# Security Guide

This document provides security best practices and configurations for the k8s-gitops repository.

## Repository Security

### Git Security
```bash
# Verify .gitignore excludes sensitive files
cat .gitignore

# Check for sensitive files that may have been committed
git ls-files | grep -E '(password|token|secret|key|credential)'

# Scan repository for secrets
# Install gitleaks: https://github.com/zricethezav/gitleaks
gitleaks detect --source .
```

### File Permissions
```bash
# Ensure script files have proper permissions
chmod 755 scripts/deploy.sh

# Ensure sensitive files are protected
chmod 600 scripts/config.env
```

## Authentication & Authorization

### ArgoCD Security

#### User Management
```bash
# Create a new user
argocd account create <username>

# Update user password
argocd account update-password --account <username>

# Configure RBAC
argocd proj role create <project> <role-name>
```

#### SSO Configuration
```yaml
# Example SSO configuration in bootstrap/argocd/argocd-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  dex.config: |
    connectors:
      - type: github
        id: github
        name: GitHub
        config:
          clientID: <client-id>
          clientSecret: <client-secret>
```

### Kubernetes Security

#### RBAC Configuration
```yaml
# Example Role in apps/dev/hello-app/k8s/rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: hello-app-role
  namespace: hello-app
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]

# Example RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: hello-app-role-binding
  namespace: hello-app
subjects:
- kind: ServiceAccount
  name: hello-app-sa
  namespace: hello-app
roleRef:
  kind: Role
  name: hello-app-role
  apiGroup: rbac.authorization.k8s.io
```

#### Service Accounts
```yaml
# Example in apps/dev/hello-app/k8s/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hello-app-sa
  namespace: hello-app
```

## Network Security

### Pod Security

#### Security Context
```yaml
# Example security context in apps/dev/hello-app/k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-app
  namespace: hello-app
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: hello-app
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
```

#### Network Policies
```yaml
# Example in apps/dev/hello-app/k8s/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: hello-app-network-policy
  namespace: hello-app
spec:
  podSelector:
    matchLabels:
      app: hello-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: argocd
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

### TLS Configuration

#### ArgoCD TLS
```yaml
# Example in bootstrap/argocd/argocd-secret.yaml (do not commit real secrets)
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
type: Opaque
data:
  # Placeholders - replace with actual base64 encoded values
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
```

#### Application TLS
```yaml
# Example in apps/dev/hello-app/k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-app-ingress
  namespace: hello-app
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - hello-app.example.com
    secretName: hello-app-tls
```

## Container Security

### Image Security

#### Scanning
```bash
# Scan image for vulnerabilities using Trivy
# Install Trivy: https://aquasecurity.github.io/trivy/
trivy image tomcroll/hello-app:latest

# Scan using Docker Scout
docker scout cves tomcroll/hello-app:latest
```

#### Pull Secrets
```yaml
# Example in apps/dev/hello-app/k8s/pull-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: docker-registry-cred
  namespace: hello-app
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>

# Use in deployment
spec:
  template:
    spec:
      imagePullSecrets:
      - name: docker-registry-cred
```

### Registry Security

#### Private Registry
```yaml
# Use private registry in deployment
spec:
  template:
    spec:
      containers:
      - name: hello-app
        image: private-registry.example.com/hello-app:latest
      imagePullSecrets:
      - name: registry-secret
```

## Secret Management

### GitOps Secrets

#### Environment Variables
```bash
# Configure environment-specific variables in config.env (not committed)
# Example usage in scripts/deploy.sh
source scripts/config.env
```

#### Kubernetes Secrets
```yaml
# Example Secret (placeholder, never commit actual secrets)
apiVersion: v1
kind: Secret
metadata:
  name: hello-app-secret
  namespace: hello-app
type: Opaque
data:
  api-key: <base64-encoded-value>
  
# Reference in deployment
env:
- name: API_KEY
  valueFrom:
    secretKeyRef:
      name: hello-app-secret
      key: api-key
```

#### External Secrets
```yaml
# Example using External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: hello-app-secret
  namespace: hello-app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: hello-app-secret
  data:
  - secretKey: api-key
    remoteRef:
      key: hello-app/api-key
```

## Compliance & Auditing

### Audit Logging

#### Enable Audit Logging
```yaml
# Example audit policy for Minikube or K3s
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
  - group: ""
    resources: ["pods", "services"]
```

#### Log Collection
```yaml
# Example fluentd configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
data:
  fluent.conf: |
    <match kubernetes.**>
      @type elasticsearch
      host elasticsearch-logging
      port 9200
      logstash_format true
    </match>
```

### Compliance Checks

#### Policy Enforcement
```yaml
# Using OPA/Gatekeeper
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-labels
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Namespace"]
  parameters:
    labels: ["environment", "owner"]
```

## Best Practices

### Access Control
- Use RBAC with least privilege
- Regularly rotate credentials
- Implement MFA where possible
- Audit permissions regularly

### Network Security
- Use network policies
- Enable TLS everywhere
- Regularly update certificates
- Segment network traffic by namespace

### Container Security
- Use minimal base images
- Run containers as non-root
- Set appropriate resource limits
- Enable read-only filesystem when possible
- Scan images for vulnerabilities

### Secret Management
- Never commit secrets to Git
- Rotate secrets regularly
- Monitor secret access
- Use dedicated secret management tools

### Compliance
- Regularly run security audits
- Keep documentation updated
- Perform penetration testing
- Monitor and fix CVEs

### CI/CD Security
- Secure build pipelines
- Validate manifests before deployment
- Implement progressive delivery
- Run security scans in pipeline 