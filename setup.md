# GitOps Setup Guide

This guide explains how to set up and deploy applications using ArgoCD and Docker Hub in a GitOps workflow.

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
└── setup.md                     # This guide
```

## Prerequisites

1. Minikube installed and running
2. kubectl configured
3. Docker Hub account
4. Git repository (e.g., GitHub)
5. ArgoCD installed on cluster

## Step 1: Docker Hub Setup

1. Create Docker Hub Account (if not already done):
   - Visit https://hub.docker.com/signup
   - Complete registration

2. Create Access Token:
   - Go to https://hub.docker.com/settings/security
   - Click "New Access Token"
   - Name it "k8s-gitops-ci"
   - Save the token securely

3. Add GitHub Secrets:
   - Go to your repository settings
   - Navigate to "Secrets and variables" → "Actions"
   - Add two secrets:
     ```
     DOCKER_USERNAME: your-docker-username
     DOCKER_PASSWORD: your-docker-access-token
     ```

## Step 2: Local Development

1. Build and test the Docker image locally:
   ```bash
   cd apps/dev/hello-app
   docker build -t your-docker-username/hello-app:test .
   docker run -p 8080:8080 your-docker-username/hello-app:test
   ```

2. Test the application:
   ```bash
   curl http://localhost:8080
   ```

## Step 3: Deploy to Kubernetes

1. Start Minikube (if not running):
   ```bash
   minikube start
   ```

2. Install ArgoCD:
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f bootstrap/argocd/install.yaml
   ```

3. Access ArgoCD UI:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
   Visit: https://localhost:8080

4. Get initial admin password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

5. Deploy the application:
   ```bash
   kubectl apply -f apps/dev/hello-app/argocd-app.yaml
   ```

## Step 4: Continuous Deployment

1. Push code changes to trigger deployment:
   ```bash
   git add .
   git commit -m "Update application"
   git push
   ```

2. GitHub Actions will:
   - Build new Docker image
   - Push to Docker Hub
   - Tag with commit SHA and 'latest'

3. ArgoCD will:
   - Detect changes in Git repository
   - Apply new Kubernetes manifests
   - Update application with new image

## Monitoring and Troubleshooting

1. Check application status in ArgoCD UI:
   - Green = Healthy and Synced
   - Yellow = Out of Sync
   - Red = Error

2. View application logs:
   ```bash
   kubectl logs -n hello-app -l app=hello-app
   ```

3. Check deployment status:
   ```bash
   kubectl get all -n hello-app
   ```

4. Force sync in case of issues:
   ```bash
   argocd app sync hello-app
   ```

## Best Practices

1. Always test changes locally before pushing
2. Use semantic versioning for releases
3. Monitor ArgoCD UI for sync status
4. Keep secrets in a separate, secure storage
5. Regularly update dependencies and base images

## Common Issues and Solutions

1. Image Pull Errors:
   - Verify Docker Hub credentials
   - Check image name and tag in deployment.yaml

2. Sync Failures:
   - Check ArgoCD logs
   - Verify Git repository access
   - Validate Kubernetes manifests

3. Application not accessible:
   - Check service and ingress configuration
   - Verify pod health and logs
   - Check resource constraints

## Cleanup

To remove the application:
```bash
kubectl delete -f apps/dev/hello-app/argocd-app.yaml
kubectl delete namespace hello-app
``` 