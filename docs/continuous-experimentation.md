# Continuous Experimentation (A4)

## Summary

We implement canary deployment infrastructure for both `frontend` and `model-service` using Istio traffic management. The setup enables weighted traffic routing between v1 (stable) and v2 (canary) versions with Prometheus metrics and Grafana dashboards for observability and decision support.

---

## Implementation

### Infrastructure Components

| Component | Purpose |
|-----------|---------|
| **Istio VirtualService** | Routes traffic with configurable weights (default 90/10) |
| **Istio DestinationRule** | Defines v1/v2 subsets based on pod version labels |
| **Sticky Sessions** | Cookie-based (`sms-app-version`, TTL: 1h) for user consistency |
| **Prometheus** | Scrapes metrics with `version` label for v1/v2 comparison |
| **Grafana Dashboard** | Visualizes request rate, latency, and errors by version |

### Helm Chart Configuration

The experiment is enabled by setting `canary.enabled: true` in values:

```yaml
# values-experiment.yaml
canary:
  enabled: true
  frontend:
    replicaCount: 1
    image:
      tag: "v2"
  modelService:
    replicaCount: 1
    image:
      tag: "v2"

istio:
  trafficSplit:
    stable: 90   # v1
    canary: 10   # v2
```

### Metrics Exposed

Istio automatically adds `destination_version` labels from pod metadata:

| Metric | Type | Labels |
|--------|------|--------|
| `istio_requests_total` | Counter | destination_app, destination_version, response_code |
| `istio_request_duration_milliseconds` | Histogram | destination_app, destination_version |
| `app_predictions_total` | Counter | source, status (app-level, no version) |

### Deployment Architecture

```
                    ┌─────────────────────────────────────┐
                    │         Istio Gateway               │
                    │   app.sms-detector.local:80         │
                    └─────────────────┬───────────────────┘
                                      │
                    ┌─────────────────▼───────────────────┐
                    │         VirtualService              │
                    │                                     │
                    │   Header x-version: v1 → v1 (100%) │
                    │   Header x-version: v2 → v2 (100%) │
                    │   Default → 90% v1 / 10% v2        │
                    └────────┬────────────────┬──────────┘
                             │                │
              ┌──────────────▼──┐      ┌──────▼──────────────┐
              │   Subset: v1    │      │   Subset: v2        │
              │   (stable)      │      │   (canary)          │
              ├─────────────────┤      ├─────────────────────┤
              │ frontend v1     │      │ frontend-canary v2  │
              │ model-svc v1    │      │ model-svc-canary v2 │
              │ 2 replicas each │      │ 1 replica each      │
              └─────────────────┘      └─────────────────────┘
```

---

## Experiment Design

### Hypothesis

- **H0 (Null):** v2 does not improve latency compared to v1
- **H1 (Alternative):** v2 has lower p95 latency than v1 without increasing error rate

### Decision Criteria

| Outcome | Condition | Action |
|---------|-----------|--------|
| **Accept v2** | p95 latency ≤ v1 (within 10% tolerance) AND error rate comparable | Promote to 50%, then 100% |
| **Reject v2** | Latency regression > 10% OR error rate increase | Rollback to 100% v1 |
| **Inconclusive** | Not enough data or conflicting signals | Extend experiment duration |

---

## Running the Experiment

### Prerequisites

```bash
# 1. Ensure Istio is installed
istioctl version

# 2. Ensure namespace has Istio injection enabled
kubectl label namespace sms-app istio-injection=enabled --overwrite

# 3. Build and push v2 container images (with version label in metrics)
cd app && docker build -t ghcr.io/doda25-team23/app:v2 . && docker push ghcr.io/doda25-team23/app:v2
cd ../model-service && docker build -t ghcr.io/doda25-team23/model-service:v2 . && docker push ghcr.io/doda25-team23/model-service:v2
```

### Deploy Experiment

```bash
# Deploy with both v1 and v2 running (90/10 split)
cd operation
helm upgrade --install sms-app ./helm-chart \
  -n sms-app \
  --create-namespace \
  -f ./helm-chart/values-experiment.yaml
```

### Verify Deployment

```bash
# Check pods - should see both v1 and v2
kubectl get pods -n sms-app -L version

# Expected output:
# NAME                                         READY   STATUS    VERSION
# sms-app-frontend-xxxx                        2/2     Running   v1
# sms-app-frontend-canary-xxxx                 2/2     Running   v2
# sms-app-model-service-xxxx                   2/2     Running   v1
# sms-app-model-service-canary-xxxx            2/2     Running   v2

# Verify VirtualService routing
kubectl get virtualservice -n sms-app -o yaml | grep -A5 "weight"
```

