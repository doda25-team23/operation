# Istio Canary Deployment Quick Reference

## 🚀 Quick Start

### Deploy Initial Version (v1)
```bash
helm install sms-app ./helm-chart -n sms-app --create-namespace
```

### Deploy Canary Version (v2) - 90/10 Split
```bash
helm upgrade sms-app ./helm-chart -n sms-app \
  --set frontend.version=v2 \
  --set frontend.image.tag=2.0.0 \
  --set modelService.version=v2 \
  --set modelService.image.tag=2.0.0 \
  --reuse-values
```

## 📊 Traffic Split Commands

```bash
# 90/10 (initial canary)
--set istio.trafficSplit.stable=90 --set istio.trafficSplit.canary=10

# 80/20
--set istio.trafficSplit.stable=80 --set istio.trafficSplit.canary=20

# 50/50
--set istio.trafficSplit.stable=50 --set istio.trafficSplit.canary=50

# 100% canary (full promotion)
--set istio.trafficSplit.stable=0 --set istio.trafficSplit.canary=100

# Rollback (100% stable)
--set istio.trafficSplit.stable=100 --set istio.trafficSplit.canary=0
```

## 🧪 Testing Commands

### Test Traffic Distribution
```bash
# Send 100 requests and count distribution
for i in {1..100}; do
  curl -s http://app.sms-detector.local/ 
done
```

### Test Sticky Sessions (Cookie)
```bash
# First request - get assigned
curl -c cookies.txt http://app.sms-detector.local/

# Subsequent requests - same version
curl -b cookies.txt http://app.sms-detector.local/
curl -b cookies.txt http://app.sms-detector.local/
```

### Force Specific Version
```bash
# Force v1
curl -H "x-version: v1" http://app.sms-detector.local/

# Force v2
curl -H "x-version: v2" http://app.sms-detector.local/
```

## 🔍 Verification Commands

```bash
# Check Istio resources
kubectl get gateway,virtualservices,destinationrules -n sms-app

# Check pod versions
kubectl get pods -n sms-app --show-labels | grep version

# Check traffic split
kubectl get vs -n sms-app sms-app-frontend -o yaml | grep weight

# Verify sticky sessions
kubectl get dr -n sms-app sms-app-frontend -o yaml | grep consistentHash
```

## ⚙️ Configuration Options

### Switch to Header-Based Sticky Sessions
```bash
helm upgrade sms-app ./helm-chart -n sms-app \
  --set istio.stickySession.useCookie=false \
  --reuse-values
```

### Change IngressGateway Name
```bash
helm upgrade sms-app ./helm-chart -n sms-app \
  --set istio.ingressGateway.name=my-custom-gateway \
  --reuse-values
```

### Disable Istio Features
```bash
helm upgrade sms-app ./helm-chart -n sms-app \
  --set istio.enabled=false \
  --reuse-values
```

## 📈 Monitoring

```bash
# Watch pod status
watch kubectl get pods -n sms-app

# Check Istio sidecar logs
kubectl logs -n sms-app POD_NAME -c istio-proxy

# View Gateway status
kubectl describe gateway -n sms-app

# Check VirtualService routes
kubectl describe vs -n sms-app sms-app-frontend
```

## 🔧 Troubleshooting

### Gateway not accessible
```bash
kubectl get svc -n istio-system istio-ingressgateway
kubectl get gateway -n sms-app -o yaml
```

### Traffic not splitting
```bash
kubectl get pods -n sms-app --show-labels | grep version
kubectl get vs -n sms-app sms-app-frontend -o yaml
```

### Sticky sessions not working
```bash
kubectl get dr -n sms-app -o yaml | grep consistentHash
curl -v http://app.sms-detector.local/ 2>&1 | grep -i cookie
```

## 📚 Full Documentation

- Complete testing guide: `ISTIO_TESTING.md`
- Implementation details: `IMPLEMENTATION_SUMMARY.md`
- Main README: `README.md` (Traffic Management section)
- Helm docs: `helm-chart/README.md`
- Examples: `helm-chart/values-canary-example.yaml`

## ⚡ Common Workflows

### Standard Canary Rollout
```bash
# 1. Deploy v2 at 10%
helm upgrade sms-app ./helm-chart -n sms-app \
  --set frontend.version=v2 \
  --set frontend.image.tag=2.0.0 \
  --set modelService.version=v2 \
  --set modelService.image.tag=2.0.0

# 2. Monitor for 15-30 minutes
# Check Grafana dashboards for errors, latency

# 3. Increase to 50%
helm upgrade sms-app ./helm-chart -n sms-app \
  --set istio.trafficSplit.stable=50 \
  --set istio.trafficSplit.canary=50 \
  --reuse-values

# 4. Monitor for another 15-30 minutes

# 5. Full promotion to 100%
helm upgrade sms-app ./helm-chart -n sms-app \
  --set istio.trafficSplit.stable=0 \
  --set istio.trafficSplit.canary=100 \
  --reuse-values

# 6. Clean up old version (optional)
# Update default version in values.yaml
```

### Emergency Rollback
```bash
# Immediately route all traffic to v1
helm upgrade sms-app ./helm-chart -n sms-app \
  --set istio.trafficSplit.stable=100 \
  --set istio.trafficSplit.canary=0 \
  --reuse-values
```
