# Monitoring Guide

This guide explains how to monitor applications and infrastructure in the k8s-gitops repository, including best practices for observability.

## Monitoring Components

### ArgoCD Monitoring

#### Application Health
```bash
# Get application status
argocd app get hello-app

# Watch application sync status
argocd app watch hello-app

# Get detailed sync status
argocd app sync hello-app --prune
```

#### Resource Status
```bash
# Check application resources
argocd app resources hello-app

# View application events
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Check sync history
argocd app history hello-app
```

### Kubernetes Monitoring

#### Pod Health
```bash
# Get pod status
kubectl get pods -n hello-app

# Get detailed pod information
kubectl describe pod <pod-name> -n hello-app

# View pod logs
kubectl logs <pod-name> -n hello-app

# Watch pod status in real-time
kubectl get pods -n hello-app -w
```

#### Service Health
```bash
# Check service status
kubectl get svc -n hello-app

# Test service connectivity
kubectl port-forward svc/hello-app 8080:80 -n hello-app

# Access in browser
curl http://localhost:8080
```

#### Resource Usage
```bash
# Get node resource usage
kubectl top nodes

# Get pod resource usage
kubectl top pods -n hello-app

# Get detailed resource metrics
kubectl describe nodes | grep -A 5 "Resource"
```

### Container Monitoring

#### Docker Status
```bash
# List running containers
docker ps | grep hello-app

# View container logs
docker logs <container-id>

# Check container resource usage
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

#### Image Management
```bash
# List local images
docker images | grep hello-app

# Check image history
docker history tomcroll/hello-app:latest

# Remove unused images
docker image prune -a
```

## Setting Up Monitoring Tools

### Metrics Server
```bash
# Enable metrics server in Minikube
minikube addons enable metrics-server

# Verify metrics server
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
```

### Prometheus & Grafana

#### Installation
```bash
# Add Prometheus repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus stack
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring

# Access Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# Default credentials: admin/prom-operator
```

#### Adding Custom Dashboards
```bash
# Example dashboard for hello-app
# Save as monitoring/hello-app-dashboard.json
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "panels": [
    {
      "title": "Request Rate",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "sum(rate(http_requests_total{app=\"hello-app\"}[5m])) by (path)"
        }
      ]
    },
    {
      "title": "Error Rate",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "sum(rate(http_requests_total{app=\"hello-app\", status=~\"5..\"}[5m])) by (path)"
        }
      ]
    }
  ]
}
```

### Application Health Checks

#### Adding Health Probes
```yaml
# Example probe configuration in k8s/deployment.yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 3
  periodSeconds: 3

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

#### Implementing Health Endpoints
```python
# Example Flask health endpoint in src/app.py
@app.route('/health')
def health():
    return jsonify(status="healthy"), 200

@app.route('/ready')
def ready():
    return jsonify(status="ready"), 200
```

## Setting Up Alerts

### Prometheus Alerting
```yaml
# Save as monitoring/hello-app-alerts.yaml
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
      expr: sum(rate(http_requests_total{app="hello-app",status=~"5.."}[5m])) > 1
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: High error rate detected
        description: Error rate is above 1 req/s for 5 minutes
    - alert: SlowResponseTime
      expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{app="hello-app"}[5m])) by (le)) > 2
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: Slow response times detected
        description: 95th percentile latency is above 2s for 5 minutes
```

### ArgoCD Notifications
```yaml
# Update argocd-app.yaml with notifications
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hello-app
  namespace: argocd
  annotations:
    notifications.argoproj.io/subscribe.on-sync-succeeded: "slack:deployments"
    notifications.argoproj.io/subscribe.on-sync-failed: "slack:deployments"
    notifications.argoproj.io/subscribe.on-health-degraded: "slack:alerts"
```

## Logging Configuration

### Container Logging
```yaml
# Update k8s/deployment.yaml
containers:
- name: hello-app
  image: tomcroll/hello-app:latest
  env:
  - name: LOG_LEVEL
    value: "info"
```

### Structured Logging
```python
# Example structured logging in Python
import logging
import json

def json_logger():
    logger = logging.getLogger()
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter(json.dumps({
        'timestamp': '%(asctime)s',
        'level': '%(levelname)s',
        'message': '%(message)s',
        'module': '%(module)s',
    })))
    logger.addHandler(handler)
    return logger
```

## Monitoring Best Practices

1. **Regular Health Checks**
   - Monitor application metrics daily
   - Review logs for errors periodically
   - Check resource usage trends

2. **Resource Management**
   - Set appropriate resource requests and limits
   - Monitor utilization and adjust as needed
   - Clean up unused resources regularly

3. **Logging Strategy**
   - Use structured logging
   - Configure appropriate log levels
   - Implement log rotation for long-running services

4. **Alert Configuration**
   - Set meaningful alert thresholds
   - Avoid alert fatigue with proper tuning
   - Establish clear escalation paths

5. **Documentation**
   - Document monitoring endpoints and metrics
   - Maintain runbooks for common alerts
   - Update monitoring configuration when application changes

## Troubleshooting Common Issues

### Connectivity Issues
```bash
# Check network connectivity
kubectl run test-conn --rm -i --tty --image=busybox -- ping hello-app

# Test HTTP endpoint
kubectl run test-http --rm -i --tty --image=curlimages/curl -- curl http://hello-app.hello-app.svc.cluster.local
```

### Resource Issues
```bash
# Check for resource constraints
kubectl describe pods -n hello-app | grep -A 5 "Conditions"

# Check events for resource issues
kubectl get events --sort-by=.metadata.creationTimestamp -n hello-app
```

### Monitoring System Issues
```bash
# Check Prometheus status
kubectl get pods -n monitoring | grep prometheus

# Check Grafana status
kubectl get pods -n monitoring | grep grafana
``` 