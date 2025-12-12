# Istio Traffic Management Testing Guide

This guide provides step-by-step instructions for testing Istio Gateway, VirtualServices, DestinationRules, canary releases, and sticky sessions.

## Prerequisites

- Kubernetes cluster with Istio installed
- Helm 3.x
- kubectl configured
- curl or similar HTTP client

## Setup

1. **Verify Istio installation:**
   ```bash
   kubectl get pods -n istio-system
   kubectl get svc -n istio-system istio-ingressgateway
   ```

2. **Deploy application:**
   ```bash
   cd /Users/user/Documents/slides/DODA/my-team/operation
   helm install sms-app ./helm-chart -n sms-app --create-namespace
   ```

3. **Get Istio IngressGateway IP:**
   ```bash
   export INGRESS_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   echo $INGRESS_IP
   
   # If LoadBalancer not available (minikube):
   export INGRESS_IP=$(minikube ip)
   export INGRESS_PORT=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
   ```

4. **Update /etc/hosts:**
   ```bash
   echo "$INGRESS_IP app.sms-detector.local canary.sms-detector.local" | sudo tee -a /etc/hosts
   ```

## Test 1: Verify Gateway and VirtualService

**Check resources exist:**
```bash
kubectl get gateway -n sms-app
kubectl get virtualservices -n sms-app
kubectl get destinationrules -n sms-app
```

**Expected output:**
```
NAME                     AGE
sms-app-gateway          1m

NAME                        GATEWAYS              HOSTS                                          AGE
sms-app-frontend            [sms-app-gateway]     [app.sms-detector.local, canary.sms-...]      1m
sms-app-model-service       []                    [sms-app-model-service]                        1m

NAME                        HOST                    AGE
sms-app-frontend            sms-app-frontend        1m
sms-app-model-service       sms-app-model-service   1m
```

**Test basic connectivity:**
```bash
curl -v http://app.sms-detector.local/
```

Expected: HTTP 200 response from frontend

## Test 2: Deploy Canary Version (90/10 Split)

**Deploy v2 canary:**
```bash
helm upgrade sms-app ./helm-chart -n sms-app \
  --set frontend.version=v2 \
  --set frontend.image.tag=latest \
  --set modelService.version=v2 \
  --set modelService.image.tag=latest \
  --reuse-values
```

**Verify both versions running:**
```bash
kubectl get pods -n sms-app --show-labels | grep version
```

Expected: Some pods with `version=v1`, some with `version=v2`

**Test traffic distribution (90/10):**
```bash
# Send 100 requests and count responses
for i in {1..100}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://app.sms-detector.local/
done | sort | uniq -c
```

Expected: ~90 requests to v1, ~10 to v2 (approximate distribution)

## Test 3: Sticky Sessions (Cookie-Based)

**Test cookie persistence:**
```bash
# First request - get assigned to a version
curl -c cookies.txt -v http://app.sms-detector.local/ 2>&1 | grep -i "set-cookie"

# Check which version you got (look for version indicator in response)
curl -b cookies.txt http://app.sms-detector.local/

# Make multiple requests with same cookie
for i in {1..10}; do
  echo "Request $i:"
  curl -b cookies.txt -s http://app.sms-detector.local/ | grep -o "version.*" || echo "Same version"
done
```

Expected: All requests go to the same version (sticky session working)

**Test new session gets different assignment:**
```bash
# Remove cookie and make new request
rm cookies.txt
curl -c cookies.txt http://app.sms-detector.local/
```

Expected: May get assigned to different version (90% v1, 10% v2)

## Test 4: Header-Based Version Override

**Force specific version using header:**
```bash
# Force v1
curl -H "x-version: v1" http://app.sms-detector.local/
curl -H "x-version: v1" http://app.sms-detector.local/
curl -H "x-version: v1" http://app.sms-detector.local/

# Force v2
curl -H "x-version: v2" http://app.sms-detector.local/
curl -H "x-version: v2" http://app.sms-detector.local/
curl -H "x-version: v2" http://app.sms-detector.local/
```

Expected: All v1 requests hit v1, all v2 requests hit v2 (100% accuracy)

## Test 5: Header-Based Sticky Sessions

**Switch to header-based sticky sessions:**
```bash
helm upgrade sms-app ./helm-chart -n sms-app \
  --set istio.stickySession.useCookie=false \
  --set istio.stickySession.headerName=x-user-id \
  --reuse-values
```

