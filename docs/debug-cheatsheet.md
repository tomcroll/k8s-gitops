# Kubernetes & ArgoCD Debugging Cheat Sheet

This cheat sheet provides quick commands and troubleshooting steps for the k8s-gitops repository.

## Quick Commands

### Pod Status
```bash
# Get all resources in namespace
kubectl get all -n hello-app

# Watch pod status
kubectl get pods -n hello-app -w

# Get pod details
kubectl describe pod -n hello-app POD_NAME

# Get logs
kubectl logs -n hello-app POD_NAME
kubectl logs -n hello-app -l app=hello-app --all-containers
```

### ArgoCD Commands
```bash
# Application status
argocd app get hello-app
argocd app list

# Force sync
argocd app sync hello-app --force

# Show diff
argocd app diff hello-app

# Application history
argocd app history hello-app

# Get app events
kubectl get events -n argocd --field-selector involvedObject.name=hello-app
```

### Docker Commands
```bash
# Test build locally
docker build -t tomcroll/hello-app:test -f apps/dev/hello-app/Dockerfile apps/dev/hello-app

# Check image layers
docker history tomcroll/hello-app:latest

# Run interactive container
docker run -it --rm tomcroll/hello-app:latest sh
```

### Deployment Script
```bash
# Run deployment script with debug mode
DEBUG=true ./scripts/deploy.sh

# Check deployment log
cat apps/dev/hello-app/deployments.log

# Update config and redeploy
vim scripts/config.env
./scripts/deploy.sh
```

## Common Error Messages

### Pod Errors
| Error Message | Common Causes | Solution |
|--------------|---------------|----------|
| `ImagePullBackOff` | - Wrong image name<br>- Registry auth failed | - Check image name in deployment.yaml<br>- Verify Docker Hub credentials |
| `CrashLoopBackOff` | - Application crash<br>- Missing config | - Check container logs<br>- Verify environment variables |
| `Pending` | - Resource limits<br>- Node issues | - Check node capacity with `kubectl describe node`<br>- Adjust resource requests |
| `Error` | - Application error<br>- Volume issues | - Check events with `kubectl get events`<br>- Verify storage configuration |

### ArgoCD Errors
| Error Message | Common Causes | Solution |
|--------------|---------------|----------|
| `OutOfSync` | - Git changes<br>- Manual kubectl changes | - Check Git history<br>- Run `argocd app sync hello-app --force` |
| `Degraded` | - Health check failed<br>- Resource issues | - Check application logs<br>- Verify deployment status |
| `ComparisonError` | - Manifest issues<br>- Network problems | - Validate YAML with `kubectl apply --dry-run`<br>- Check connectivity |
| `SyncFailed` | - Permissions issues<br>- Invalid resources | - Check ArgoCD logs<br>- Verify resource definitions |

## Health Checks

### System Health
```bash
# Node status
kubectl get nodes
kubectl describe node $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# Resource usage
kubectl top nodes
kubectl top pods -n hello-app

# Cluster components
kubectl get componentstatuses
```

### Network Health
```bash
# DNS check
kubectl run test-dns -n hello-app --rm -i --tty --image=busybox -- nslookup hello-app.hello-app.svc.cluster.local

# Service check
kubectl run test-curl -n hello-app --rm -i --tty --image=curlimages/curl -- curl http://hello-app

# Port forward check
lsof -i :8081  # Check if port is in use
```

### Storage Health
```bash
# PVC status
kubectl get pvc -n hello-app
kubectl describe pvc -n hello-app

# Storage class
kubectl get storageclass
```

## Debug Modes

### Interactive Debugging
```bash
# Shell into container
kubectl exec -it -n hello-app $(kubectl get pod -l app=hello-app -n hello-app -o jsonpath='{.items[0].metadata.name}') -- /bin/sh

# Copy files from pod
kubectl cp hello-app/$(kubectl get pod -l app=hello-app -n hello-app -o jsonpath='{.items[0].metadata.name}'):/app/log.txt ./log-local.txt

# Run temporary debug pod
kubectl run debug-pod -n hello-app --rm -i --tty --image=ubuntu -- bash
```

### Network Debugging
```bash
# Check endpoints
kubectl get endpoints -n hello-app

# Test connectivity
kubectl run netcat -n hello-app --rm -i --tty --image=busybox -- nc -vz hello-app 80

# Check ingress
kubectl describe ingress -n hello-app
```

### GitOps Debugging
```bash
# Check Git repo state
git status
git log -p -n 1  # Last commit details

# Verify ArgoCD repo connection
argocd repo list
argocd repo get https://github.com/yourusername/k8s-gitops.git
```

## Recovery Commands

### Application Reset
```bash
# Delete and recreate pods
kubectl delete pod -n hello-app -l app=hello-app

# Scale deployment
kubectl scale deployment -n hello-app hello-app --replicas=0
kubectl scale deployment -n hello-app hello-app --replicas=2

# Force rollout
kubectl rollout restart deployment -n hello-app hello-app
```

### ArgoCD Reset
```bash
# Hard refresh
argocd app delete hello-app --cascade=false
kubectl apply -f apps/dev/hello-app/argocd-app.yaml

# Terminate operation
argocd app terminate-op hello-app

# Refresh from Git
argocd app get hello-app --refresh
```

### Clean Restart
```bash
# Full namespace cleanup
kubectl delete namespace hello-app
kubectl create namespace hello-app

# Redeploy application
./scripts/deploy.sh

# Reset ArgoCD
kubectl -n argocd delete pod -l app.kubernetes.io/name=argocd-server
```

## Specific Troubleshooting Scenarios

### 1. Deployment Not Updating
```bash
# Check if image is updated in deployment
kubectl get deployment hello-app -n hello-app -o jsonpath='{.spec.template.spec.containers[0].image}'

# Verify ArgoCD auto-sync status
argocd app get hello-app | grep "Auto-Sync"

# Force sync
argocd app sync hello-app --force
```

### 2. Application Crash Issues
```bash
# Get recent crash logs
kubectl logs -n hello-app -l app=hello-app --previous

# Check resource constraints
kubectl describe pod -n hello-app -l app=hello-app | grep -A 3 "Requests"

# Check environment variables
kubectl describe pod -n hello-app -l app=hello-app | grep -A 20 "Environment"
```

### 3. Network Connectivity Issues
```bash
# Check DNS resolution
kubectl run test-dns -n hello-app --rm -i --tty --image=busybox -- nslookup kubernetes.default

# Test service connectivity
kubectl run test-curl -n hello-app --rm -i --tty --image=curlimages/curl -- curl -v http://hello-app.hello-app.svc.cluster.local

# Verify network policies
kubectl get networkpolicy -n hello-app
``` 