# Helm Integration Guide

This guide explains how to add both Helm and non-Helm applications to your homelab in a clean, scalable way.

## Architecture Overview

Your homelab now supports **two deployment patterns**:

### **1. Kustomize Applications (Traditional)**
- **Location**: `infra/*/` or `apps/*/`
- **Use for**: Simple YAML manifests, custom configurations
- **Examples**: MetalLB, Longhorn, n8n, Homepage

### **2. Helm Applications (New)**
- **Location**: `infra/*/helm/` or `apps/*/helm/`
- **Use for**: Complex applications with dependencies, community charts
- **Examples**: Monitoring stack, databases, complex applications

## How It Works

### **ApplicationSet Configuration**
```yaml
# Kustomize Applications
infra-kustomize:
  directories: [infra/metallb, infra/longhorn, infra/cloudflare-tunnel]

# Helm Applications  
infra-helm:
  directories: [infra/*/helm]
```

### **Automatic Discovery**
- **Kustomize**: ArgoCD finds directories and deploys them as-is
- **Helm**: ArgoCD finds `*/helm/` directories and treats them as Helm charts

## Adding New Applications

### **Option 1: Kustomize Application (Simple)**
```bash
# Create directory
mkdir -p apps/myapp

# Add manifests
apps/myapp/
├── namespace.yaml
├── deployment.yaml
├── service.yaml
└── kustomization.yaml
```

### **Option 2: Helm Application (Complex)**
```bash
# Create Helm chart directory
mkdir -p apps/myapp/helm

# Add Helm chart files
apps/myapp/helm/
├── Chart.yaml          # Chart metadata
├── values.yaml         # Custom values
├── namespace.yaml      # Namespace (optional)
└── kustomization.yaml  # Kustomize config
```

## Helm Chart Structure

### **Chart.yaml Example**
```yaml
apiVersion: v2
name: myapp
description: My application
type: application
version: 0.1.0
appVersion: "1.0.0"
dependencies:
- name: postgresql
  version: 12.1.2
  repository: https://charts.bitnami.com/bitnami
```

### **values.yaml Example**
```yaml
# Override default values from the dependency chart
postgresql:
  auth:
    postgresPassword: "mypassword"
  primary:
    persistence:
      size: 10Gi
      storageClassName: longhorn
```

## Best Practices

### **When to Use Kustomize**
- ✅ Simple applications with few resources
- ✅ Custom configurations
- ✅ Applications you want full control over
- ✅ Quick deployments

### **When to Use Helm**
- ✅ Complex applications with many dependencies
- ✅ Community charts (databases, monitoring, etc.)
- ✅ Applications that benefit from templating
- ✅ Applications with complex configuration

### **File Organization**
```
infra/
├── metallb/           # Kustomize
├── longhorn/          # Kustomize  
├── monitoring/        # Helm
│   └── helm/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── namespace.yaml
└── database/          # Helm
    └── helm/
        ├── Chart.yaml
        ├── values.yaml
        └── namespace.yaml

apps/
├── n8n/              # Kustomize
├── homepage/         # Kustomize
└── wordpress/        # Helm
    └── helm/
        ├── Chart.yaml
        ├── values.yaml
        └── namespace.yaml
```

## Examples

### **Adding a Database (Helm)**
```bash
mkdir -p infra/database/helm
cd infra/database/helm

# Create Chart.yaml
cat > Chart.yaml << EOF
apiVersion: v2
name: database
description: PostgreSQL database
type: application
version: 0.1.0
dependencies:
- name: postgresql
  version: 12.1.2
  repository: https://charts.bitnami.com/bitnami
EOF

# Create values.yaml
cat > values.yaml << EOF
postgresql:
  auth:
    postgresPassword: "mypassword"
  primary:
    persistence:
      size: 20Gi
      storageClassName: longhorn
  service:
    type: LoadBalancer
    port: 5432
EOF

# Create namespace
cat > namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: database
EOF

# Create kustomization
cat > kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- namespace.yaml
namespace: database
EOF
```

### **Adding a Simple App (Kustomize)**
```bash
mkdir -p apps/simple-app
cd apps/simple-app

# Create namespace
cat > namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: simple-app
EOF

# Create deployment
cat > deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: simple-app
  namespace: simple-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: simple-app
  template:
    metadata:
      labels:
        app: simple-app
    spec:
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80
EOF

# Create service
cat > service.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: simple-app
  namespace: simple-app
spec:
  selector:
    app: simple-app
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF

# Create kustomization
cat > kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- namespace.yaml
- deployment.yaml
- service.yaml
namespace: simple-app
EOF
```

## Benefits

### **Unified Experience**
- Both patterns feel native to the codebase
- Consistent file organization
- Same GitOps workflow

### **Flexibility**
- Choose the right tool for each application
- Mix and match as needed
- Easy to migrate between patterns

### **Scalability**
- Automatic discovery of new applications
- No manual ArgoCD configuration needed
- Easy to add new applications

This approach gives you the best of both worlds: the simplicity of Kustomize for simple apps and the power of Helm for complex applications, all managed through a unified GitOps workflow.
