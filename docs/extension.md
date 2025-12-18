## Extension proposal: “Release validation gate” for Kubernetes/Istio/Monitoring manifests

This repo is primarily **deployment and operations** code: Helm charts, raw Kubernetes manifests, Istio traffic-management objects, and Prometheus Operator CRDs.

### Release-engineering pain point

**Low-confidence releases caused by configuration drift and missing pre-merge validation.**

Concrete symptoms visible in this repo:

- **Multiple sources of truth** for the same system:
  - raw manifests: `kubernetes/base/`
  - app chart with Istio features: `helm-chart/`
  - monitoring/alerting chart: `helm/app-stack/`
- A meaningful portion of the stack uses **CRDs** (Istio `Gateway`/`VirtualService`/`DestinationRule`, Prometheus Operator `ServiceMonitor`/`PrometheusRule`/`AlertmanagerConfig`) where mistakes often surface only at deploy time.
- Canary + sticky sessions + rate limit settings are powerful, but **small YAML errors** (field names, API versions, ports) can break routing in ways that are hard to diagnose quickly.

Net effect: changes can look “done” in review, but still fail at install/apply time, delaying deployments and creating avoidable firefights.

---

### Proposed improvement (1–5 day scope)

Add a **“release validation gate”** that runs in CI for every PR and can be run locally.

**Deliverables (implementation idea):**

- **`make validate` (or `./scripts/validate.sh`)** that:
  - Renders charts:
    - `helm lint` and `helm template` for `helm-chart/` and `helm/app-stack/`
  - Validates rendered YAML + raw manifests:
    - schema conformance using `kubeconform` (fast Kubernetes schema validation)
  - Adds domain-specific checks:
    - `promtool check rules` on rendered `PrometheusRule` content
    - `istioctl analyze` on rendered Istio objects (best-effort static analysis)

- **GitHub Actions workflow** (or equivalent CI) that runs the same validation on:
  - every pull request
  - pushes to main

**Why this fits in 1–5 days:**

- It’s mostly wiring together existing CLI tools and choosing a minimal set of representative value files (e.g., `helm-chart/values.yaml` and a canary example like `values-canary-example.yaml`).
- No production runtime changes are required; it’s a guardrail that improves confidence.

---

### Measurement approach (how we’ll know it helped)

Use a combination of **process metrics** and **delivery-performance metrics**.

**A) Primary outcome: fewer broken deploys caused by config mistakes**

- **Metric**: count of deployment failures attributable to invalid manifests (Helm render errors, rejected resources, CRD schema mismatch).
- **How**: track failures in CI logs and (if you have a deployment pipeline) in deploy job logs.
- **Target**: reduce “deploy broke due to YAML/config” incidents by a meaningful fraction (e.g., 50–80%).

**B) Faster feedback for operators and reviewers**

- **Metric**: mean time from PR open to first detection of a manifest/config issue.
- **How**: CI job timestamps; compare before/after introducing the gate.

**C) Tie-in to delivery performance (DORA/Four Keys)**

- Track **lead time for changes**, **deployment frequency**, **change failure rate**, and **time to restore** where possible.
- The gate primarily targets **change failure rate** (fewer failed changes) and indirectly improves lead time.

---

### Quality sources

- **DORA / Accelerate (delivery performance metrics)**: DORA report PDF: `https://dora.dev/research/2022/dora-report/2022-dora-accelerate-state-of-devops-report.pdf`
- **Helm chart validation and best practices**:
  - `helm lint` reference: `https://helm.sh/docs/helm/helm_lint/`
  - Chart template best practices: `https://helm.sh/docs/chart_best_practices/templates/`
- **Schema-based Kubernetes manifest validation**:
  - Kubeconform overview: `https://kubeconform.mandragor.org/about/`
- **Prometheus Operator CRDs (ServiceMonitor/PrometheusRule/AlertmanagerConfig)**:
  - Design docs: `https://prometheus-operator.dev/docs/getting-started/design/`
  - API reference: `https://prometheus-operator.dev/docs/api-reference/api/`
- **Istio traffic management + sticky sessions**:
  - DestinationRule reference (consistent hash / cookie): `https://istio.io/latest/docs/reference/config/networking/destination-rule/`

---

### Assumptions and downsides

- **Assumption: CI environment can install the needed CLIs** (`helm`, `kubeconform`, `istioctl`, `promtool`).
  - Downside: tool installation adds some maintenance overhead.

- **Schema validation is necessary but not sufficient**.
  - `kubeconform` validates against schemas but cannot fully replicate server-side admission checks or controller behavior.

- **Sticky sessions are “soft” affinity** under consistent hashing.
  - When pods scale up/down, a fraction of clients can be remapped to different backends.

- **Multiple deployment modes remain** (raw manifests + two charts).
  - The validation gate reduces risk, but it doesn’t eliminate drift by itself; a longer-term improvement would be to converge on a single “golden path” and clearly deprecate the others.
