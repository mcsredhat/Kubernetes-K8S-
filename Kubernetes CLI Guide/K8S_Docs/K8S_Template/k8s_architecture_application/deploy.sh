#!/bin/bash
# ============================================================================
# deploy.sh - Complete Kubernetes Deployment Script (CORRECTED)
# ============================================================================
# Purpose: Deploy, manage, and validate Kubernetes resources
# Usage: ./deploy.sh [command]
# Commands: check-prereqs, deploy, status, cleanup, help
# FIXES: Added CLOUD_PROVIDER validation, updated file references
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="${SCRIPT_DIR}/values.env"
TEMP_DIR="${SCRIPT_DIR}/.temp"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

# Load environment variables
load_env() {
    if [[ ! -f "$VALUES_FILE" ]]; then
        log_error "values.env not found at $VALUES_FILE"
        exit 1
    fi
    
    set -a
    source "$VALUES_FILE"
    set +a
}

# Check prerequisites
check_prereqs() {
    log_info "Checking prerequisites..."
    local errors=0
    local warnings=0
    
    # Check required tools
    for tool in kubectl envsubst; do
        if ! command -v $tool &>/dev/null; then
            log_error "$tool not installed"
            ((errors++))
        else
            log_success "$tool installed"
        fi
    done
    
    # Check cluster connectivity
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        ((errors++))
    else
        log_success "Connected to cluster: $(kubectl config current-context)"
    fi
    
    # Load variables
    load_env
    
    # Check cloud provider is set
    if [[ -z "${CLOUD_PROVIDER:-}" ]]; then
        log_error "CLOUD_PROVIDER not set in values.env"
        log_info "Set CLOUD_PROVIDER to: aws, gcp, or azure"
        ((errors++))
    elif [[ ! "${CLOUD_PROVIDER}" =~ ^(aws|gcp|azure)$ ]]; then
        log_error "Invalid CLOUD_PROVIDER: ${CLOUD_PROVIDER}"
        log_info "Must be one of: aws, gcp, azure"
        ((errors++))
    else
        log_success "Cloud provider: ${CLOUD_PROVIDER}"
    fi
    
    # Check storage class
    if ! kubectl get storageclass "$STORAGE_CLASS" &>/dev/null; then
        log_error "Storage class '$STORAGE_CLASS' not found"
        log_info "Available storage classes:"
        kubectl get storageclass -o custom-columns=NAME:.metadata.name --no-headers | sed 's/^/  - /'
        ((errors++))
    else
        log_success "Storage class '$STORAGE_CLASS' exists"
    fi
    
    # Check cert-manager
    if ! kubectl get crd certificates.cert-manager.io &>/dev/null; then
        log_error "cert-manager not installed (REQUIRED for TLS)"
        log_info "Install: kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml"
        ((errors++))
    else
        log_success "cert-manager installed"
    fi
    
    # Check ingress-nginx
    if ! kubectl get namespace ingress-nginx &>/dev/null; then
        log_warning "ingress-nginx not installed"
        log_info "Install: kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml"
        ((warnings++))
    else
        log_success "ingress-nginx installed"
    fi
    
    # Check metrics-server
    if ! kubectl get deployment metrics-server -n kube-system &>/dev/null; then
        log_warning "metrics-server not installed (HPA won't work)"
        log_info "Install: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
        ((warnings++))
    else
        log_success "metrics-server installed"
    fi
    
    # Check for default passwords
    if [[ "$DATABASE_PASSWORD" == *"CHANGE"* ]] || \
       [[ "$API_KEY" == *"CHANGE"* ]] || \
       [[ "$JWT_SECRET" == *"CHANGE"* ]] || \
       [[ "$ENCRYPTION_KEY" == *"CHANGE"* ]]; then
        log_error "Default passwords detected - MUST be changed before deployment"
        ((errors++))
    else
        log_success "No default passwords found"
    fi
    
    # Check password strength
    if [[ ${#DATABASE_PASSWORD} -lt 16 ]] || \
       [[ ${#JWT_SECRET} -lt 32 ]] || \
       [[ ${#ENCRYPTION_KEY} -lt 32 ]]; then
        log_warning "Some passwords don't meet recommended length"
        ((warnings++))
    else
        log_success "Password lengths meet recommendations"
    fi
    
    # Check SNAPSHOT_RETENTION is set
    if [[ -z "${SNAPSHOT_RETENTION:-}" ]]; then
        log_warning "SNAPSHOT_RETENTION not set, using default: 4"
        export SNAPSHOT_RETENTION=4
    else
        log_success "Snapshot retention: ${SNAPSHOT_RETENTION}"
    fi
    
    echo
    if [[ $errors -gt 0 ]]; then
        log_error "Found $errors error(s) - fix before deployment"
        return 1
    fi
    
    if [[ $warnings -gt 0 ]]; then
        log_warning "Found $warnings warning(s) - review before deployment"
    fi
    
    log_success "All critical checks passed!"
    return 0
}

# Process template files
process_templates() {
    log_info "Processing templates..."
    
    load_env
    
    # Set defaults for optional variables
    export SNAPSHOT_RETENTION=${SNAPSHOT_RETENTION:-4}
    
    mkdir -p "$TEMP_DIR"
    
    local files=(
        "01-namespace.yaml"
        "02-storage.yaml"
        "03-secrets-config.yaml"
        "04-rbac.yaml"
        "05-deployment.yaml"
        "06-services-ingress.yaml"
        "07-autoscaling.yaml"
        "08-security-network.yaml"
        "09-monitoring.yaml"
        "10-backup-maintenance.yaml"
    )
    
    for file in "${files[@]}"; do
        local source="${SCRIPT_DIR}/${file}"
        local dest="${TEMP_DIR}/${file}"
        
        if [[ -f "$source" ]]; then
            envsubst < "$source" > "$dest"
            log_success "Processed $file"
        else
            log_warning "File not found: $file"
        fi
    done
}

# Deploy resources
deploy() {
    log_info "Starting deployment..."
    
    # Check prerequisites first
    if ! check_prereqs; then
        log_error "Prerequisites check failed. Fix errors and try again."
        exit 1
    fi
    
    # Process templates
    process_templates
    
    # Deploy in order
    local files=(
        "01-namespace.yaml"
        "02-storage.yaml"
        "03-secrets-config.yaml"
        "04-rbac.yaml"
        "05-deployment.yaml"
        "06-services-ingress.yaml"
        "07-autoscaling.yaml"
        "08-security-network.yaml"
        "09-monitoring.yaml"
        "10-backup-maintenance.yaml"
    )
    
    for file in "${files[@]}"; do
        local filepath="${TEMP_DIR}/${file}"
        
        if [[ -f "$filepath" ]]; then
            log_info "Applying $file..."
            
            if kubectl apply -f "$filepath"; then
                log_success "$file applied"
            else
                log_error "Failed to apply $file"
                return 1
            fi
            
            # Wait a bit between critical resources
            if [[ "$file" == "01-namespace.yaml" ]] || \
               [[ "$file" == "02-storage.yaml" ]] || \
               [[ "$file" == "03-secrets-config.yaml" ]]; then
                sleep 3
            fi
        fi
    done
    
    echo
    log_success "Deployment completed!"
    log_info "Check status with: ./deploy.sh status"
}

# Check deployment status
status() {
    load_env
    
    log_info "Checking deployment status for namespace: $NAMESPACE"
    echo
    
    echo "=== Pods ==="
    kubectl get pods -n "$NAMESPACE" -o wide
    echo
    
    echo "=== Deployments ==="
    kubectl get deployments -n "$NAMESPACE"
    echo
    
    echo "=== Services ==="
    kubectl get services -n "$NAMESPACE"
    echo
    
    echo "=== Ingress ==="
    kubectl get ingress -n "$NAMESPACE"
    echo
    
    echo "=== PVC Status ==="
    kubectl get pvc -n "$NAMESPACE"
    echo
    
    echo "=== HPA Status ==="
    kubectl get hpa -n "$NAMESPACE"
    echo
    
    echo "=== Certificates ==="
    kubectl get certificates -n "$NAMESPACE"
    echo
    
    echo "=== Recent Events ==="
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -n 10
}

# Cleanup resources
cleanup() {
    load_env
    
    log_warning "This will DELETE all resources in namespace: $NAMESPACE"
    read -p "Are you sure? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "Cleanup cancelled"
        return 0
    fi
    
    log_info "Deleting namespace: $NAMESPACE"
    kubectl delete namespace "$NAMESPACE" --timeout=5m
    
    log_info "Deleting monitoring namespace (if exists)"
    kubectl delete namespace monitoring --timeout=5m 2>/dev/null || true
    
    log_info "Cleaning up temp files"
    rm -rf "$TEMP_DIR"
    
    log_success "Cleanup completed"
}

# Show help
show_help() {
    cat << EOF
Kubernetes Deployment Script

Usage: ./deploy.sh [command]

Commands:
    check-prereqs  - Validate prerequisites and configuration
    deploy         - Deploy all resources to Kubernetes
    status         - Check deployment status
    cleanup        - Remove all deployed resources
    help           - Show this help message

Examples:
    ./deploy.sh check-prereqs  # Validate before deployment
    ./deploy.sh deploy         # Deploy application
    ./deploy.sh status         # Check status
    ./deploy.sh cleanup        # Remove everything

Before deployment:
    1. Edit values.env with your configuration
    2. Change all default passwords
    3. Set CLOUD_PROVIDER (aws, gcp, or azure)
    4. Verify storage class exists
    5. Run check-prereqs to validate

For more information, see deployment_guide.md
EOF
}

# Main script logic
main() {
    local command="${1:-help}"
    
    case "$command" in
        check-prereqs)
            check_prereqs
            ;;
        deploy)
            deploy
            ;;
        status)
            status
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo
            show_help
            exit 1
            ;;
    esac
}

main "$@"