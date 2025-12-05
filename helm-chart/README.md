# SMS Spam Detection Application - Helm Chart

Helm chart for deploying the SMS Spam Detection application to Kubernetes.

## Prerequisites

- Kubernetes cluster (v1.24+)
- Helm 3.x
- nginx-ingress controller installed and configured
- `/mnt/shared` directory on all nodes (for shared storage)

## Installation

### Quick Start

```bash
helm install sms-app ./helm-chart \
  --create-namespace \
  --namespace sms-app
```

### Custom Configuration

```bash
helm install sms-app ./helm-chart \
  --set ingress.hosts.stable=myapp.local \
  --set frontend.replicaCount=3 \
  --create-namespace \
  --namespace sms-app
```

### Override Secrets

```bash
helm install sms-app ./helm-chart \
  --set secrets.smtp.password=real-password \
  --namespace sms-app
```

## Accessing the Application

1. Add the hostname to your `/etc/hosts`:

```bash
# For self-provisioned cluster with MetalLB
192.168.56.90 app.sms-detector.local

# For Minikube
$(minikube ip) app.sms-detector.local
```

2. Access the application:

```bash
curl http://app.sms-detector.local
```

## Configuration

Key configuration parameters in `values.yaml`:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.hosts.stable` | Stable version hostname | `app.sms-detector.local` |
| `frontend.replicaCount` | Number of frontend replicas | `2` |
| `modelService.service.port` | Model service port | `8081` |
| `modelService.volume.enabled` | Enable shared storage | `true` |
| `secrets.smtp.password` | SMTP password (override!) | `placeholder-pass` |

See `values.yaml` for all available options.

## Service Relocation

Change service names and ports:

```bash
helm upgrade sms-app ./helm-chart \
  --set modelService.service.name=model-api \
  --set modelService.service.port=8082 \
  --reuse-values
```

## Upgrading

```bash
helm upgrade sms-app ./helm-chart --namespace sms-app
```

## Uninstalling

```bash
helm uninstall sms-app --namespace sms-app
kubectl delete namespace sms-app
```

## Troubleshooting

**Pods not starting?**
- Check if `/mnt/shared` exists on nodes: `ls -la /mnt/shared`
- Disable volume: `--set modelService.volume.enabled=false`

**Ingress not accessible?**
- Verify ingress: `kubectl get ingress -n sms-app`
- Check /etc/hosts entry matches ingress hostname

**Services can't communicate?**
- Check MODEL_HOST: `kubectl get deploy -n sms-app -o yaml | grep MODEL_HOST`
- Verify services: `kubectl get svc -n sms-app`

## For Teammates

### Adding Monitoring Components

Create subdirectories in `templates/`:
- `templates/monitoring/` - Prometheus, ServiceMonitors
- `templates/grafana/` - Grafana deployment, dashboards
- `templates/alerting/` - AlertManager, PrometheusRules

Add your configuration to `values.yaml` in the placeholder sections.

### Extending the Chart

1. Add templates to `templates/` directory
2. Add values to `values.yaml`
3. Update Chart version in `Chart.yaml`
4. Test with `helm lint` and `helm template`
