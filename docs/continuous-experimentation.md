# Continuous Experimentation (A4)

## Summary

We implement canary deployment infrastructure for `model-service` using Istio traffic management. The setup enables weighted traffic routing between versions with Prometheus metrics and Grafana dashboards for observability.

---

## Implementation

### Infrastructure Components

- **Istio VirtualService**: Routes traffic with configurable weights (default 90/10)
- **Istio DestinationRule**: Defines v1/v2 subsets based on pod version labels
- **Prometheus**: Scrapes `app_predictions_total` and `app_prediction_latency_seconds` metrics
- **Grafana Dashboard**: Visualizes request rate, latency, and errors by pod

### Helm Chart Configuration

```yaml
# values-canary-example.yaml
istio:
  trafficSplit:
    stable: 90   # v1
    canary: 10   # v2
```

### Metrics Exposed

| Metric | Type | Labels |
|--------|------|--------|
| `app_predictions_total` | Counter | status, pod |
| `app_prediction_latency_seconds` | Histogram | source, pod |

---

## Experiment Design

### Hypothesis

- **H0:** v2 does not improve latency compared to v1
- **H1:** v2 has lower latency than v1 without increasing error rate

### Decision Criteria

**Accept v2:** p95 latency ≤ v1 (within 10% tolerance), error rate comparable

**Reject v2:** Latency regression or error rate increase

---

## Running the Experiment

```bash
# 1. Start Minikube with Istio
minikube start --cpus=4 --memory=8192
istioctl install --set profile=demo -y

# 2. Install monitoring
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# 3. Deploy application
kubectl create namespace sms-app
kubectl label namespace sms-app istio-injection=enabled
helm install sms-app ./helm-chart -n sms-app -f ./helm-chart/values-canary-example.yaml

# 4. Generate traffic
kubectl port-forward -n sms-app svc/model-service 8081:8081 &
while true; do curl -s -X POST -H "Content-Type: application/json" -d '{"sms":"test"}' http://localhost:8081/predict; sleep 1; done

# 5. Observe in Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Import grafana-dashboards/ab-testing.json
```

---

## Promotion/Rollback

```bash
# Promote canary
helm upgrade sms-app ./helm-chart -n sms-app --set istio.trafficSplit.stable=50 --set istio.trafficSplit.canary=50

# Rollback
helm upgrade sms-app ./helm-chart -n sms-app --set istio.trafficSplit.stable=100 --set istio.trafficSplit.canary=0
```

---

## Limitations

- Current helm chart deploys single version; true side-by-side v1/v2 requires chart modification
- Metrics grouped by pod name, not version label
- Istio telemetry metrics not scraped; uses application-level metrics
