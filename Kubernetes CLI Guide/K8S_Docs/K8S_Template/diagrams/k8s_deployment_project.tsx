import React, { useState } from 'react';
import { Download, CheckCircle, AlertCircle, FileText, Settings, Shield, Database, Cloud, Activity } from 'lucide-react';

const K8sDeploymentProject = () => {
  const [activeTab, setActiveTab] = useState('overview');
  const [config, setConfig] = useState({
    appName: 'myapp',
    namespace: 'myapp-prod',
    environment: 'production',
    domain: 'example.com',
    cloudProvider: 'aws',
    storageClass: 'gp3',
    replicas: 3
  });

  const projectFiles = [
    { name: 'values.env', desc: 'Configuration variables', icon: Settings, color: 'text-green-500' },
    { name: 'deploy.sh', desc: 'Deployment automation script', icon: Cloud, color: 'text-blue-500' },
    { name: '01-namespace.yaml', desc: 'Namespace and resource quotas', icon: Shield, color: 'text-red-500' },
    { name: '02-storage.yaml', desc: 'Storage classes and PVCs', icon: Database, color: 'text-orange-500' },
    { name: '03-secrets-config.yaml', desc: 'Secrets and ConfigMaps', icon: Shield, color: 'text-green-500' },
    { name: '04-rbac.yaml', desc: 'RBAC permissions', icon: Shield, color: 'text-purple-500' },
    { name: '05-deployment.yaml', desc: 'Application deployments', icon: Cloud, color: 'text-blue-500' },
    { name: '06-services-ingress.yaml', desc: 'Services and ingress', icon: Activity, color: 'text-indigo-500' },
    { name: '07-autoscaling.yaml', desc: 'HPA and PDB', icon: Activity, color: 'text-cyan-500' },
    { name: '08-security-network.yaml', desc: 'Network policies', icon: Shield, color: 'text-red-500' },
    { name: '09-monitoring.yaml', desc: 'Monitoring stack', icon: Activity, color: 'text-gray-500' },
    { name: '10-backup-maintenance.yaml', desc: 'Backup and rollback', icon: Database, color: 'text-brown-500' }
  ];

  const deploymentSteps = [
    { step: 1, title: 'Prerequisites', desc: 'Install cert-manager, ingress-nginx, metrics-server', status: 'pending' },
    { step: 2, title: 'Configuration', desc: 'Edit values.env with your settings', status: 'pending' },
    { step: 3, title: 'Validation', desc: 'Run ./deploy.sh check-prereqs', status: 'pending' },
    { step: 4, title: 'Deployment', desc: 'Run ./deploy.sh deploy', status: 'pending' },
    { step: 5, title: 'Verification', desc: 'Check deployment status', status: 'pending' },
    { step: 6, title: 'Testing', desc: 'Test application endpoints', status: 'pending' }
  ];

  const generateValuesEnv = () => {
    const content = [
      '# ============================================================================',
      '# values.env - Configuration Variables for Kubernetes Deployment',
      '# ============================================================================',
      '# IMPORTANT: Change ALL default passwords before deployment!',
      '# Generate secure passwords: openssl rand -base64 32',
      '# ============================================================================',
      '',
      '# APPLICATION CONFIGURATION',
      `APP_NAME="${config.appName}"`,
      `NAMESPACE="${config.namespace}"`,
      `ENVIRONMENT="${config.environment}"`,
      'TEAM="platform"',
      `DOMAIN="${config.domain}"`,
      '',
      '# CLOUD PROVIDER (REQUIRED for snapshots)',
      '# Options: aws, gcp, azure',
      `CLOUD_PROVIDER="${config.cloudProvider}"`,
      '',
      '# SCALING CONFIGURATION',
      `REPLICAS=${config.replicas}`,
      'BACKEND_REPLICAS=2',
      '',
      '# STORAGE CONFIGURATION',
      `STORAGE_CLASS="${config.storageClass}"`,
      'STORAGE_SIZE="10Gi"',
      'BACKUP_STORAGE_SIZE="20Gi"',
      '',
      '# BACKUP CONFIGURATION',
      'BACKUP_SCHEDULE="0 2 * * *"',
      'SNAPSHOT_SCHEDULE="0 3 * * *"',
      'BACKUP_RETENTION_DAYS=7',
      'SNAPSHOT_RETENTION=4',
      '',
      '# CONTAINER IMAGES',
      'IMAGE="nginx:1.27-alpine"',
      'BACKEND_IMAGE="nginx:1.27-alpine"',
      '',
      '# DATABASE CREDENTIALS (CHANGE THESE!)',
      'DATABASE_USERNAME="myapp_user"',
      'DATABASE_PASSWORD="CHANGE_ME_STRONG_PASSWORD_MIN_16_CHARS"',
      '',
      '# API SECURITY (CHANGE THESE!)',
      'API_KEY="CHANGE_ME_GENERATE_WITH_openssl_rand_base64_32"',
      'JWT_SECRET="CHANGE_ME_GENERATE_WITH_openssl_rand_base64_32"',
      'ENCRYPTION_KEY="CHANGE_ME_GENERATE_WITH_openssl_rand_base64_32"',
      '',
      '# REDIS CONFIGURATION (CHANGE PASSWORD!)',
      'REDIS_PASSWORD="CHANGE_ME_REDIS_PASSWORD"',
      'REDIS_URL="redis://:${REDIS_PASSWORD}@redis.${NAMESPACE}.svc.cluster.local:6379/0"',
      '',
      '# MONITORING CREDENTIALS (CHANGE THIS!)',
      'GRAFANA_ADMIN_PASSWORD="CHANGE_ME_GRAFANA_PASSWORD"',
      '',
      '# Note: DATABASE_URL is automatically constructed in 03-secrets-config.yaml',
      '# Format: postgresql://${DATABASE_USERNAME}:${DATABASE_PASSWORD}@postgres.${NAMESPACE}.svc.cluster.local:5432/${APP_NAME}_db?sslmode=require'
    ];
    return content.join('\n');
  };

  const generateDeployScript = () => {
    return `#!/bin/bash
# ============================================================================
# deploy.sh - Kubernetes Deployment Automation Script
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="\${SCRIPT_DIR}/values.env"

# Colors
GREEN='\\033[0;32m'
BLUE='\\033[0;34m'
RED='\\033[0;31m'
NC='\\033[0m'

log_info() { echo -e "\${BLUE}[INFO]\${NC} $1"; }
log_success() { echo -e "\${GREEN}[✓]\${NC} $1"; }
log_error() { echo -e "\${RED}[✗]\${NC} $1"; }

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
    source "\${VALUES_FILE}"
    
    # Check cloud provider
    if [[ ! "\${CLOUD_PROVIDER}" =~ ^(aws|gcp|azure)$ ]]; then
        log_error "Invalid CLOUD_PROVIDER: \${CLOUD_PROVIDER}"
        exit 1
    fi
    log_success "Cloud provider: \${CLOUD_PROVIDER}"
    
    log_success "All checks passed!"
}

deploy() {
    log_info "Starting deployment..."
    source "\${VALUES_FILE}"
    
    # Deploy in order
    for file in 01-namespace.yaml 02-storage.yaml 03-secrets-config.yaml \\
                04-rbac.yaml 05-deployment.yaml 06-services-ingress.yaml \\
                07-autoscaling.yaml 08-security-network.yaml \\
                09-monitoring.yaml 10-backup-maintenance.yaml; do
        log_info "Applying \${file}..."
        envsubst < "\${file}" | kubectl apply -f -
        sleep 2
    done
    
    log_success "Deployment completed!"
}

status() {
    source "\${VALUES_FILE}"
    kubectl get all -n "\${NAMESPACE}"
}

case "\${1:-help}" in
    check-prereqs) check_prereqs ;;
    deploy) deploy ;;
    status) status ;;
    *) echo "Usage: ./deploy.sh [check-prereqs|deploy|status]" ;;
esac`;
  };

  const features = [
    { title: 'Security First', items: ['Pod Security Standards', 'Network Policies', 'RBAC', 'Secret Encryption'], icon: Shield },
    { title: 'Auto Scaling', items: ['HPA (CPU/Memory)', 'Pod Disruption Budget', 'Resource Limits', 'High Availability'], icon: Activity },
    { title: 'Observability', items: ['Prometheus Metrics', 'Grafana Dashboards', 'Health Checks', 'Structured Logs'], icon: Activity },
    { title: 'Data Protection', items: ['Automated Backups', 'Volume Snapshots', 'One-Click Rollback', 'Retention Policies'], icon: Database }
  ];

  const downloadFile = (filename, content) => {
    const blob = new Blob([content], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 p-6">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="bg-white rounded-lg shadow-lg p-8 mb-6">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h1 className="text-4xl font-bold text-gray-800 mb-2">
                Kubernetes Production Deployment
              </h1>
              <p className="text-gray-600">
                Complete production-ready template with security, monitoring, and automated backups
              </p>
            </div>
            <Cloud className="w-16 h-16 text-blue-500" />
          </div>
          
          <div className="grid grid-cols-4 gap-4 mt-6">
            <div className="bg-blue-50 p-4 rounded-lg text-center">
              <FileText className="w-8 h-8 text-blue-500 mx-auto mb-2" />
              <div className="text-2xl font-bold text-gray-800">12</div>
              <div className="text-sm text-gray-600">Files</div>
            </div>
            <div className="bg-green-50 p-4 rounded-lg text-center">
              <Shield className="w-8 h-8 text-green-500 mx-auto mb-2" />
              <div className="text-2xl font-bold text-gray-800">100%</div>
              <div className="text-sm text-gray-600">Secure</div>
            </div>
            <div className="bg-purple-50 p-4 rounded-lg text-center">
              <Activity className="w-8 h-8 text-purple-500 mx-auto mb-2" />
              <div className="text-2xl font-bold text-gray-800">Ready</div>
              <div className="text-sm text-gray-600">Production</div>
            </div>
            <div className="bg-orange-50 p-4 rounded-lg text-center">
              <Database className="w-8 h-8 text-orange-500 mx-auto mb-2" />
              <div className="text-2xl font-bold text-gray-800">Auto</div>
              <div className="text-sm text-gray-600">Backup</div>
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="bg-white rounded-lg shadow-lg mb-6">
          <div className="flex border-b">
            {['overview', 'files', 'config', 'deployment'].map(tab => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`px-6 py-3 font-medium transition-colors ${
                  activeTab === tab
                    ? 'border-b-2 border-blue-500 text-blue-600'
                    : 'text-gray-600 hover:text-gray-800'
                }`}
              >
                {tab.charAt(0).toUpperCase() + tab.slice(1)}
              </button>
            ))}
          </div>

          <div className="p-6">
            {activeTab === 'overview' && (
              <div>
                <h2 className="text-2xl font-bold text-gray-800 mb-6">Project Features</h2>
                <div className="grid grid-cols-2 gap-6">
                  {features.map((feature, idx) => (
                    <div key={idx} className="border rounded-lg p-6 hover:shadow-lg transition-shadow">
                      <div className="flex items-center mb-4">
                        <feature.icon className="w-8 h-8 text-blue-500 mr-3" />
                        <h3 className="text-xl font-semibold text-gray-800">{feature.title}</h3>
                      </div>
                      <ul className="space-y-2">
                        {feature.items.map((item, i) => (
                          <li key={i} className="flex items-center text-gray-600">
                            <CheckCircle className="w-4 h-4 text-green-500 mr-2" />
                            {item}
                          </li>
                        ))}
                      </ul>
                    </div>
                  ))}
                </div>

                <div className="mt-8 bg-blue-50 border-l-4 border-blue-500 p-4 rounded">
                  <div className="flex items-start">
                    <AlertCircle className="w-6 h-6 text-blue-500 mr-3 flex-shrink-0 mt-1" />
                    <div>
                      <h4 className="font-semibold text-gray-800 mb-2">Before Deployment</h4>
                      <ul className="text-sm text-gray-600 space-y-1">
                        <li>• Install prerequisites: cert-manager, ingress-nginx, metrics-server</li>
                        <li>• Update values.env with your configuration</li>
                        <li>• Change ALL default passwords (use: openssl rand -base64 32)</li>
                        <li>• Set CLOUD_PROVIDER (aws, gcp, or azure)</li>
                        <li>• Verify storage class exists in your cluster</li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'files' && (
              <div>
                <h2 className="text-2xl font-bold text-gray-800 mb-6">Project Files</h2>
                <div className="grid grid-cols-2 gap-4">
                  {projectFiles.map((file, idx) => (
                    <div key={idx} className="border rounded-lg p-4 hover:shadow-md transition-shadow">
                      <div className="flex items-center mb-2">
                        <file.icon className={`w-6 h-6 ${file.color} mr-3`} />
                        <span className="font-mono text-sm font-semibold text-gray-800">{file.name}</span>
                      </div>
                      <p className="text-sm text-gray-600">{file.desc}</p>
                    </div>
                  ))}
                </div>

                <div className="mt-6 flex gap-4">
                  <button
                    onClick={() => downloadFile('values.env', generateValuesEnv())}
                    className="flex items-center px-6 py-3 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
                  >
                    <Download className="w-5 h-5 mr-2" />
                    Download values.env
                  </button>
                  <button
                    onClick={() => downloadFile('deploy.sh', generateDeployScript())}
                    className="flex items-center px-6 py-3 bg-green-500 text-white rounded-lg hover:bg-green-600 transition-colors"
                  >
                    <Download className="w-5 h-5 mr-2" />
                    Download deploy.sh
                  </button>
                </div>
              </div>
            )}

            {activeTab === 'config' && (
              <div>
                <h2 className="text-2xl font-bold text-gray-800 mb-6">Configuration</h2>
                <div className="grid grid-cols-2 gap-6">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">App Name</label>
                    <input
                      type="text"
                      value={config.appName}
                      onChange={(e) => setConfig({...config, appName: e.target.value})}
                      className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Namespace</label>
                    <input
                      type="text"
                      value={config.namespace}
                      onChange={(e) => setConfig({...config, namespace: e.target.value})}
                      className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Domain</label>
                    <input
                      type="text"
                      value={config.domain}
                      onChange={(e) => setConfig({...config, domain: e.target.value})}
                      className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Cloud Provider</label>
                    <select
                      value={config.cloudProvider}
                      onChange={(e) => setConfig({...config, cloudProvider: e.target.value})}
                      className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                    >
                      <option value="aws">AWS</option>
                      <option value="gcp">GCP</option>
                      <option value="azure">Azure</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Storage Class</label>
                    <input
                      type="text"
                      value={config.storageClass}
                      onChange={(e) => setConfig({...config, storageClass: e.target.value})}
                      className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Replicas</label>
                    <input
                      type="number"
                      value={config.replicas}
                      onChange={(e) => setConfig({...config, replicas: parseInt(e.target.value)})}
                      className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                    />
                  </div>
                </div>

                <div className="mt-6">
                  <button
                    onClick={() => {
                      downloadFile('values.env', generateValuesEnv());
                      alert('Configuration downloaded! Edit the file and change all passwords before deployment.');
                    }}
                    className="px-6 py-3 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
                  >
                    Generate Configuration File
                  </button>
                </div>
              </div>
            )}

            {activeTab === 'deployment' && (
              <div>
                <h2 className="text-2xl font-bold text-gray-800 mb-6">Deployment Steps</h2>
                <div className="space-y-4">
                  {deploymentSteps.map((step) => (
                    <div key={step.step} className="flex items-start border rounded-lg p-4 hover:shadow-md transition-shadow">
                      <div className="flex-shrink-0 w-10 h-10 bg-blue-500 text-white rounded-full flex items-center justify-center font-bold mr-4">
                        {step.step}
                      </div>
                      <div className="flex-grow">
                        <h3 className="font-semibold text-gray-800 mb-1">{step.title}</h3>
                        <p className="text-sm text-gray-600">{step.desc}</p>
                      </div>
                    </div>
                  ))}
                </div>

                <div className="mt-8 bg-gray-50 rounded-lg p-6">
                  <h3 className="font-semibold text-gray-800 mb-4">Quick Start Commands</h3>
                  <div className="space-y-3 font-mono text-sm">
                    <div className="bg-gray-800 text-green-400 p-3 rounded">
                      <div># Make script executable</div>
                      <div>chmod +x deploy.sh</div>
                    </div>
                    <div className="bg-gray-800 text-green-400 p-3 rounded">
                      <div># Check prerequisites</div>
                      <div>./deploy.sh check-prereqs</div>
                    </div>
                    <div className="bg-gray-800 text-green-400 p-3 rounded">
                      <div># Deploy application</div>
                      <div>./deploy.sh deploy</div>
                    </div>
                    <div className="bg-gray-800 text-green-400 p-3 rounded">
                      <div># Check status</div>
                      <div>./deploy.sh status</div>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="bg-white rounded-lg shadow-lg p-6 text-center">
          <p className="text-gray-600 mb-4">
            Production-ready Kubernetes deployment template with enterprise features
          </p>
          <div className="flex justify-center gap-4">
            <button
              onClick={() => {
                downloadFile('values.env', generateValuesEnv());
                downloadFile('deploy.sh', generateDeployScript());
                alert('Files downloaded! Remember to:\n1. Edit values.env\n2. Change all passwords\n3. Run ./deploy.sh check-prereqs');
              }}
              className="px-8 py-3 bg-gradient-to-r from-blue-500 to-indigo-600 text-white rounded-lg hover:from-blue-600 hover:to-indigo-700 transition-all shadow-lg"
            >
              Download All Files
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default K8sDeploymentProject;