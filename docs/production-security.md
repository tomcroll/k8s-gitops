# Production Security Implementation Guide

## 1. Production Certificate Setup with Let's Encrypt

### Install and Configure Cert-Manager
```bash
# Create cert-manager namespace
kubectl create namespace cert-manager

# Install cert-manager with CRDs
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Verify installation
kubectl get pods -n cert-manager
```

### Configure Let's Encrypt Staging (For Testing)
```yaml
# Save as staging-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
```

### Configure Let's Encrypt Production
```yaml
# Save as production-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

### Update Ingress for Automatic Certificate Management
```yaml
# Save as hello-app-ingress-prod.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-app-ingress
  namespace: hello-app
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    acme.cert-manager.io/http01-edit-in-place: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - hello-app.example.com
    secretName: hello-app-tls-prod
  rules:
  - host: hello-app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-app
            port:
              number: 80
```

## 2. Enhanced Security Measures

### Pod Security Policy
```yaml
# Save as hello-app-psp.yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: hello-app-psp
spec:
  privileged: false
  seLinux:
    rule: RunAsAny
  runAsUser:
    rule: MustRunAsNonRoot
    ranges:
    - min: 1000
      max: 65535
  fsGroup:
    rule: MustRunAs
    ranges:
    - min: 1000
      max: 65535
  volumes:
  - 'configMap'
  - 'emptyDir'
  - 'projected'
  - 'secret'
  - 'downwardAPI'
```

### Advanced Network Policy
```yaml
# Save as hello-app-network-policy-enhanced.yaml
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
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  - to:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
```

### Security Context Configuration
```yaml
# Save as hello-app-security-context.yaml
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
        capabilities:
          drop:
          - ALL
      containers:
      - name: hello-app
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
```

## 3. Comprehensive Monitoring Setup

### Install Prometheus Stack
```bash
# Add Prometheus repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=your-secure-password
```

### Configure Service Monitoring
```yaml
# Save as hello-app-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: hello-app-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: hello-app
  namespaceSelector:
    matchNames:
    - hello-app
  endpoints:
  - port: http
    interval: 15s
    path: /metrics
```

### Grafana Dashboard
```yaml
# Save as hello-app-dashboard.json
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "panels": [
    {
      "title": "Request Rate",
      "type": "graph",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "rate(http_requests_total{app=\"hello-app\"}[5m])",
          "legendFormat": "{{method}} {{path}}"
        }
      ]
    },
    {
      "title": "Error Rate",
      "type": "graph",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "rate(http_requests_total{app=\"hello-app\", status=~\"5..\"}[5m])",
          "legendFormat": "{{method}} {{path}}"
        }
      ]
    }
  ]
}
```

### Alert Rules
```yaml
# Save as hello-app-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: hello-app-alerts
  namespace: monitoring
spec:
  groups:
  - name: hello-app
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{app="hello-app",status=~"5.."}[5m]) > 1
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: High error rate detected
        description: Error rate is above 1 req/s for 5 minutes
    - alert: HighLatency
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="hello-app"}[5m])) > 2
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: High latency detected
        description: 95th percentile latency is above 2s for 5 minutes
```

## 4. Implementation Steps

1. **Certificate Setup**:
```bash
# Apply issuers
kubectl apply -f staging-issuer.yaml
kubectl apply -f production-issuer.yaml

# Apply production ingress
kubectl apply -f hello-app-ingress-prod.yaml

# Verify certificate
kubectl get certificate -n hello-app
kubectl describe certificate hello-app-tls-prod -n hello-app
```

2. **Security Implementation**:
```bash
# Apply security policies
kubectl apply -f hello-app-psp.yaml
kubectl apply -f hello-app-network-policy-enhanced.yaml
kubectl apply -f hello-app-security-context.yaml

# Verify security context
kubectl get psp
kubectl describe networkpolicy -n hello-app
```

3. **Monitoring Setup**:
```bash
# Apply monitoring configurations
kubectl apply -f hello-app-servicemonitor.yaml
kubectl apply -f hello-app-alerts.yaml

# Import Grafana dashboard
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# Then import hello-app-dashboard.json via Grafana UI
```

## 5. Verification

### Certificate Verification
```bash
# Check certificate status
kubectl get certificate -n hello-app
kubectl get certificaterequest -n hello-app
kubectl get order -n hello-app -o wide
```

### Security Verification
```bash
# Test network policies
kubectl run test-connection --rm -i --tty \
  --image=busybox -n hello-app -- wget -qO- http://hello-app

# Verify security context
kubectl get pods -n hello-app -o yaml | grep -A 20 securityContext
```

### Monitoring Verification
```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus-operated 9090:9090 -n monitoring
# Access http://localhost:9090/targets

# Check Grafana dashboards
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# Access http://localhost:3000
```

## 6. Maintenance

### Certificate Renewal
```bash
# Check certificate expiry
kubectl get certificate -n hello-app -o jsonpath='{.items[*].status.notAfter}'

# Force renewal if needed
kubectl delete secret hello-app-tls-prod -n hello-app
```

### Security Updates
```bash
# Update security policies
kubectl apply -f hello-app-security-context.yaml

# Rotate pods
kubectl rollout restart deployment hello-app -n hello-app
```

### Monitoring Updates
```bash
# Update Prometheus rules
kubectl apply -f hello-app-alerts.yaml

# Verify rules
kubectl get prometheusrule -n monitoring
``` 