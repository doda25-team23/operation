# Continuous Experimentation (A4)

## Summary
We run a canary experiment for a new `app-service` version (v2) in production-like conditions. Using Istio traffic management, we route 90% of incoming requests to the stable version (v1) and 10% to the canary (v2). We compare the versions using Prometheus-scraped application metrics and a Grafana dashboard to decide whether to promote v2.

---

## What changed (compared to the base design)
- Deployed **two versions** of `app-service` simultaneously:
    - **v1 (stable)**
    - **v2 (canary)**
- Configured Istio routing so that:
    - 90% of user traffic goes to **v1**
    - 10% goes to **v2**
- Both versions expose Prometheus metrics on `/actuator/prometheus` (or `/metrics`, depending on our implementation).
- A Grafana dashboard visualizes version-separated performance and error metrics.

> NOTE: This experiment focuses on the `app-service` change. The `model-service` is held constant to avoid confounding effects.

---

## Falsifiable hypothesis
- **H0 (null):** `app-service` v2 does **not** improve latency compared to v1 (or is worse).
- **H1 (alternative):** `app-service` v2 has **lower latency** than v1 under real traffic without increasing error rate.

This hypothesis is falsifiable because it is evaluated via measurable request latency and error metrics.

---

## Experiment design
### Versions
- `app-service`:
    - v1: stable
    - v2: canary
- Routing:
    - Incoming requests enter via the Istio IngressGateway and are routed using an Istio VirtualService.
    - Weighted routing sends ~90% to v1 and ~10% to v2.

### Observation window
- We observe metrics for **30–60 minutes** under normal usage (or a controlled load test that approximates typical usage).

### How to reproduce / verify routing
- Send multiple requests and observe version-specific metrics changing over time.
- Optional: if we support a header-based route for debugging (e.g., `X-Canary: true`), we use it only to validate connectivity, not for the main experiment.

---

## Metrics
We use two metrics categories:
1) **Latency** (primary): request latency (p95 / p99 or histogram-based)
2) **Errors** (guardrail): 5xx error rate (or exception count)

### Primary metric: request latency
- We compare v1 vs v2 using histogram metrics (e.g., Spring Boot’s `http_server_requests_seconds_bucket`)
- We visualize p95 latency per version.

### Guardrail metric: error rate
- We compare v1 vs v2 by 5xx response rate (or similar), per version.

---

## Decision process
We decide whether to **accept (promote)** or **reject (roll back)** v2 using the Grafana dashboard.

### Accept criteria (promote v2)
- v2 shows **no regression** in tail latency:
    - **p95 latency of v2 ≤ p95 latency of v1** (or within a small tolerance)
- v2 shows **no meaningful error increase**:
    - error rate remains comparable to v1

### Reject criteria (roll back to v1)
- v2 increases tail latency significantly for sustained periods
- v2 increases error rate (5xx or exceptions) compared to v1

### Action after decision
- **Accept:** gradually increase v2 weight (e.g., 10% → 25% → 50% → 100%), then deprecate v1.
- **Reject:** set routing back to 100% v1 immediately.

---

## Grafana dashboard
Our Grafana dashboard supports the decision by directly comparing v1 and v2 metrics.

### Panels included (minimum)
- **p95 latency (v1 vs v2)**
- **Request rate (v1 vs v2)** (to ensure v2 actually receives traffic)
- **5xx error rate (v1 vs v2)**

### Screenshot evidence

> **Screenshot:** `docs/images/continuous-experimentation-dashboard.png`

---

## Notes on consistency