**Test user consistency:**
```bash
# User A - should consistently get same version
for i in {1..10}; do
  echo "User A - Request $i:"
  curl -H "x-user-id: user-alice" http://app.sms-detector.local/
done

# User B - should consistently get same version (may differ from User A)
for i in {1..10}; do
  echo "User B - Request $i:"
  curl -H "x-user-id: user-bob" http://app.sms-detector.local/
done
```

Expected: Each user consistently hits the same version across all requests

## Test 6: Traffic Split Adjustment

**Test 50/50 split:**
```bash
helm upgrade sms-app ./helm-chart -n sms-app \
  --set istio.trafficSplit.stable=50 \
  --set istio.trafficSplit.canary=50 \
  --reuse-values

# Verify traffic distribution
for i in {1..100}; do
  curl -s http://app.sms-detector.local/
done
```

Expected: ~50% to v1, ~50% to v2

**Test full promotion (100% v2):**
```bash
helm upgrade sms-app ./helm-chart -n sms-app \
  --set istio.trafficSplit.stable=0 \
  --set istio.trafficSplit.canary=100 \
  --reuse-values

# Verify all traffic to v2
for i in {1..20}; do
  curl -s http://app.sms-detector.local/
done
```

Expected: 100% to v2

## Test 7: Model Service Internal Routing

**Verify model-service routing:**
```bash
# Get frontend pod
FRONTEND_POD=$(kubectl get pod -n sms-app -l app=frontend -o jsonpath='{.items[0].metadata.name}')

# Test internal calls from frontend to model-service
kubectl exec -n sms-app $FRONTEND_POD -c frontend -- curl -s http://sms-app-model-service:8081/apidocs
```

Expected: Model service responds (version routing follows same rules)

## Test 8: Configurable IngressGateway Name

**Test with custom gateway name:**
```bash
helm upgrade sms-app ./helm-chart -n sms-app \
  --set istio.ingressGateway.name=my-custom-gateway \
  --reuse-values

# Check Gateway spec
kubectl get gateway -n sms-app sms-app-gateway -o yaml | grep selector -A 1
```

Expected: Gateway selector matches custom name

## Monitoring and Debugging

**Check Istio configuration:**
```bash
# Istio config dump
istioctl proxy-config routes -n sms-app $(kubectl get pod -n sms-app -l app=frontend -o jsonpath='{.items[0].metadata.name}')

# Virtual service details
kubectl describe virtualservice -n sms-app sms-app-frontend

# Destination rule details
kubectl describe destinationrule -n sms-app sms-app-frontend
```

**Check logs:**
```bash
# Frontend logs
kubectl logs -n sms-app -l app=frontend -c frontend

# Istio sidecar logs
kubectl logs -n sms-app -l app=frontend -c istio-proxy
```

**Metrics:**
```bash
# Request metrics
kubectl exec -n sms-app $(kubectl get pod -n sms-app -l app=frontend -o jsonpath='{.items[0].metadata.name}') -c istio-proxy -- curl -s localhost:15000/stats | grep -i version
```

## Cleanup

```bash
# Remove deployment
helm uninstall sms-app -n sms-app

# Remove namespace
kubectl delete namespace sms-app

# Remove /etc/hosts entry
sudo sed -i.bak '/sms-detector.local/d' /etc/hosts
```

## Troubleshooting

**Issue: Gateway not accessible**
- Check Istio IngressGateway is running: `kubectl get pods -n istio-system`
- Verify LoadBalancer IP: `kubectl get svc -n istio-system istio-ingressgateway`
- Check Gateway configuration: `kubectl get gateway -n sms-app -o yaml`

**Issue: Traffic not splitting correctly**
- Verify version labels on pods: `kubectl get pods -n sms-app --show-labels`
- Check VirtualService weights: `kubectl get vs -n sms-app sms-app-frontend -o yaml`
- Ensure Istio sidecar injected: Pods should show 2/2 READY

**Issue: Sticky sessions not working**
- Check DestinationRule has consistentHash: `kubectl get dr -n sms-app -o yaml`
- Verify cookie/header is being sent: `curl -v` to see headers
- Check Istio proxy logs for routing decisions

**Issue: Version labels not applied**
- Verify deployment has version label: `kubectl get deployment -n sms-app -o yaml | grep version`
- Re-deploy with correct version: `helm upgrade --set frontend.version=v1`
