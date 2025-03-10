# GitOps Setup Guide

This guide explains how to set up and deploy applications using ArgoCD and Docker Hub in a GitOps workflow.

## Quick Start Guide

### Prerequisites Installation
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install kubectl minikube docker argocd

# Start Docker Desktop
open -a Docker
```

### Initial Setup (5 minutes)
1. **Start Kubernetes**:
   ```bash
   minikube start
   ```

2. **Clone Repository**:
   ```bash
   git clone https://github.com/YOUR_USERNAME/k8s-gitops.git
   cd k8s-gitops
   ```

3. **Configure Environment**:
   ```bash
   # Edit config.env with your details
   vim scripts/config.env
   ```

4. **Deploy ArgoCD**:
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f bootstrap/argocd/install.yaml
   ```

### Deploy Application (2 minutes)
```bash
# Make deployment script executable
chmod +x scripts/deploy.sh

# Deploy application
./scripts/deploy.sh
```

### Access Application
```bash
# Get ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD UI (in a new terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Visit https://localhost:8080 (username: admin)

# Access application (in a new terminal)
kubectl port-forward svc/hello-app -n hello-app 8081:80
# Visit http://localhost:8081
```

## Repository Structure

```
k8s-gitops/
├── apps/
│   └── dev/
│       └── hello-app/           # Sample Flask application
│           ├── src/             # Application source code
│           ├── k8s/             # Kubernetes manifests
│           ├── Dockerfile       # Container image definition
│           └── argocd-app.yaml  # ArgoCD application manifest
├── bootstrap/
│   └── argocd/
│       └── install.yaml         # ArgoCD installation manifest
├── scripts/
│   ├── deploy.sh               # Automated deployment script
│   └── config.env              # Deployment configuration
└── setup.md                     # This guide
```

## Current Configuration

### Application Structure
- **Language**: Python/Flask
- **Container**: Python 3.11 slim image
- **Port**: 8080 (container), 80 (service)
- **Health Check**: HTTP endpoint at /
- **Environment Variables**:
  - ENVIRONMENT (default: production)
  - VERSION (default: 1.0.0)

### Deployment Configuration
```env
# Docker settings
DOCKER_USERNAME="tomcroll"
APP_NAME="hello-app"

# Kubernetes settings
NAMESPACE="hello-app"
PORT=8081

# Git settings
GIT_BRANCH="main"
```

## Deployment Methods

### 1. Automated Deployment (Recommended)
Using the deployment script:
```bash
# Make script executable (first time only)
chmod +x scripts/deploy.sh

# Deploy new version
./scripts/deploy.sh
```

The script will:
- Build and tag Docker image with timestamp
- Push to Docker Hub
- Update Kubernetes manifests
- Commit and push changes
- Wait for ArgoCD sync
- Set up port forwarding
- Log deployment details

### 2. Manual Deployment Steps

#### a. Build and Push Image
```bash
cd apps/dev/hello-app
docker build -t your-username/hello-app:version .
docker push your-username/hello-app:version
```

#### b. Update Manifests
```bash
# Update image in k8s/deployment.yaml
kubectl apply -f k8s/deployment.yaml
```

#### c. Monitor in ArgoCD
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Continuous Deployment Flow

1. **Image Building**:
   - Images tagged with timestamp and 'latest'
   - Pushed to Docker Hub repository
   - Automated by deploy.sh or GitHub Actions

2. **GitOps Process**:
   - Deployment manifests updated with new image
   - Changes committed and pushed to Git
   - ArgoCD detects changes and syncs

3. **Monitoring**:
   - Deployment status tracked in ArgoCD UI
   - Logs available in deployments.log
   - Health checks via Kubernetes probes

## Configuration Files

### 1. config.env
Contains environment-specific settings:
- Docker credentials and image names
- Application paths and ports
- Git configuration
- Namespace settings

### 2. deployment.yaml
Kubernetes deployment configuration:
- Resource limits: 200m CPU, 256Mi memory
- Resource requests: 100m CPU, 128Mi memory
- Replicas: 2
- Service type: ClusterIP
- Ingress configuration

### 3. argocd-app.yaml
ArgoCD application settings:
- Auto-sync enabled
- Self-healing enabled
- Prune resources enabled
- Namespace creation automated

## Monitoring and Logs

1. **Deployment Logs**:
   ```bash
   cat apps/dev/hello-app/deployments.log
   ```

