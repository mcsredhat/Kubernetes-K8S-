import React, { useState } from 'react';
import { Cloud, Server, Box, Globe, Database, ArrowRight, Network, Users } from 'lucide-react';

const K8sServiceDiagram = () => {
  const [activeService, setActiveService] = useState('clusterip');

  const services = {
    clusterip: {
      title: 'ClusterIP Service',
      description: 'Internal-only access within the cluster',
      command: 'kubectl create service clusterip my-app --tcp=80:8080',
      color: 'bg-blue-500',
      features: ['Internal IP only', 'Cluster-wide DNS', 'No external access']
    },
    nodeport: {
      title: 'NodePort Service',
      description: 'Accessible via a port on each cluster node',
      command: 'kubectl create service nodeport my-app --tcp=80:8080',
      color: 'bg-green-500',
      features: ['ClusterIP + Node ports', 'Port range: 30000-32767', 'External access via any node']
    },
    loadbalancer: {
      title: 'LoadBalancer Service',
      description: 'Cloud-provisioned load balancer with public IP',
      command: 'kubectl create service loadbalancer my-app --tcp=80:8080',
      color: 'bg-purple-500',
      features: ['All NodePort features', 'Public IP address', 'Cloud provider integration']
    },
    externalname: {
      title: 'ExternalName Service',
      description: 'DNS alias to external service',
      command: 'kubectl create service externalname my-db --external-name=db.example.com',
      color: 'bg-orange-500',
      features: ['No pod routing', 'DNS CNAME record', 'Points to external services']
    }
  };

  return (
    <div className="w-full h-full bg-gradient-to-br from-slate-900 to-slate-800 p-8 overflow-auto">
      <div className="max-w-7xl mx-auto">
        <h1 className="text-3xl font-bold text-white mb-2 text-center">
          Kubernetes Service Types
        </h1>
        <p className="text-slate-300 text-center mb-8">
          Click on each service type to see how traffic flows
        </p>

        {/* Service Type Selector */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-8">
          {Object.entries(services).map(([key, service]) => (
            <button
              key={key}
              onClick={() => setActiveService(key)}
              className={`p-4 rounded-lg transition-all ${
                activeService === key
                  ? `${service.color} text-white shadow-lg scale-105`
                  : 'bg-slate-700 text-slate-300 hover:bg-slate-600'
              }`}
            >
              <div className="font-semibold">{service.title}</div>
            </button>
          ))}
        </div>

        {/* Main Diagram Area */}
        <div className="bg-slate-800 rounded-xl p-8 mb-6 shadow-2xl">
          {activeService === 'clusterip' && <ClusterIPDiagram />}
          {activeService === 'nodeport' && <NodePortDiagram />}
          {activeService === 'loadbalancer' && <LoadBalancerDiagram />}
          {activeService === 'externalname' && <ExternalNameDiagram />}
        </div>

        {/* Service Details */}
        <div className="bg-slate-800 rounded-xl p-6 shadow-xl">
          <h3 className="text-xl font-bold text-white mb-3">
            {services[activeService].title}
          </h3>
          <p className="text-slate-300 mb-4">
            {services[activeService].description}
          </p>
          <div className="bg-slate-900 rounded p-4 mb-4 font-mono text-sm text-green-400">
            {services[activeService].command}
          </div>
          <div className="space-y-2">
            <h4 className="text-white font-semibold">Key Features:</h4>
            {services[activeService].features.map((feature, idx) => (
              <div key={idx} className="flex items-center text-slate-300">
                <div className="w-2 h-2 bg-blue-400 rounded-full mr-3"></div>
                {feature}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

const ClusterIPDiagram = () => (
  <div className="space-y-8">
    <div className="flex items-center justify-center gap-8 flex-wrap">
      <div className="text-center">
        <div className="bg-slate-700 p-6 rounded-lg mb-2">
          <Users className="w-16 h-16 text-red-400 mx-auto" />
        </div>
        <div className="text-white font-semibold">External Users</div>
        <div className="text-red-400 text-sm">❌ No Access</div>
      </div>

      <div className="flex flex-col items-center">
        <div className="border-4 border-blue-500 rounded-xl p-8 bg-slate-700/50">
          <div className="text-center mb-6">
            <div className="text-blue-400 font-bold text-lg mb-2">Kubernetes Cluster</div>
          </div>
          
          <div className="flex items-center gap-6 flex-wrap justify-center">
            <div className="text-center">
              <div className="bg-green-600 p-4 rounded-lg mb-2">
                <Box className="w-12 h-12 text-white mx-auto" />
              </div>
              <div className="text-white text-sm">Pod 1</div>
              <div className="text-slate-400 text-xs">:8080</div>
            </div>

            <ArrowRight className="text-blue-400 w-8 h-8" />

            <div className="text-center">
              <div className="bg-blue-600 p-4 rounded-lg mb-2">
                <Network className="w-12 h-12 text-white mx-auto" />
              </div>
              <div className="text-white font-semibold">ClusterIP</div>
              <div className="text-slate-400 text-xs">10.0.0.50:80</div>
            </div>

            <ArrowRight className="text-blue-400 w-8 h-8" />

            <div className="space-y-2">
              <div className="text-center">
                <div className="bg-green-600 p-4 rounded-lg mb-2">
                  <Box className="w-12 h-12 text-white mx-auto" />
                </div>
                <div className="text-white text-sm">Pod 2</div>
                <div className="text-slate-400 text-xs">:8080</div>
              </div>
              <div className="text-center">
                <div className="bg-green-600 p-4 rounded-lg mb-2">
                  <Box className="w-12 h-12 text-white mx-auto" />
                </div>
                <div className="text-white text-sm">Pod 3</div>
                <div className="text-slate-400 text-xs">:8080</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div className="text-center text-slate-400 text-sm">
      Traffic flows only within the cluster. Other pods can access via ClusterIP or DNS name.
    </div>
  </div>
);

const NodePortDiagram = () => (
  <div className="space-y-8">
    <div className="flex items-center justify-center gap-8 flex-wrap">
      <div className="text-center">
        <div className="bg-slate-700 p-6 rounded-lg mb-2">
          <Users className="w-16 h-16 text-green-400 mx-auto" />
        </div>
        <div className="text-white font-semibold">External Users</div>
        <div className="text-green-400 text-sm">✓ Access via NodePort</div>
      </div>

      <ArrowRight className="text-green-400 w-8 h-8" />

      <div className="border-4 border-green-500 rounded-xl p-8 bg-slate-700/50">
        <div className="text-center mb-6">
          <div className="text-green-400 font-bold text-lg mb-2">Kubernetes Cluster</div>
        </div>
        
        <div className="space-y-6">
          <div className="flex items-center gap-4 flex-wrap justify-center">
            <div className="text-center">
              <div className="bg-slate-600 p-4 rounded-lg mb-2">
                <Server className="w-12 h-12 text-white mx-auto" />
              </div>
              <div className="text-white text-sm">Node 1</div>
              <div className="text-green-400 text-xs">:30080</div>
            </div>
            <div className="text-center">
              <div className="bg-slate-600 p-4 rounded-lg mb-2">
                <Server className="w-12 h-12 text-white mx-auto" />
              </div>
              <div className="text-white text-sm">Node 2</div>
              <div className="text-green-400 text-xs">:30080</div>
            </div>
          </div>

          <ArrowRight className="text-green-400 w-8 h-8 mx-auto" />

          <div className="flex items-center gap-4 justify-center">
            <div className="text-center">
              <div className="bg-blue-600 p-4 rounded-lg mb-2">
                <Network className="w-12 h-12 text-white mx-auto" />
              </div>
              <div className="text-white font-semibold">Service</div>
              <div className="text-slate-400 text-xs">ClusterIP + NodePort</div>
            </div>

            <ArrowRight className="text-green-400 w-8 h-8" />

            <div className="flex gap-2">
              <div className="bg-green-600 p-3 rounded-lg">
                <Box className="w-10 h-10 text-white" />
              </div>
              <div className="bg-green-600 p-3 rounded-lg">
                <Box className="w-10 h-10 text-white" />
              </div>
              <div className="bg-green-600 p-3 rounded-lg">
                <Box className="w-10 h-10 text-white" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div className="text-center text-slate-400 text-sm">
      External traffic reaches any node on port 30000-32767, then routes to pods via ClusterIP.
    </div>
  </div>
);

const LoadBalancerDiagram = () => (
  <div className="space-y-8">
    <div className="flex flex-col items-center gap-6">
      <div className="text-center">
        <div className="bg-slate-700 p-6 rounded-lg mb-2">
          <Globe className="w-16 h-16 text-purple-400 mx-auto" />
        </div>
        <div className="text-white font-semibold">Internet</div>
        <div className="text-purple-400 text-sm">Public IP: 203.0.113.5</div>
      </div>

      <ArrowRight className="text-purple-400 w-8 h-8 rotate-90" />

      <div className="text-center">
        <div className="bg-purple-600 p-6 rounded-lg mb-2">
          <Cloud className="w-16 h-16 text-white mx-auto" />
        </div>
        <div className="text-white font-semibold">Cloud Load Balancer</div>
        <div className="text-slate-400 text-xs">AWS ELB / GCP LB / Azure LB</div>
      </div>

      <ArrowRight className="text-purple-400 w-8 h-8 rotate-90" />

      <div className="border-4 border-purple-500 rounded-xl p-8 bg-slate-700/50">
        <div className="text-center mb-6">
          <div className="text-purple-400 font-bold text-lg mb-2">Kubernetes Cluster</div>
        </div>
        
        <div className="space-y-6">
          <div className="flex items-center gap-4 justify-center flex-wrap">
            <div className="text-center">
              <div className="bg-slate-600 p-4 rounded-lg mb-2">
                <Server className="w-12 h-12 text-white mx-auto" />
              </div>
              <div className="text-white text-sm">Node 1</div>
            </div>
            <div className="text-center">
              <div className="bg-slate-600 p-4 rounded-lg mb-2">
                <Server className="w-12 h-12 text-white mx-auto" />
              </div>
              <div className="text-white text-sm">Node 2</div>
            </div>
            <div className="text-center">
              <div className="bg-slate-600 p-4 rounded-lg mb-2">
                <Server className="w-12 h-12 text-white mx-auto" />
              </div>
              <div className="text-white text-sm">Node 3</div>
            </div>
          </div>

          <ArrowRight className="text-purple-400 w-8 h-8 mx-auto" />

          <div className="flex items-center gap-4 justify-center">
            <div className="text-center">
              <div className="bg-blue-600 p-4 rounded-lg mb-2">
                <Network className="w-12 h-12 text-white mx-auto" />
              </div>
              <div className="text-white font-semibold">Service</div>
            </div>

            <ArrowRight className="text-purple-400 w-8 h-8" />

            <div className="flex gap-2">
              <div className="bg-green-600 p-3 rounded-lg">
                <Box className="w-10 h-10 text-white" />
              </div>
              <div className="bg-green-600 p-3 rounded-lg">
                <Box className="w-10 h-10 text-white" />
              </div>
              <div className="bg-green-600 p-3 rounded-lg">
                <Box className="w-10 h-10 text-white" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div className="text-center text-slate-400 text-sm">
      Cloud provider creates external load balancer that distributes traffic to nodes, then to pods.
    </div>
  </div>
);

const ExternalNameDiagram = () => (
  <div className="space-y-8">
    <div className="flex items-center justify-center gap-8 flex-wrap">
      <div className="border-4 border-orange-500 rounded-xl p-8 bg-slate-700/50">
        <div className="text-center mb-6">
          <div className="text-orange-400 font-bold text-lg mb-2">Kubernetes Cluster</div>
        </div>
        
        <div className="flex items-center gap-6 flex-wrap justify-center">
          <div className="text-center">
            <div className="bg-green-600 p-4 rounded-lg mb-2">
              <Box className="w-12 h-12 text-white mx-auto" />
            </div>
            <div className="text-white text-sm">Application Pod</div>
            <div className="text-slate-400 text-xs">Needs database</div>
          </div>

          <ArrowRight className="text-orange-400 w-8 h-8" />

          <div className="text-center">
            <div className="bg-orange-600 p-4 rounded-lg mb-2">
              <Network className="w-12 h-12 text-white mx-auto" />
            </div>
            <div className="text-white font-semibold">ExternalName</div>
            <div className="text-slate-400 text-xs">my-db.default.svc</div>
            <div className="text-orange-400 text-xs mt-1">→ CNAME</div>
          </div>

          <ArrowRight className="text-orange-400 w-8 h-8" />

          <div className="text-center">
            <div className="bg-slate-600 p-6 rounded-lg mb-2">
              <Database className="w-16 h-16 text-white mx-auto" />
            </div>
            <div className="text-white font-semibold">External Service</div>
            <div className="text-slate-400 text-xs">db.example.com</div>
          </div>
        </div>
      </div>
    </div>
    <div className="text-center text-slate-400 text-sm">
      Service returns DNS CNAME pointing to external resource. No pods involved - pure DNS routing.
    </div>
  </div>
);

export default K8sServiceDiagram;