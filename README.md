# SMS Spam Detection System - Operations

Operational configurations for deploying the SMS Spam Detection microservices application.

## Overview

The system classifies SMS messages as spam or legitimate (ham) using machine learning.

**Services:**
- **Frontend**: Web UI (Spring Boot/Java) - Port 8080
- **Model Service**: ML inference API (Flask/Python) - Port 8081

**Repositories:**
- Frontend: https://github.com/doda25-team23/app
- Model Service: https://github.com/doda25-team23/model-service
- Version Library: https://github.com/doda25-team23/lib-version
- Operations: https://github.com/doda25-team23/operation

## Documentation

- [QUICKSTART.md](QUICKSTART.md) - Get started quickly with different deployment options
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- [docs/deployment.md](docs/deployment.md) - Architecture and deployment details
- [docs/traffic-management.md](docs/traffic-management.md) - Istio canary configuration
- [docs/continuous-experimentation.md](docs/continuous-experimentation.md) - A/B testing guide

## Quick Start

See [QUICKSTART.md](QUICKSTART.md) for detailed instructions.

### Docker Compose (Local Development)

```bash
make compose-up
```

Access:
- Web UI: http://localhost:8080
- API Docs: http://localhost:8081/apidocs

### Kubernetes with Helm

```bash
# Install application
make k8s-app-install

# Validate deployment
make validate-canary

# Install monitoring
make k8s-mon-install
```

## Container Images

Published on GitHub Container Registry:
- Frontend: `ghcr.io/doda25-team23/app:latest`
- Model Service: `ghcr.io/doda25-team23/model-service:latest`

## Features

### Rate Limiting (Istio)

Protects against excessive API usage using Istio EnvoyFilter.

**Configuration:** 10 requests per minute per pod (global limit)

**Test rate limiting:**

```bash
# Send rapid requests to trigger rate limiting
for i in {1..20}; do
  curl -s -o /dev/null -w "Request $i: %{http_code}\n" http://app.sms-detector.local
done

# Expected: Mix of 200 (success) and 429 (rate limited) responses
```

**Configure limits** in `helm-chart/values.yaml`:

```yaml
rateLimit:
  enabled: true
  maxTokens: 10          # Max burst size
  tokensPerFill: 10      # Tokens per interval
  fillInterval: "60s"    # Time interval (10 req/min)
```

**How it works:**
- Applied to frontend service via Istio EnvoyFilter
- Uses token bucket algorithm
- Returns HTTP 429 when limit exceeded
- Each pod has independent rate limit bucket

### Monitoring & Alerting

Grafana dashboards available in `grafana-dashboards/`:
- **application-metrics.json**: Request rates, response times, error rates
- **ab-testing.json**: A/B testing comparison and decision support

## Configuration

### Helm Chart Values

Key configuration options in `helm-chart/values.yaml`:

```yaml
frontend:
  replicaCount: 2
  image:
    repository: ghcr.io/doda25-team23/app
    tag: latest

modelService:
  replicaCount: 2
  image:
    repository: ghcr.io/doda25-team23/model-service
    tag: latest

ingress:
  enabled: true
  hosts:
    stable: app.sms-detector.local

rateLimit:
  enabled: true
  maxTokens: 10
  fillInterval: "60s"
```

### Environment Variables

| Variable     | Default                     | Description           |
| ------------ | --------------------------- | --------------------- |
| `MODEL_HOST` | `http://model-service:8081` | Backend API URL       |
| `MODEL_DIR`  | `/app/model`                | ML model directory    |
| `MODEL_PORT` | `8081`                      | Model service port    |

## Kubernetes Environments

### Assignment A2: Cluster Provisioning
See [K8S_SETUP.md](K8S_SETUP.md) for Vagrant + Ansible setup.

### Assignment A3: Monitoring & Operations
- Prometheus metrics collection
- Grafana dashboards
- Alertmanager configuration
- See [ALERTING_SETUP.md](ALERTING_SETUP.md)

### Assignment A4: Istio Service Mesh
- Rate limiting (EnvoyFilter)
- Traffic management
- Canary deployments
- See [ACTIVITY.md](ACTIVITY.md)

## Troubleshooting

**Pods stuck in ImagePullBackOff:**
- Verify GitHub Container Registry credentials in `ghcr-secret`
- Check image names and tags in `values.yaml`

**Rate limiting not working:**
- Verify Istio sidecars injected: `kubectl get pods -n sms-app` (should show 2/2 Ready)
- Check EnvoyFilter exists: `kubectl get envoyfilter -n sms-app`
- Verify namespace has Istio injection: `kubectl get namespace sms-app --show-labels`

**Ingress not accessible:**
- Ensure ingress controller is running: `kubectl get pods -n ingress-nginx`
- For minikube: Run `minikube tunnel` in separate terminal
- Add hostname to `/etc/hosts`: `<MINIKUBE_IP> app.sms-detector.local`

## Cleanup

```bash
# Remove Helm release
helm uninstall sms-app -n sms-app

# Delete namespace
kubectl delete namespace sms-app

# Stop Docker Compose
docker-compose down
```