2. **Application Logs**:
   ```bash
   kubectl logs -n hello-app -l app=hello-app
   ```

3. **ArgoCD Status**:
   ```bash
   argocd app get hello-app
   ```

## Best Practices

1. **Version Control**:
   - Use timestamp-based versioning for images
   - Keep deployment history in deployments.log
   - Maintain Git history for all changes

2. **Configuration Management**:
   - Store sensitive data in secrets
   - Use config.env for environment settings
   - Keep resource limits appropriate

3. **Monitoring**:
   - Regular health checks
   - Resource usage monitoring
   - Deployment status tracking

## Troubleshooting

### 1. Deployment Issues

#### a. Pod Stuck in Pending State
```bash
# Check pod status
kubectl get pods -n hello-app
kubectl describe pod -n hello-app <pod-name>

# Common causes and solutions:
# - Resource limits: Adjust CPU/memory in deployment.yaml
# - Node capacity: Check node resources
minikube node list
kubectl describe node minikube
```

#### b. Image Pull Errors
```bash
# Check pod events
kubectl describe pod -n hello-app <pod-name>

# Verify Docker login
docker login

# Check image availability
docker pull tomcroll/hello-app:latest

# Manual image push if needed
docker push tomcroll/hello-app:latest
```

#### c. Application Crash Loop
```bash
# Check container logs
kubectl logs -n hello-app <pod-name> --previous

# Check resource usage
kubectl top pod -n hello-app

# Debug with interactive shell
kubectl exec -it -n hello-app <pod-name> -- /bin/bash
```

### 2. ArgoCD Sync Issues

#### a. Git Repository Problems
```bash
# Check ArgoCD repo status
argocd repo list
argocd repo get https://github.com/YOUR_USERNAME/k8s-gitops.git

# Refresh repository
argocd repo refresh
```

#### b. Sync Failures
```bash
# Check sync status
argocd app get hello-app

# View detailed sync problems
argocd app logs hello-app

# Force sync with pruning
argocd app sync hello-app --prune
```

#### c. Resource Health Issues
```bash
# Check resource health
argocd app resources hello-app

# Verify Kubernetes events
kubectl get events -n hello-app --sort-by='.lastTimestamp'
```

### 3. Networking Issues

#### a. Service Unreachable
```bash
# Check service status
kubectl get svc -n hello-app
kubectl describe svc hello-app -n hello-app

# Test service DNS
kubectl run test-dns --image=busybox:1.28 -n hello-app --rm -it -- nslookup hello-app
```

#### b. Ingress Problems
```bash
# Verify ingress configuration
kubectl get ingress -n hello-app
kubectl describe ingress hello-app -n hello-app

# Check ingress controller
kubectl get pods -n ingress-nginx
```

#### c. Port Forwarding Issues
```bash
# Kill existing port forwards
pkill -f "kubectl port-forward"

# Try alternative ports
kubectl port-forward svc/hello-app -n hello-app 8082:80
```

### 4. Common Error Scenarios

#### a. "ImagePullBackOff" Error
```bash
# Solution steps:
1. Verify image name and tag in deployment.yaml
2. Check Docker Hub credentials
3. Try manual pull to verify access
4. Update image pull secrets if needed
```

#### b. "CrashLoopBackOff" Error
```bash
# Solution steps:
1. Check application logs
2. Verify environment variables
3. Check resource limits
4. Test application locally
```

#### c. "Pending" State
```bash
# Solution steps:
1. Check node resources
2. Verify PVC status if using storage
3. Check node taints and tolerations
4. Adjust resource requests
```

### 5. Recovery Procedures

#### a. Reset Deployment
```bash
# Recreate deployment
kubectl delete -f k8s/deployment.yaml
kubectl apply -f k8s/deployment.yaml

# Force new image pull
kubectl patch deployment hello-app -n hello-app -p \
  '{"spec":{"template":{"metadata":{"annotations":{"kubectl.kubernetes.io/restartedAt":"'$(date +%s)'"}}}}}'
```

#### b. Clean Slate Reset
```bash
# Remove and recreate everything
kubectl delete namespace hello-app
kubectl create namespace hello-app
./scripts/deploy.sh
```

#### c. ArgoCD Reset
```bash
# Reset ArgoCD application
argocd app delete hello-app
kubectl apply -f apps/dev/hello-app/argocd-app.yaml
```

## Cleanup

1. **Remove Application**:
   ```