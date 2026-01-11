#!/bin/bash
# Quick validation script for Istio canary deployment setup
# Usage: ./validate-canary-setup.sh [namespace]

set -e

NAMESPACE="${1:-sms-app}"

echo "=== Validating Canary Deployment Setup in namespace: $NAMESPACE ==="
echo

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "❌ Namespace $NAMESPACE does not exist"
    exit 1
fi
echo "✅ Namespace $NAMESPACE exists"

# Check Istio injection
INJECTION=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null || echo "")
if [ "$INJECTION" = "enabled" ]; then
    echo "✅ Istio injection enabled"
else
    echo "⚠️  Istio injection not enabled (label: istio-injection=enabled)"
fi

# Check deployments
echo
echo "=== Deployments ==="
DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" -o name 2>/dev/null | wc -l)
if [ "$DEPLOYMENTS" -gt 0 ]; then
    kubectl get deployments -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,VERSION:.metadata.labels.version,REPLICAS:.status.replicas,READY:.status.readyReplicas
    echo "✅ Found $DEPLOYMENTS deployment(s)"
else
    echo "❌ No deployments found"
fi

# Check for version labels
echo
echo "=== Version Labels ==="
V1_PODS=$(kubectl get pods -n "$NAMESPACE" -l version=v1 --no-headers 2>/dev/null | wc -l)
V2_PODS=$(kubectl get pods -n "$NAMESPACE" -l version=v2 --no-headers 2>/dev/null | wc -l)
echo "  v1 pods: $V1_PODS"
echo "  v2 pods: $V2_PODS"

if [ "$V1_PODS" -gt 0 ] && [ "$V2_PODS" -gt 0 ]; then
    echo "✅ Both v1 and v2 versions deployed (canary ready)"
elif [ "$V1_PODS" -gt 0 ]; then
    echo "⚠️  Only v1 deployed (no canary)"
else
    echo "⚠️  Version labels not found"
fi

# Check Istio resources
echo
echo "=== Istio Resources ==="

GATEWAYS=$(kubectl get gateway -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
echo "  Gateways: $GATEWAYS"
[ "$GATEWAYS" -gt 0 ] && echo "✅ Gateway configured" || echo "⚠️  No Gateway found"

VS=$(kubectl get virtualservice -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
echo "  VirtualServices: $VS"
[ "$VS" -gt 0 ] && echo "✅ VirtualService configured" || echo "⚠️  No VirtualService found"

DR=$(kubectl get destinationrule -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
echo "  DestinationRules: $DR"
[ "$DR" -gt 0 ] && echo "✅ DestinationRule configured" || echo "⚠️  No DestinationRule found"

# Check traffic split configuration
echo
echo "=== Traffic Split Configuration ==="
if [ "$VS" -gt 0 ]; then
    FRONTEND_VS=$(kubectl get virtualservice -n "$NAMESPACE" -o name 2>/dev/null | grep frontend | head -1)
    if [ -n "$FRONTEND_VS" ]; then
        echo "Checking $FRONTEND_VS for weight configuration:"
        kubectl get "$FRONTEND_VS" -n "$NAMESPACE" -o jsonpath='{.spec.http[0].route[*].weight}' 2>/dev/null | \
            awk '{print "  Weights: " $0}'
        echo
    fi
fi

# Check rate limiting
echo "=== Rate Limiting ==="
ENVOYFILTERS=$(kubectl get envoyfilter -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
if [ "$ENVOYFILTERS" -gt 0 ]; then
    echo "✅ EnvoyFilter found (rate limiting configured)"
    kubectl get envoyfilter -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,AGE:.metadata.creationTimestamp
else
    echo "⚠️  No EnvoyFilter found (rate limiting not configured)"
fi

# Check pod sidecars
echo
echo "=== Istio Sidecar Injection ==="
TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
PODS_WITH_SIDECAR=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].spec.containers[*].name}' 2>/dev/null | grep -o istio-proxy | wc -l)

echo "  Total pods: $TOTAL_PODS"
echo "  Pods with istio-proxy: $PODS_WITH_SIDECAR"

if [ "$TOTAL_PODS" -eq "$PODS_WITH_SIDECAR" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    echo "✅ All pods have Istio sidecar"
elif [ "$PODS_WITH_SIDECAR" -gt 0 ]; then
    echo "⚠️  Some pods missing Istio sidecar"
else
    echo "⚠️  No pods have Istio sidecar"
fi

# Summary
echo
echo "=== Summary ==="
ISSUES=0

[ "$INJECTION" != "enabled" ] && ((ISSUES++))
[ "$DEPLOYMENTS" -eq 0 ] && ((ISSUES++))
[ "$V2_PODS" -eq 0 ] && ((ISSUES++))
[ "$GATEWAYS" -eq 0 ] && ((ISSUES++))
[ "$VS" -eq 0 ] && ((ISSUES++))
[ "$DR" -eq 0 ] && ((ISSUES++))

if [ "$ISSUES" -eq 0 ]; then
    echo "✅ Canary deployment setup looks good!"
    exit 0
else
    echo "⚠️  Found $ISSUES potential issue(s) - review output above"
    exit 1
fi
