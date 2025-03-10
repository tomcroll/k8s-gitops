# Accessing Applications

This guide provides instructions for accessing applications deployed within the k8s-gitops environment, with a specific focus on the hello-app example.

## Service Access Configuration

### 1. ArgoCD Access
```bash
# Port forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8443:443

# Access ArgoCD UI
open https://localhost:8443

# Login with:
# Username: admin
# Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
```

### 2. Application Access (Local Development)
```bash
# Forward application port to avoid conflicts
kubectl port-forward svc/hello-app -n hello-app 9090:80

# Access the application in browser
open http://localhost:9090
```

## Exposing Applications Publicly

### 1. Using NodePort

NodePort is the simplest method for exposing applications in a development environment:

```bash
# Update the service type to NodePort
kubectl patch svc hello-app -n hello-app -p '{"spec": {"type": "NodePort"}}'

# Get the assigned NodePort
export NODE_PORT=$(kubectl get svc hello-app -n hello-app -o jsonpath='{.spec.ports[0].nodePort}')

# Get cluster IP
export CLUSTER_IP=$(minikube ip)

# Access URL
echo "http://$CLUSTER_IP:$NODE_PORT"
```

### 2. Using Ingress (Recommended)

For proper host-based routing with domain names:

```bash
# Enable Ingress controller (if using Minikube)
minikube addons enable ingress

# Verify Ingress controller is running
kubectl get pods -n ingress-nginx
```

Create an Ingress resource:

```yaml
# Save as apps/dev/hello-app/k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-app-ingress
  namespace: hello-app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: hello-app.local  # Use a proper domain in production
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

Apply and verify:

```bash
# Apply the configuration
kubectl apply -f apps/dev/hello-app/k8s/ingress.yaml

# Get Ingress status
kubectl get ingress -n hello-app

# For local testing, add DNS entry
echo "$(minikube ip) hello-app.local" | sudo tee -a /etc/hosts

# Access the application
open http://hello-app.local
```

### 3. Using LoadBalancer (Cloud Environments)

For cloud environments with built-in load balancer support:

```bash
# Update service type to LoadBalancer
kubectl patch svc hello-app -n hello-app -p '{"spec": {"type": "LoadBalancer"}}'

# Get external IP (may take a few minutes in cloud environments)
kubectl get svc hello-app -n hello-app -w
```

## Secure Access Configuration

### 1. TLS Setup

For secure HTTPS access:

```bash
# Generate self-signed certificate (development only)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout hello-app-tls.key \
  -out hello-app-tls.crt \
  -subj "/CN=hello-app.local/O=Hello App/C=US"

# Create TLS secret
kubectl create secret tls hello-app-tls -n hello-app \
  --cert=hello-app-tls.crt \
  --key=hello-app-tls.key

# Update Ingress with TLS
kubectl patch ingress hello-app-ingress -n hello-app -p '
{
  "spec": {
    "tls": [{
      "hosts": ["hello-app.local"],
      "secretName": "hello-app-tls"
    }]
  }
}'
```

### 2. Security Headers

Add security headers to your Ingress:

```bash
# Add security annotations
kubectl patch ingress hello-app-ingress -n hello-app -p '
{
  "metadata": {
    "annotations": {
      "nginx.ingress.kubernetes.io/force-ssl-redirect": "true",
      "nginx.ingress.kubernetes.io/ssl-redirect": "true",
      "nginx.ingress.kubernetes.io/proxy-body-size": "8m",
      "nginx.ingress.kubernetes.io/ssl-protocols": "TLSv1.2 TLSv1.3",
      "nginx.ingress.kubernetes.io/ssl-ciphers": "HIGH:!aNULL:!MD5"
    }
  }
}'
```

## Troubleshooting Access Issues

### 1. Verify Application Status
```bash
# Check pod status
kubectl get pods -n hello-app

# Check logs
kubectl logs -l app=hello-app -n hello-app

# Check service endpoints
kubectl get endpoints -n hello-app
```

### 2. Network Connectivity
```bash
# Test DNS resolution
kubectl run test-dns --rm -i --tty --image=busybox -n hello-app -- \
  nslookup hello-app.hello-app.svc.cluster.local

# Test network connectivity
kubectl run test-net --rm -i --tty --image=busybox -n hello-app -- \
  wget -qO- http://hello-app
```

### 3. Ingress Issues
```bash
# Check Ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# Verify Ingress resource
kubectl describe ingress hello-app-ingress -n hello-app
```

## Best Practices

1. **Security**
   - Always use HTTPS in production
   - Implement proper authentication
   - Use valid certificates from trusted authorities
   - Regularly rotate certificates

2. **Reliability**
   - Set appropriate timeouts
   - Configure health checks
   - Implement retries and circuit breakers
   - Use appropriate instance/replicas count

3. **Performance**
   - Enable compression
   - Configure caching when appropriate
   - Set reasonable rate limits
   - Monitor response times

4. **Observability**
   - Enable access logging
   - Monitor error rates
   - Set up alerts for availability issues
   - Track certificate expiration