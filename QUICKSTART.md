# Quick Start Guide

This guide helps you get the SMS Spam Detection system running quickly in different environments.

## Prerequisites

- Docker and Docker Compose (for local development)
- Kubernetes cluster with Istio (for production deployment)
- Helm 3.x
- kubectl configured

## Local Development (Docker Compose)

Fastest way to run the application locally:

```bash
# Start the services
make compose-up

# Check status
make compose-ps

# Access the application
open http://localhost:8080

# View logs
make compose-logs

# Stop services
make compose-down
```

The compose setup includes:
- Frontend on port 8080
- Model service on port 8081
- Health checks enabled
- Automatic restart on failure

### Verify Metrics (Optional)

After starting the services, you can verify that custom application metrics are being exposed:

```bash
# Frontend metrics
curl http://localhost:8080/actuator/prometheus | grep app_

# Model service metrics
curl http://localhost:8081/metrics | grep app_
```

Expected custom metrics:
- `app_predictions_total` - Counter of prediction requests (by source and status)
- `app_prediction_latency_seconds` - Histogram of prediction duration
- `app_active_users` - Gauge of active concurrent users

## Kubernetes Deployment

### Option 1: Using Makefile (Recommended)

```bash
# Install application + monitoring
make k8s-install

# Check status
make k8s-status

# Clean up
make k8s-clean
```

### Option 2: Using Helm directly

```bash
# Create namespace with Istio injection
kubectl create namespace sms-app
kubectl label namespace sms-app istio-injection=enabled

# Create image pull secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_USERNAME \
  --docker-password=YOUR_TOKEN \
  -n sms-app

# Install application chart
helm install sms-app ./helm-chart -n sms-app

# Verify deployment
kubectl get pods -n sms-app
```

## Production Deployment

Use the production values file for optimized settings:

```bash
helm install sms-app ./helm-chart \
  -f helm-chart/values-production.yaml \
  -n sms-app \
  --create-namespace
```

Production values include:
- 3 replicas for high availability
- Pinned image versions
- Enhanced resource limits
- Conservative 95/5 canary split
- Gateway-level rate limiting

## Validation

After deployment, validate the setup:

```bash
# Run validation script
make validate-canary

# Check Istio configuration
kubectl get gateway,virtualservice,destinationrule -n sms-app

# Test rate limiting
make rate-limit-test
```

## Accessing the Application

### Docker Compose
- Frontend: http://localhost:8080
- Model Service API: http://localhost:8081/apidocs

### Kubernetes (with Ingress)
- Frontend: http://app.sms-detector.local
- Canary: http://canary.sms-detector.local

Add to /etc/hosts:
```
192.168.56.90 app.sms-detector.local canary.sms-detector.local
```

If you access the app through the Istio IngressGateway instead of NGINX, point the hostnames to the Istio gateway IP.

## Testing Canary Deployment

Test traffic split:
```bash
# Normal requests (90% v1, 10% v2)
for i in {1..20}; do
  curl http://app.sms-detector.local
done

# Force specific version with header
curl -H "x-version: v2" http://app.sms-detector.local

# Test sticky sessions
curl -c cookies.txt http://app.sms-detector.local
curl -b cookies.txt http://app.sms-detector.local
```

## Monitoring

### Deploy Monitoring Stack

```bash
# Install app-stack (ServiceMonitors, AlertManager config)
helm install app-stack ./helm/app-stack -n sms-app
```

### Access Dashboards

```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open in browser
open http://localhost:3000   # Grafana
open http://localhost:9090   # Prometheus
```

Default Grafana credentials: `admin` / (retrieve with):
```bash
kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
```

### Provision Grafana Dashboards

Pre-built dashboards are available in `grafana-dashboards/` and can be automatically provisioned via ConfigMap:

```bash
# Apply dashboard ConfigMap (dashboards auto-load into Grafana)
kubectl apply -f kubernetes/grafana-dashboard-configmap.yaml

# Verify dashboard was loaded
kubectl get configmap grafana-dashboards -n monitoring
```

Available dashboards:
- **application-metrics.json** - Custom app metrics (predictions, latency, active users)
- **ab-testing.json** - A/B testing and canary deployment metrics

Dashboards are automatically discovered by Grafana via the `grafana_dashboard: "1"` label.

### Verify ServiceMonitors

Confirm ServiceMonitors are created and targeting the correct services:

```bash
# List ServiceMonitors
kubectl get servicemonitor -n sms-app

# Expected output:
# NAME                      AGE
# app-stack-frontend        1m
# app-stack-model-service   1m

# Check selector labels match services
kubectl get servicemonitor -n sms-app -o yaml | grep -A3 "matchLabels"
```

### Verify Prometheus Scraping

Confirm Prometheus is discovering and scraping targets:

```bash
# Port forward Prometheus (if not already)
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &

# Check targets are being scraped
curl -s "http://localhost:9090/api/v1/targets" | grep -o '"job":"sms-app[^"]*"' | sort -u

# Expected output:
# "job":"sms-app-frontend"
# "job":"sms-app-model-service"

# Query custom metrics
curl -s "http://localhost:9090/api/v1/query?query=app_active_users"
curl -s "http://localhost:9090/api/v1/query?query=app_predictions_total"
```

### Verify AlertManager

Test that alerts are configured and can be sent:

```bash
# Port forward AlertManager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093 &

# Check AlertManager status
curl -s http://localhost:9093/api/v2/status | head -20

# View configured alerts
kubectl get prometheusrule -n sms-app

# Check firing alerts
curl -s http://localhost:9093/api/v2/alerts
```

To test webhook alerts, update `helm/app-stack/values.yaml` with a URL from [webhook.site](https://webhook.site), then trigger an alert by generating traffic.

## Troubleshooting

If you encounter issues, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common problems and solutions.

Quick checks:
```bash
# Check pod logs
kubectl logs -n sms-app deployment/frontend

# Check Istio sidecar injection
kubectl get pods -n sms-app -o jsonpath='{.items[*].spec.containers[*].name}'

# Analyze Istio configuration
istioctl analyze -n sms-app

# Get events
kubectl get events -n sms-app --sort-by='.lastTimestamp'
```

## Full Vagrant Cluster Setup

For a complete Kubernetes cluster setup with Vagrant:

```bash
# Check prerequisites
make check

# Start VMs and provision cluster
make cluster-up

# Run finalization (MetalLB, Ingress, Istio)
make cluster-finalize

# Deploy application
export KUBECONFIG=./kubeconfig/config
make k8s-app-install

# SSH to controller
make cluster-ssh-ctrl
```

## Next Steps

- Review [deployment.md](docs/deployment.md) for architecture details
- Check [traffic-management.md](docs/traffic-management.md) for canary configuration
- Read [continuous-experimentation.md](docs/continuous-experimentation.md) for A/B testing
- See [extension.md](docs/extension.md) for future improvements
