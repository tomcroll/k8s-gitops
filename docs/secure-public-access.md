# Secure Public Access Setup Guide

## 1. Ingress Controller Setup

### Enable and Configure Ingress
```bash
# Enable Ingress controller
minikube addons enable ingress

# Verify Ingress controller is running
kubectl get pods -n ingress-nginx

# Create namespace if not exists
kubectl create namespace hello-app
```

### Create Ingress Configuration
```yaml
# Save as hello-app-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-app-ingress
  namespace: hello-app
  annotations:
    # Security headers
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "8m"
    # Security policies
    nginx.ingress.kubernetes.io/security-policy: "default-src 'self'; frame-ancestors 'none'"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    # Rate limiting
    nginx.ingress.kubernetes.io/limit-rps: "10"
    nginx.ingress.kubernetes.io/limit-connections: "5"
    # SSL configuration
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    nginx.ingress.kubernetes.io/ssl-ciphers: "HIGH:!aNULL:!MD5"
    # HSTS
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
    nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
spec:
  tls:
  - hosts:
    - hello-app.local
    secretName: hello-app-tls
  rules:
  - host: hello-app.local
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

## 2. TLS Certificate Setup

### Generate Self-Signed Certificate (Development)
```bash
# Generate private key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout hello-app-tls.key \
  -out hello-app-tls.crt \
  -subj "/CN=hello-app.local/O=Hello App/C=US"

# Create TLS secret
kubectl create secret tls hello-app-tls \
  -n hello-app \
  --cert=hello-app-tls.crt \
  --key=hello-app-tls.key
```

### Production Certificate Setup (Let's Encrypt)
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer
cat <<EOF | kubectl apply -f -
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
EOF

# Update Ingress for cert-manager
kubectl patch ingress hello-app-ingress -n hello-app -p '
{
  "metadata": {
    "annotations": {
      "cert-manager.io/cluster-issuer": "letsencrypt-prod"
    }
  }
}'
```

## 3. Security Enhancements

### Network Policies
```yaml
# Save as hello-app-network-policy.yaml
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
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53 # DNS
    - protocol: UDP
      port: 53 # DNS
```

### Pod Security Context
```yaml
# Update deployment with security context
kubectl patch deployment hello-app -n hello-app --type=json -p '[
  {
    "op": "add",
    "path": "/spec/template/spec/securityContext",
    "value": {
      "runAsNonRoot": true,
      "runAsUser": 1000,
      "fsGroup": 2000,
      "seccompProfile": {
        "type": "RuntimeDefault"
      }
    }
  }
]'
```

## 4. Monitoring and Logging

### Enable Access Logging
```yaml
# Update Ingress annotations
kubectl patch ingress hello-app-ingress -n hello-app --type=merge -p '
{
  "metadata": {
    "annotations": {
      "nginx.ingress.kubernetes.io/enable-access-log": "true",
      "nginx.ingress.kubernetes.io/configuration-snippet": "access_log /var/log/nginx/hello-app_access.log combined buffer=512k flush=1m;"
    }
  }
}'
```

### Prometheus Metrics
```yaml
# Add Prometheus annotations
kubectl patch deployment hello-app -n hello-app --type=merge -p '
{
  "metadata": {
    "annotations": {
      "prometheus.io/scrape": "true",
      "prometheus.io/port": "80",
      "prometheus.io/path": "/metrics"
    }
  }
}'
```

## 5. Verification Steps

### Test TLS Configuration
```bash
# Verify certificate
curl -vI --insecure https://hello-app.local

# Check TLS version and cipher
openssl s_client -connect hello-app.local:443 -tls1_2
```

### Test Security Headers
```bash
# Check security headers
curl -I https://hello-app.local
```

### Test Rate Limiting
```bash
# Test rate limits
for i in {1..20}; do
  curl -I https://hello-app.local
  sleep 0.1
done
```

## 6. Production Checklist

1. **DNS Configuration**
   - Configure proper DNS records
   - Set appropriate TTL values
   - Consider using DNS provider's proxy/CDN

2. **Certificate Management**
   - Use production Let's Encrypt certificates
   - Set up automatic renewal
   - Monitor certificate expiration

3. **Security Measures**
   - Enable WAF rules
   - Set up DDoS protection
   - Configure IP whitelisting if needed

4. **Monitoring**
   - Set up uptime monitoring
   - Configure error alerting
   - Monitor TLS certificate expiration
   - Track response times and error rates

5. **Backup and Recovery**
   - Backup TLS certificates and keys
   - Document recovery procedures
   - Test restore processes

6. **Documentation**
   - Update access documentation
   - Document security configurations
   - Maintain incident response plans 