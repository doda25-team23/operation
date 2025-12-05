# Alerting Setup Guide

This guide explains how to configure Prometheus AlertManager with email notifications for the application stack.

## Overview

The alerting system consists of:
- **AlertManager**: Handles alert routing and notifications
- **PrometheusRule**: Defines alert conditions (e.g., high request rate)
- **AlertManagerConfig**: Configures notification settings (webhook or email)
- **Secret**: Stores SMTP credentials securely (only if using email)

## Quick Start: Webhook Testing (Recommended)

The easiest way to test alerts is using a webhook receiver - no SMTP setup needed!

1. **Get a test webhook URL:**
   - Visit https://webhook.site
   - Copy your unique URL (e.g., `https://webhook.site/abc123-def456-...`)

2. **Update values.yaml:**
   ```yaml
   alerting:
     enabled: true
     webhook:
       enabled: true
       url: "https://webhook.site/your-unique-id"
   ```

3. **Deploy and test:**
   ```bash
   helm upgrade --install app-stack ./helm/app-stack
   # Generate some traffic to trigger the alert
   # Check webhook.site to see the alert payload!
   ```

That's it! You'll see the alert JSON payload on webhook.site when it fires.

## Prerequisites

- Prometheus Operator must be installed in your cluster
- Valid SMTP server credentials for sending emails

## Configuration Options

### Option 1: Webhook (Easiest - Recommended for Testing)

Webhooks are the simplest way to test alerts - just point to a URL and see the JSON payload!

**Using webhook.site (Free Testing Service):**
1. Go to https://webhook.site
2. Copy your unique URL
3. Update `values.yaml`:
   ```yaml
   alerting:
     enabled: true
     webhook:
       enabled: true
       url: "https://webhook.site/your-unique-id-here"
   ```

**Using Your Own Endpoint:**
```yaml
alerting:
  enabled: true
  webhook:
    enabled: true
    url: "http://your-service:8080/alerts"  # Your HTTP endpoint
```

The webhook will receive a JSON payload like:
```json
{
  "version": "4",
  "groupKey": "...",
  "status": "firing",
  "receiver": "webhook-notifications",
  "alerts": [
    {
      "status": "firing",
      "labels": {
        "alertname": "HighRequestRate",
        "severity": "warning"
      },
      "annotations": {
        "summary": "High request rate detected",
        "description": "Service is receiving more than 15 requests per minute..."
      }
    }
  ]
}
```

### Option 2: Email (Production Use)

### 1. Update Email Settings

Edit `helm/app-stack/values.yaml` and update the alerting section:

```yaml
alerting:
  enabled: true
  email:
    enabled: true
    to: "dev-team@example.com"  # Your email address
    smtpFrom: "alerts@example.com"
    smtpHost: "smtp.gmail.com"  # Your SMTP server
    smtpPort: "587"  # 587 for TLS, 465 for SSL
    smtpAuthUsername: "your-email@gmail.com"
    smtpAuthPassword: "your-app-password"  # Use app password for Gmail
```

### 2. Deploy with Helm (Webhook)

```bash
# Deploy with webhook (no credentials needed!)
helm upgrade --install app-stack ./helm/app-stack \
  --namespace your-namespace \
  --create-namespace \
  --set alerting.webhook.url="https://webhook.site/your-id"
```

### 2. Deploy with Helm (Email)

```bash
# Deploy the stack with alerting enabled
helm upgrade --install app-stack ./helm/app-stack \
  --namespace your-namespace \
  --create-namespace

# Or override email settings at deploy time (recommended for production)
helm upgrade --install app-stack ./helm/app-stack \
  --namespace your-namespace \
  --create-namespace \
  --set alerting.email.to="dev-team@example.com" \
  --set alerting.email.smtpFrom="alerts@example.com" \
  --set alerting.email.smtpHost="smtp.gmail.com" \
  --set alerting.email.smtpPort="587" \
  --set alerting.email.smtpAuthUsername="your-email@gmail.com" \
  --set alerting.email.smtpAuthPassword="your-password"
```

### 3. Using Secrets for Credentials (Recommended)

For production, store SMTP credentials in a Kubernetes Secret:

