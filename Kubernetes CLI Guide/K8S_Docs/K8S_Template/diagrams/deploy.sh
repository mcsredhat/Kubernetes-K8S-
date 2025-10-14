#!/bin/bash
# ============================================================================
# deploy.sh - Kubernetes Deployment Automation Script
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="${SCRIPT_DIR}/values.env"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

check_prereqs() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl not installed"
        exit 1
    fi
    log_success "kubectl installed"
    
    # Check cluster connection
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cannot connect to cluster"
        exit 1
    fi
    log_success "Cluster connected"
    
    # Load config
    source "${VALUES_FILE}"
    
    # Check cloud provider
    if [[ ! "${CLOUD_PROVIDER}" =~ ^(aws|gcp|azure)$ ]]; then
        log_error "Invalid CLOUD_PROVIDER: ${CLOUD_PROVIDER}"
        exit 1
    fi
    log_success "Cloud provider: ${CLOUD_PROVIDER}"
    
    log_success "All checks passed!"
}

deploy() {
    log_info "Starting deployment..."
    source "${VALUES_FILE}"
    
    # Deploy in order
    for file in 01-namespace.yaml 02-storage.yaml 03-secrets-config.yaml \
                04-rbac.yaml 05-deployment.yaml 06-services-ingress.yaml \
                07-autoscaling.yaml 08-security-network.yaml \
                09-monitoring.yaml 10-backup-maintenance.yaml; do
        log_info "Applying ${file}..."
        envsubst < "${file}" | kubectl apply -f -
        sleep 2
    done
    
    log_success "Deployment completed!"
}

status() {
    source "${VALUES_FILE}"
    kubectl get all -n "${NAMESPACE}"
}

case "${1:-help}" in
    check-prereqs) check_prereqs ;;
    deploy) deploy ;;
    status) status ;;
    *) echo "Usage: ./deploy.sh [check-prereqs|deploy|status]" ;;
esac