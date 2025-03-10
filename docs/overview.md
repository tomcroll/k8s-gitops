# K8s-GitOps Repository Overview

This document provides an overview of the GitOps repository structure, workflow, and best practices for maintaining and deploying applications using ArgoCD.

## Repository Structure

```
k8s-gitops/
├── apps/                   # Application definitions
│   ├── templates/          # Reusable application templates
│   └── dev/                # Development environment applications
│       └── hello-app/      # Example "hello-app" application
│           ├── src/        # Application source code
│           ├── k8s/        # Kubernetes manifests
│           ├── Dockerfile  # Container image definition
│           └── argocd-app.yaml  # ArgoCD application definition
├── bootstrap/              # Bootstrap components
│   ├── argocd/             # ArgoCD installation manifests
│   └── apps/               # Root application definitions
├── docs/                   # Documentation
│   ├── access.md           # Application access guide
│   ├── aws-loadbalancer-setup.md # AWS load balancer setup
│   ├── debug-cheatsheet.md # Debugging reference
│   ├── monitoring.md       # Monitoring guide
│   ├── os-setup.md         # OS-specific setup instructions
│   ├── overview.md         # This document
│   ├── production-security.md # Production security guide
│   └── security.md         # Security best practices
├── scripts/                # Automation scripts
│   ├── deploy.sh           # Deployment script
│   └── config.env          # Configuration variables
├── terraform/              # Infrastructure as Code 
│   └── aws-lb-controller.tf # AWS Load Balancer Controller setup
├── .gitignore              # Git ignore patterns
├── README.md               # Repository introduction
└── setup.md                # Setup instructions
```

## GitOps Workflow

This repository implements a GitOps workflow with ArgoCD, following these principles:

1. **Declarative**: All system configurations are defined declaratively in the repository
2. **Versioned and Immutable**: All changes are stored in Git with full history
3. **Pulled Automatically**: ArgoCD pulls changes and applies them to the cluster
4. **Continuously Reconciled**: System state is continuously compared with the desired state

### Workflow Stages:

1. **Development**
   - Update application code in `apps/dev/[app-name]/src`
   - Test locally using Docker

2. **Build and Publish**
   - Build container image using Dockerfile
   - Tag with timestamp and/or semantic versioning
   - Push to container registry (e.g., Docker Hub)

3. **Update Manifests**
   - Update Kubernetes manifests in `apps/dev/[app-name]/k8s`
   - Reference the new container image tag

4. **Commit and Push**
   - Commit and push changes to the Git repository
   - ArgoCD detects changes

5. **Deployment**
   - ArgoCD automatically synchronizes the application state
   - Deployment is tracked in ArgoCD UI

## Security Considerations

This repository follows several security best practices:

1. **Secret Management**
   - Sensitive information excluded via `.gitignore`
   - Environment-specific values stored in `config.env` (not committed)
   - Production secrets should use sealed-secrets or external vault

2. **Access Controls**
   - Role-based access control (RBAC) for applications
   - Principle of least privilege for service accounts
   - Network policies to restrict traffic

3. **Image Security**
   - Regular scanning of container images
   - Non-root users in containers
   - Immutable tags for container images

## Documentation Structure

The `/docs` directory contains detailed documentation on various aspects:

- **access.md**: How to access applications deployed in the cluster
- **aws-loadbalancer-setup.md**: AWS Load Balancer Controller configuration
- **debug-cheatsheet.md**: Quick reference for debugging issues
- **monitoring.md**: Setting up and using monitoring tools
- **os-setup.md**: OS-specific setup instructions
- **overview.md**: This overview document
- **production-security.md**: Security configurations for production
- **security.md**: General security guidelines

## Getting Started

Refer to the `setup.md` file in the root directory for step-by-step instructions on setting up the environment and deploying your first application.

## Best Practices

1. **Application Configuration**
   - Use a consistent directory structure for applications
   - Separate application code from Kubernetes manifests
   - Document application-specific requirements

2. **Deployment Strategy**
   - Use the automated deployment script for consistency
   - Log all deployments for audit trail
   - Monitor health checks after deployment

3. **Maintenance**
   - Regularly update base images
   - Apply security patches promptly
   - Monitor resource usage and adjust limits

4. **Documentation**
   - Update documentation when making significant changes
   - Document configuration options
   - Maintain troubleshooting guides 