### Test Routing

```bash
# Test default routing (should follow 90/10 split)
for i in {1..10}; do
  curl -s http://app.sms-detector.local/sms/ | grep -o 'version.*'
done

# Force v1 via header
curl -H "x-version: v1" http://app.sms-detector.local/sms/

# Force v2 via header
curl -H "x-version: v2" http://app.sms-detector.local/sms/
```

### Generate Traffic

```bash
# First, set up port-forward to Istio ingress gateway (if not using external IP)
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80 &

# Run experiment for 5 minutes
./run-experiment.sh sms-app 300 http://localhost:8080

# Or manual traffic generation (note: Host header required for Istio routing):
while true; do
  curl -s -X POST \
    -H "Host: app.sms-detector.local" \
    --data-urlencode "sms=Test message $(date +%s)" \
    http://localhost:8080/sms/
  sleep 2
done
```

### Observe in Grafana

```bash
# Port forward to Grafana (kube-prometheus-stack)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Get Grafana credentials
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-user}" | base64 -d
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Open http://localhost:3000
# Login with credentials above
# Go to Explore, select Prometheus datasource
# Use the Istio queries below
```

**Key Queries for Version Comparison (Istio Metrics):**

```promql
# Request rate by version
sum by (destination_version) (rate(istio_requests_total{destination_app="frontend", reporter="destination"}[1m]))

# Latency p95 by version
histogram_quantile(0.95, sum by (destination_version, le) (rate(istio_request_duration_milliseconds_bucket{destination_app="frontend"}[1m])))

# Error rate by version (non-2xx responses)
sum by (destination_version) (rate(istio_requests_total{destination_app="frontend", response_code!~"2.."}[1m]))

# Traffic distribution
sum by (destination_version) (increase(istio_requests_total{destination_app="frontend"}[5m]))

# Success rate by version
sum by (destination_version) (rate(istio_requests_total{destination_app="frontend", response_code="200"}[1m]))
```

---

## Promotion/Rollback

### Gradual Promotion

```bash
# Increase to 50/50
helm upgrade sms-app ./helm-chart -n sms-app \
  --set istio.trafficSplit.stable=50 \
  --set istio.trafficSplit.canary=50 \
  --reuse-values

# Full promotion to 100% v2
helm upgrade sms-app ./helm-chart -n sms-app \
  --set istio.trafficSplit.stable=0 \
  --set istio.trafficSplit.canary=100 \
  --reuse-values
```

### Rollback

```bash
# Rollback to 100% v1
helm upgrade sms-app ./helm-chart -n sms-app \
  --set istio.trafficSplit.stable=100 \
  --set istio.trafficSplit.canary=0 \
  --reuse-values
```

---

## Experiment Results

### Experiment 1: Initial 90/10 Split

#### Setup

- **Date**: 2026-01-30
- **Duration**: 5 minutes (300 seconds)
- **Traffic Split**: 90% v1 / 10% v2
- **Total Requests**: 434 (389 v1 + 45 v2, from Istio ingress gateway logs)

#### Observations

Traffic was successfully routed according to the 90/10 split configuration. The Istio VirtualService correctly distributed requests between v1 and v2 subsets.

![Traffic Distribution](images/V2-V1.PNG)

#### Metrics Collected

| Metric | v1 | v2 | Total/Diff |
|--------|----|----|------------|
| Request Count | 389 | 45 | 434 |
| Traffic % | 89.6% | 10.4% | ~90/10 |
| p95 Latency | 30s | 30s | 0 |
| Error Rate | 0 | 0 | 0 |

#### Traffic Verification

```bash
# Verified via Istio ingress gateway logs:
kubectl logs -n istio-system deploy/istio-ingressgateway --tail=500 | \
  grep -oP 'outbound\|8080\|v[12]\|sms-app-frontend' | sort | uniq -c

# Result:
#   389 outbound|8080|v1|sms-app-frontend
#    45 outbound|8080|v2|sms-app-frontend
```

### Experiment 2: 50/50 Split

```bash
# Update traffic split to 50/50
helm upgrade sms-app ./helm-chart -n sms-app \
  --set istio.trafficSplit.stable=50 \
  --set istio.trafficSplit.canary=50 \
  --reuse-values

# Generate traffic
./run-experiment.sh sms-app 300 http://localhost:8080

# Verify split
kubectl logs -n istio-system deploy/istio-ingressgateway --tail=150 | \
  grep -oP 'outbound\|8080\|v[12]\|sms-app-frontend' | sort | uniq -c

# Result:
#    76 outbound|8080|v1|sms-app-frontend
#    73 outbound|8080|v2|sms-app-frontend
```