```bash
# Create a secret with SMTP credentials
kubectl create secret generic alertmanager-email-credentials \
  --from-literal=smtp-auth-username='your-email@gmail.com' \
  --from-literal=smtp-auth-password='your-app-password' \
  --namespace your-namespace

# Then reference it in values.yaml or use --set-file
```

**Note**: The current implementation uses values.yaml, but you should modify the Secret template to reference an existing Secret in production.

## Configured Alerts

### HighRequestRate

- **Condition**: Service receives more than 15 requests per minute for 2 minutes straight
- **Metric**: `http_server_requests_seconds_count` (Spring Boot Actuator) or `http_requests_total` (standard Prometheus)
- **Severity**: Warning
- **Notification**: Email sent to configured recipient

## Testing Alerts

### Quick Test with Webhook

1. **Set up webhook.site:**
   ```bash
   # Visit https://webhook.site and copy your URL
   # Update values.yaml or use --set
   ```

2. **Deploy:**
   ```bash
   helm upgrade --install app-stack ./helm/app-stack \
     --set alerting.webhook.url="https://webhook.site/your-id"
   ```

3. **Generate traffic to trigger alert:**
   ```bash
   # Generate load to exceed 15 req/min for 2 minutes
   for i in {1..100}; do
     curl http://your-app-url/api/endpoint &
   done
   ```

4. **Check webhook.site** - you'll see the alert JSON appear automatically!

### Detailed Testing

### 1. Check AlertManager Status

```bash
# Port-forward to AlertManager UI
kubectl port-forward -n your-namespace svc/app-stack-alertmanager 9093:9093

# Open http://localhost:9093 in your browser
```

### 2. Check Prometheus Rules

```bash
# Port-forward to Prometheus UI
kubectl port-forward -n your-namespace svc/app-stack-prometheus 9090:9090

# Navigate to http://localhost:9090/alerts to see active alerts
```

### 3. Trigger Test Alert

You can manually trigger an alert by generating high traffic:

```bash
# Generate load (adjust as needed)
for i in {1..100}; do
  curl http://your-app-url/api/endpoint
done
```

## Troubleshooting

### Alerts Not Firing

1. Check if PrometheusRule is created:
   ```bash
   kubectl get prometheusrule -n your-namespace
   ```

2. Check if AlertManager is running:
   ```bash
   kubectl get alertmanager -n your-namespace
   kubectl get pods -l app.kubernetes.io/name=alertmanager -n your-namespace
   ```

3. Check Prometheus configuration:
   ```bash
   kubectl get prometheus -n your-namespace -o yaml
   # Verify alerting.alertmanagers section is present
   ```

### Emails Not Sending

1. Check AlertManager logs:
   ```bash
   kubectl logs -n your-namespace -l app.kubernetes.io/name=alertmanager
   ```

2. Verify SMTP credentials in Secret:
   ```bash
   kubectl get secret app-stack-alertmanager-email -n your-namespace -o yaml
   ```

3. Test SMTP connection from AlertManager pod:
   ```bash
   kubectl exec -n your-namespace -it <alertmanager-pod> -- sh
   # Test SMTP connection manually
   ```

### Gmail Setup

For Gmail, you need to:
1. Enable 2-factor authentication
2. Generate an "App Password" (not your regular password)
3. Use the app password in `smtpAuthPassword`

## Security Best Practices

⚠️ **Important**: Never commit real credentials to git!

1. Use `--set` flags or separate values files for production
2. Store credentials in Kubernetes Secrets
3. Use CI/CD secrets management (e.g., GitHub Secrets, GitLab CI variables)
4. Rotate credentials regularly
5. Use read-only service accounts where possible

## Customizing Alerts

To add more alerts, edit `helm/app-stack/templates/prometheusrule.yaml`:

```yaml
spec:
  groups:
  - name: application.rules
    rules:
    - alert: HighRequestRate
      expr: sum(rate(http_server_requests_seconds_count[1m])) > 15
      for: 2m
      # ... existing config ...
    - alert: HighErrorRate
      expr: sum(rate(http_server_requests_seconds_count{status=~"5.."}[1m])) > 5
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "Error rate exceeds 5 errors per minute"
```

## References

- [Prometheus Operator Documentation](https://github.com/prometheus-operator/prometheus-operator)
- [AlertManager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [PrometheusRule Specification](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#prometheusrule)

