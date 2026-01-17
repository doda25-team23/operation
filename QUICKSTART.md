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

## Kubernetes Deployment

### Option 1: Using Makefile (Recommended)

```bash
# Install application
make k8s-app-install

# Check status
make k8s-app-status

# Install monitoring stack
make k8s-mon-install

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
./validate-canary-setup.sh sms-app

# Check Istio configuration
kubectl get gateway,virtualservice,destinationrule -n sms-app

# Test rate limiting
./test-rate-limit.sh
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

Access Grafana:
```bash
# Port forward to Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Open in browser
open http://localhost:3000
```

Default credentials are typically admin/admin (check monitoring chart values).

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