| Metric | v1 | v2 | Total/Diff |
|--------|----|----|------------|
| Request Count | 76 | 73 | 149 |
| Traffic % | 51% | 49% | ~50/50 |
| p95 Latency | 30s | 30s | 0 |
| Error Rate | 0.0243 req/s | 0.0175 req/s | 68 req/s |

### Decision

Based on the collected metrics:

**Experiment 1 (90/10):**
- **Traffic Distribution**: ✓ Observed 89.6% v1 / 10.4% v2 (matches expected 90/10)
- **Latency**: ✓ p95 latency identical at 30s for both versions
- **Error Rate**: ✓ Zero errors observed for both versions

**Experiment 2 (50/50):**
- **Traffic Distribution**: ✓ Observed 51% v1 / 49% v2 (matches expected 50/50)
- **Latency**: ✓ p95 latency identical at 30s for both versions
- **Error Rate**: ✓ v2 (0.0175 req/s) lower than v1 (0.0243 req/s) - 28% improvement

#### Decision Process

The decision to accept or reject v2 follows our predefined criteria:

| Criterion | Threshold | v1 Result | v2 Result | Status |
|-----------|-----------|-----------|-----------|--------|
| p95 Latency | v2 ≤ v1 + 10% | 30s | 30s | ✓ PASS |
| Error Rate | v2 ≤ v1 | 0.0243 req/s | 0.0175 req/s | ✓ PASS |
| Traffic Routing | Matches config | 89.6%/10.4% | Configurable | ✓ PASS |

**How the Dashboard Supports This Decision:**

1. **Traffic Distribution Panel** (`istio_requests_total` by `destination_version`):
   - Confirms Istio is routing traffic according to configured weights
   - Visual verification that both v1 and v2 pods are receiving requests
   - Validates the experiment infrastructure is working correctly

2. **Latency p95 Panel** (`istio_request_duration_milliseconds` histogram):
   - Compares response time distribution between versions
   - Used to evaluate H1: "v2 has lower p95 latency than v1"
   - Result: Latencies are identical → no regression

3. **Error Rate Panel** (`istio_requests_total` with `response_code!~"2.."`):
   - Monitors non-2xx responses per version
   - Critical for detecting regressions that impact users
   - Result: v2 shows 28% fewer errors than v1

**Final Verdict: ACCEPT v2**

All decision criteria are satisfied:
- ✓ Latency is within tolerance (identical at 30s)
- ✓ Error rate is comparable (v2 is actually 28% better)
- ✓ Traffic routing is correctly controlled via Helm values

**Recommended Action:** Proceed with gradual promotion:
1. ~~90/10 split (completed)~~ → Metrics validated
2. ~~50/50 split (completed)~~ → No regressions detected
3. **Next:** Promote to 100% v2 using:
   ```bash
   helm upgrade sms-app ./helm-chart -n sms-app \
     --set istio.trafficSplit.stable=0 \
     --set istio.trafficSplit.canary=100 \
     --reuse-values
   ```

### Completed Steps

- [x] Verify 90/10 traffic split works correctly
- [x] Verify 50/50 traffic split works correctly
- [x] Analyze latency comparison in Grafana
- [x] Analyze error rate comparison in Grafana
- [x] Make promotion/rollback decision based on metrics

---

## Grafana Dashboard

Use Grafana's Explore feature with these Istio-based queries:

| Panel | Query |
|-------|-------|
| Request Rate by Version | `sum by (destination_version) (rate(istio_requests_total{destination_app="frontend"}[1m]))` |
| Latency p95 by Version | `histogram_quantile(0.95, sum by (destination_version, le) (rate(istio_request_duration_milliseconds_bucket{destination_app="frontend"}[1m])))` |
| Error Rate by Version | `sum by (destination_version) (rate(istio_requests_total{destination_app="frontend", response_code!~"2.."}[1m]))` |
| Traffic Distribution | `sum by (destination_version) (increase(istio_requests_total{destination_app="frontend"}[5m]))` |

### Quick CLI Verification

```bash
# Check traffic distribution from ingress gateway logs
kubectl logs -n istio-system deploy/istio-ingressgateway --tail=1000 | \
  grep -oP 'outbound\|8080\|v[12]\|sms-app-frontend' | sort | uniq -c

# Check Istio metrics directly from sidecar
kubectl exec -n sms-app deploy/sms-app-frontend -- \
  curl -s localhost:15020/stats/prometheus | grep istio_requests_total | head -5
```

Color coding:
- **Blue/Green**: v1 (stable)
- **Orange/Yellow**: v2 (canary)
