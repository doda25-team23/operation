# Troubleshooting Guide

Common issues and solutions for the SMS Spam Detection deployment.

## Istio Traffic Management Issues

### Traffic split not working (always routes to v1)
**Symptom:** All requests go to v1 even with 90/10 split configured.

**Solution:**
1. Check VirtualService weight configuration:
   ```bash
   kubectl get virtualservice frontend-vs -n sms-app -o yaml | grep -A 10 weight
   ```
2. Verify DestinationRule subsets are defined:
   ```bash
   kubectl get destinationrule frontend-dr -n sms-app -o yaml
   ```
3. Ensure pods have correct version labels:
   ```bash
   kubectl get pods -n sms-app --show-labels | grep version
   ```

### Sticky sessions not persisting
**Symptom:** User switches between v1/v2 on subsequent requests.

**Solution:**
1. Check if cookie is being set (for cookie-based):
   ```bash
   curl -I http://app.sms-detector.local | grep Set-Cookie
   ```
2. Verify DestinationRule has consistentHash configured
3. For header-based, ensure x-user-id header is sent consistently

## Rate Limiting Issues

### Rate limit not triggering (always returns 200)
**Symptom:** Can send unlimited requests without getting 429.

**Solution:**
1. Check if EnvoyFilter is applied:
   ```bash
   kubectl get envoyfilter -n sms-app
   ```
2. Verify rate limit scope matches workload:
   ```bash
   kubectl get envoyfilter sms-app-rate-limit -n sms-app -o yaml | grep -A 5 workloadSelector
   ```
3. Check Istio sidecar injection:
   ```bash
   kubectl get pod -n sms-app -o jsonpath='{.items[0].spec.containers[*].name}'
   ```
   Should show both app container and istio-proxy.

### Rate limit too aggressive
**Symptom:** Getting 429 errors under normal load.

**Solution:** Adjust values in `values.yaml`:
```yaml
rateLimit:
  maxTokens: 50  # Increase burst capacity
  tokensPerFill: 50
  fillInterval: "60s"
```

## Pod Startup Issues

### Pods in CrashLoopBackOff
**Symptom:** Pods keep restarting.

**Check logs:**
```bash
kubectl logs -n sms-app <pod-name> -c frontend
kubectl logs -n sms-app <pod-name> -c istio-proxy
```

**Common causes:**
- Model service: Missing model file in /app/shared
- Frontend: Cannot connect to model-service (check service name)
- Both: Insufficient memory (check OOMKilled in pod events)

### Pods stuck in Pending
**Symptom:** Pods don't schedule.

**Check events:**
```bash
kubectl describe pod -n sms-app <pod-name>
```

**Common causes:**
- Insufficient cluster resources
- Image pull failures (check imagePullSecrets)
- PersistentVolume not available

## Image Pull Issues

### Docker Compose: Unauthorized error
**Symptom:** `docker-compose up` fails with "unauthorized" or "pull access denied".

**Solution:**
1. Login to GitHub Container Registry:
   ```bash
   docker login ghcr.io -u YOUR_GITHUB_USERNAME
   # Enter your GitHub PAT (with read:packages scope) as password
   ```

2. If using sudo with docker-compose, login with sudo too:
   ```bash
   sudo docker login ghcr.io -u YOUR_GITHUB_USERNAME
   ```

3. Verify login works:
   ```bash
   docker pull ghcr.io/doda25-team23/app:latest
   ```

4. If credentials still fail, check `~/.docker/config.json`:
   ```bash
   cat ~/.docker/config.json
   ```
   Should contain an auth entry for `ghcr.io`. If it shows `credsStore: desktop` on WSL/Linux without Docker Desktop, remove that line.

### Docker credential helper errors
**Symptom:** `docker-credential-desktop.exe: executable file not found`

**Solution (WSL/Linux without Docker Desktop):**
```bash
# Remove the credsStore entry from docker config
echo '{}' > ~/.docker/config.json

# Re-login
docker login ghcr.io -u YOUR_GITHUB_USERNAME
```

### Kubernetes: ImagePullBackOff error
**Symptom:** Cannot pull images from ghcr.io in Kubernetes.

**Solution:**
1. Verify secret exists:
   ```bash
   kubectl get secret ghcr-secret -n sms-app
   ```
2. Recreate if needed:
   ```bash
   kubectl create secret docker-registry ghcr-secret \
     --docker-server=ghcr.io \
     --docker-username=YOUR_USERNAME \
     --docker-password=YOUR_PAT \
     -n sms-app
   ```
3. Check if secret is referenced in deployment:
   ```bash
   kubectl get deployment frontend -n sms-app -o yaml | grep -A 2 imagePullSecrets
   ```

## Monitoring Issues

### Metrics not showing in Prometheus
**Symptom:** Prometheus has no data for frontend/model-service.

**Solution:**
1. Check ServiceMonitor exists:
   ```bash
   kubectl get servicemonitor -n monitoring
   ```
2. Verify Prometheus scrape config includes namespace:
   ```bash
   kubectl get prometheus -n monitoring -o yaml | grep namespaceSelector
   ```
3. Check if metrics endpoint is accessible:
   ```bash
   kubectl port-forward -n sms-app svc/frontend 8080:8080
   curl http://localhost:8080/actuator/prometheus
   ```

### Grafana dashboards empty
**Symptom:** Dashboards created but show "No data".

**Solution:**
1. Verify Prometheus datasource in Grafana
2. Check dashboard queries match metric names
3. Ensure time range is correct (not looking at future)

## Ingress Issues

### Cannot access app.sms-detector.local
**Symptom:** Connection refused or DNS resolution fails.

**Solution:**
1. Add to /etc/hosts (development):
   ```
   192.168.56.90 app.sms-detector.local
   ```
2. Check Ingress is created:
   ```bash
   kubectl get ingress -n sms-app
   ```
3. Verify Ingress controller is running:
   ```bash
   kubectl get pods -n ingress-nginx
   ```

### Istio Gateway vs Nginx Ingress conflict
**Symptom:** Requests being handled by wrong component.

**Solution:**
- For Istio traffic management: Use Istio Gateway (disable nginx ingress)
- For simple routing: Use Nginx Ingress (disable Istio gateway)
- Configure in values.yaml:
  ```yaml
  ingress:
    enabled: false  # Disable nginx when using Istio
  istio:
    enabled: true   # Enable Istio Gateway
  ```

## Helm Issues

### Helm install fails with "already exists"
**Symptom:** Resource already exists error.

**Solution:**
1. Uninstall existing release:
   ```bash
   helm uninstall sms-app -n sms-app
   ```
2. Clean up namespace if needed:
   ```bash
   kubectl delete namespace sms-app
   ```
3. Reinstall:
   ```bash
   helm install sms-app ./helm-chart -n sms-app --create-namespace
   ```

### Template rendering errors
**Symptom:** Helm shows template errors during install.

**Solution:**
1. Dry-run to see rendered templates:
   ```bash
   helm install sms-app ./helm-chart --dry-run --debug -n sms-app
   ```
2. Validate values.yaml syntax:
   ```bash
   helm lint ./helm-chart
   ```

## General Debugging Commands

```bash
# Check all resources in namespace
kubectl get all -n sms-app

# Check pod status and restarts
kubectl get pods -n sms-app -o wide

# Get recent events
kubectl get events -n sms-app --sort-by='.lastTimestamp'

# Check Istio proxy status
istioctl proxy-status

# Analyze Istio configuration
istioctl analyze -n sms-app

# View all Helm releases
helm list -A

# Get Helm release values
helm get values sms-app -n sms-app
```
