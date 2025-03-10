# Kubernetes GitOps Monorepo

This repository follows the ArgoCD App of Apps pattern for managing Kubernetes deployments.

## Repository Structure

```
k8s-gitops/
├── apps/                    # Application definitions
│   ├── templates/          # Reusable application templates
│   ├── dev/               # Development environment applications
│   └── prod/              # Production environment applications
├── bootstrap/              # Bootstrap applications and configurations
│   ├── argocd/            # ArgoCD installation and configuration
│   └── apps/              # Root application definitions
└── infrastructure/         # Infrastructure components
    ├── monitoring/        # Monitoring stack (Prometheus, Grafana)
    ├── logging/          # Logging stack (EFK)
    └── ingress/          # Ingress controller and configurations
```

## Prerequisites

1. Minikube installed and running
2. kubectl configured
3. ArgoCD CLI installed
4. Helm v3 installed

## Quick Start

1. Start Minikube:
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

4. Get the initial admin password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

## Adding New Applications

1. Create application manifests in the appropriate environment directory under `apps/`
2. Update the root application in `bootstrap/apps/` to include the new application
3. Commit and push changes
4. ArgoCD will automatically detect and deploy the changes

## Development

- All application templates should go in `apps/templates/`
- Environment-specific values should be in the respective environment directories
- Infrastructure components should be in their respective directories under `infrastructure/`

## Best Practices

1. Use Kustomize for environment-specific configurations
2. Keep secrets in a separate repository using sealed-secrets
3. Use semantic versioning for application versions
4. Document all configuration parameters 