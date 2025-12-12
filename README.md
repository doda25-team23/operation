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

## Quick Start

### Docker Compose (Local Development)

```bash
cd operation
docker-compose up -d
```

Access:
- Web UI: http://localhost:8080/sms
- API Docs: http://localhost:8081/apidocs

### Kubernetes with Helm (Production)

**Prerequisites:**
- Kubernetes cluster with Istio installed
- Helm 3.x
- kubectl configured

**Deploy:**

```bash
# Create namespace with Istio injection
kubectl create namespace sms-app
kubectl label namespace sms-app istio-injection=enabled

# Create image pull secret for GitHub Container Registry
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_PERSONAL_ACCESS_TOKEN \
  --docker-email=your-email@example.com \
  -n sms-app

# Install with Helm
cd operation
helm install sms-app ./helm-chart -n sms-app --create-namespace

# Access application (requires minikube tunnel or ingress controller)
# URL: http://app.sms-detector.local
```

**Verify deployment:**

```bash
kubectl get pods -n sms-app
kubectl get ingress -n sms-app
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

### Traffic Management & Canary Release (Istio)

Enables controlled rollout of new versions with 90/10 traffic split and sticky sessions for version consistency.

**Architecture:**

The system uses Istio's traffic management capabilities to route traffic between stable (v1) and canary (v2) versions:

1. **Istio Gateway**: Entry point for external traffic on port 80
2. **VirtualServices**: Define routing rules for both frontend and model-service
3. **DestinationRules**: Define version subsets (v1, v2) with sticky session configuration
4. **Sticky Sessions**: Ensure users consistently hit the same version (old→old, new→new)

**Traffic Flow:**

```
External Request
     ↓
Istio Gateway (port 80)
     ↓
VirtualService (routing rules)
     ├─ 90% → v1 subset (stable)
     └─ 10% → v2 subset (canary)
     ↓
DestinationRule (load balancing + sticky sessions)
     ↓
Service Pods (with version labels)
```

**Configuration:**

Traffic split is controlled in `helm-chart/values.yaml`:

```yaml
istio:
  enabled: true
  trafficSplit:
    stable: 90  # 90% to v1
    canary: 10  # 10% to v2
  stickySession:
    useCookie: true
    cookieName: sms-app-version
    cookieTTL: 3600s
```

**Deploy canary version:**

```bash
# Deploy v2 (canary) version
helm upgrade sms-app ./helm-chart -n sms-app \
  --set frontend.version=v2 \
  --set frontend.image.tag=v2.0.0 \
  --set modelService.version=v2 \
  --set modelService.image.tag=v2.0.0 \
  --reuse-values

# Monitor traffic distribution
kubectl get virtualservices -n sms-app
kubectl get destinationrules -n sms-app

# Check pod versions
kubectl get pods -n sms-app --show-labels
```

**Sticky Sessions:**

Ensures version consistency - once a user is routed to v1 or v2, they stay on that version:

- **Cookie-based** (default): Uses `sms-app-version` cookie with 1-hour TTL
- **Header-based**: Uses `x-user-id` header for consistent hashing

**Testing sticky sessions:**

```bash
# First request - get assigned to a version
curl -c cookies.txt http://app.sms-detector.local

# Subsequent requests - stay on same version
curl -b cookies.txt http://app.sms-detector.local
curl -b cookies.txt http://app.sms-detector.local
```

**Force specific version (testing):**

```bash
# Force v1
curl -H "x-version: v1" http://app.sms-detector.local

# Force v2
curl -H "x-version: v2" http://app.sms-detector.local
```

**IngressGateway Configuration:**

The gateway name is configurable to support different Istio installations:

```yaml
istio:
  ingressGateway:
    name: ingressgateway  # Change to match your Istio installation
```

Common gateway names:
- `ingressgateway` (default Istio installation)
- `istio-ingressgateway` (some distributions)
- Custom names in multi-tenant clusters

**Canary promotion workflow:**

```bash
# 1. Deploy canary (10% traffic)
helm upgrade sms-app ./helm-chart --set istio.trafficSplit.canary=10

# 2. Monitor metrics (error rates, latency)
# Use Grafana dashboards to compare v1 vs v2

# 3. Increase canary traffic gradually
helm upgrade sms-app ./helm-chart --set istio.trafficSplit.stable=50 --set istio.trafficSplit.canary=50

# 4. Full promotion (100% to v2)
helm upgrade sms-app ./helm-chart --set istio.trafficSplit.stable=0 --set istio.trafficSplit.canary=100

# 5. Clean up old version
# Update default version label and remove v1 deployments
```

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

istio:
  enabled: true
  ingressGateway:
    name: ingressgateway
  hosts:
    stable: app.sms-detector.local
    canary: canary.sms-detector.local
  trafficSplit:
    stable: 90
    canary: 10
  stickySession:
    useCookie: true
    cookieName: sms-app-version
    cookieTTL: 3600s
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
- Traffic management (Istio Gateway, VirtualServices, DestinationRules)
- Canary deployments (90/10 traffic split)
- Sticky sessions (cookie/header-based for version consistency)
- See [ACTIVITY.md](ACTIVITY.md)
- Testing guide: [ISTIO_TESTING.md](ISTIO_TESTING.md)

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

## Architecture Diagram

### Rate Limiting with Istio

```
┌─────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                       │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                    Namespace: sms-app                     │ │
│  │                (istio-injection: enabled)                 │ │
│  │                                                           │ │
│  │   External Request                                        │ │
│  │         │                                                 │ │
│  │         ▼                                                 │ │
│  │   ┌──────────┐                                            │ │
│  │   │ Ingress  │  (nginx)                                   │ │
│  │   │ Gateway  │  app.sms-detector.local                    │ │
│  │   └────┬─────┘                                            │ │
│  │        │                                                  │ │
│  │        ▼                                                  │ │
│  │   ┌─────────────────────────────────────┐                │ │
│  │   │   Pod: frontend (2/2 Running)       │                │ │
│  │   │  ┌──────────────┐  ┌──────────────┐ │                │ │
│  │   │  │ istio-proxy  │  │   frontend   │ │                │ │
│  │   │  │   (Envoy)    │◄─┤  container   │ │                │ │
│  │   │  │              │  │              │ │                │ │
│  │   │  │ Rate Limit:  │  │  Port 8080   │ │                │ │
│  │   │  │ 10 req/min   │  │              │ │                │ │
│  │   │  │              │  │              │ │                │ │
│  │   │  │ ✓ Allow      │  └──────┬───────┘ │                │ │
│  │   │  │ ✗ HTTP 429   │         │         │                │ │
│  │   │  └──────┬───────┘         │         │                │ │
│  │   │         │                 │         │                │ │
│  │   │         └─────────────────┘         │                │ │
│  │   │                 │                   │                │ │
│  │   └─────────────────┼───────────────────┘                │ │
│  │                     │                                     │ │
│  │                     ▼                                     │ │
│  │             ┌───────────────┐                             │ │
│  │             │   Service:    │                             │ │
│  │             │ model-service │                             │ │
│  │             │ ClusterIP     │                             │ │
│  │             └───────┬───────┘                             │ │
│  │                     │                                     │ │
│  │                     ▼                                     │ │
│  │   ┌─────────────────────────────────────┐                │ │
│  │   │   Pod: model-service (2/2 Running)  │                │ │
│  │   │  ┌──────────────┐  ┌──────────────┐ │                │ │
│  │   │  │ istio-proxy  │  │ model-service│ │                │ │
│  │   │  │   (Envoy)    │◄─┤  container   │ │                │ │
│  │   │  │              │  │              │ │                │ │
│  │   │  │              │  │  Port 8081   │ │                │ │
│  │   │  └──────────────┘  └──────────────┘ │                │ │
│  │   └─────────────────────────────────────┘                │ │
│  │                                                           │ │
│  │   ┌─────────────────────────────────────┐                │ │
│  │   │        EnvoyFilter Resource         │                │ │
│  │   │  name: sms-app-rate-limit           │                │ │
│  │   │  workloadSelector:                  │                │ │
│  │   │    app: frontend                    │                │ │
│  │   │  config:                            │                │ │
│  │   │    maxTokens: 10                    │                │ │
│  │   │    fillInterval: 60s                │                │ │
│  │   └─────────────────────────────────────┘                │ │
│  │                                                           │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

Traffic Flow with Rate Limiting:
1. Request → Ingress → istio-proxy (sidecar)
2. istio-proxy checks token bucket (10 tokens available)
3. If tokens available: Allow → forward to frontend container
4. If no tokens: Block → return HTTP 429 (rate limited)
5. Tokens refill at 10 tokens per 60 seconds
```
