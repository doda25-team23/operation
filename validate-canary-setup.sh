#!/bin/bash
# Validation script for Istio canary deployment setup
# Usage: ./validate-canary-setup.sh [namespace]

set -e

NAMESPACE="${1:-sms-app}"
ERRORS=0
WARNINGS=0

echo "Validating Canary Deployment Setup"
echo "Namespace: $NAMESPACE"
echo "-----------------------------------"
echo

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "[ERROR] Namespace $NAMESPACE does not exist"
    exit 1
fi
echo "[OK] Namespace exists"

# Check Istio injection
INJECTION=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null || echo "")
if [ "$INJECTION" = "enabled" ]; then
    echo "[OK] Istio injection enabled"
else
    echo "[WARN] Istio injection not enabled (missing label istio-injection=enabled)"
    ((WARNINGS++))
fi

# Check deployments
echo
echo "Deployments:"
DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" -o name 2>/dev/null | wc -l | tr -d ' ')
if [ "$DEPLOYMENTS" -gt 0 ]; then
    kubectl get deployments -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,VERSION:.metadata.labels.version,REPLICAS:.status.replicas,READY:.status.readyReplicas 2>/dev/null
    echo "[OK] Found $DEPLOYMENTS deployment(s)"
else
    echo "[ERROR] No deployments found"
    ((ERRORS++))
fi

# Check for version labels
echo
echo "Version Distribution:"
V1_PODS=$(kubectl get pods -n "$NAMESPACE" -l version=v1 --no-headers 2>/dev/null | wc -l | tr -d ' ')
V2_PODS=$(kubectl get pods -n "$NAMESPACE" -l version=v2 --no-headers 2>/dev/null | wc -l | tr -d ' ')
echo "  v1 pods: $V1_PODS"
echo "  v2 pods: $V2_PODS"

if [ "$V1_PODS" -gt 0 ] && [ "$V2_PODS" -gt 0 ]; then
    echo "[OK] Both versions deployed"
elif [ "$V1_PODS" -gt 0 ]; then
    echo "[WARN] Only v1 deployed, no canary"
    ((WARNINGS++))
else
    echo "[WARN] Version labels not found"
    ((WARNINGS++))
fi

# Check Istio resources
echo
echo "Istio Resources:"

GATEWAYS=$(kubectl get gateway -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
echo "  Gateways: $GATEWAYS"
if [ "$GATEWAYS" -gt 0 ]; then
    echo "  [OK] Gateway configured"
else
    echo "  [WARN] No Gateway found"
    ((WARNINGS++))
fi

VS=$(kubectl get virtualservice -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
echo "  VirtualServices: $VS"
if [ "$VS" -gt 0 ]; then
    echo "  [OK] VirtualService configured"
else
    echo "  [WARN] No VirtualService found"
    ((WARNINGS++))
fi

DR=$(kubectl get destinationrule -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
echo "  DestinationRules: $DR"
if [ "$DR" -gt 0 ]; then
    echo "  [OK] DestinationRule configured"
else
    echo "  [WARN] No DestinationRule found"
    ((WARNINGS++))
fi

# Check traffic split configuration
echo
echo "Traffic Split:"
if [ "$VS" -gt 0 ]; then
    FRONTEND_VS=$(kubectl get virtualservice -n "$NAMESPACE" -o name 2>/dev/null | grep frontend | head -1)
    if [ -n "$FRONTEND_VS" ]; then
        WEIGHTS=$(kubectl get "$FRONTEND_VS" -n "$NAMESPACE" -o jsonpath='{.spec.http[0].route[*].weight}' 2>/dev/null)
        if [ -n "$WEIGHTS" ]; then
            echo "  Configured weights: $WEIGHTS"
            echo "  [OK] Traffic split configured"
        else
            echo "  [WARN] No weights found in VirtualService"
            ((WARNINGS++))
        fi
    fi
fi

# Check rate limiting
echo
echo "Rate Limiting:"
ENVOYFILTERS=$(kubectl get envoyfilter -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$ENVOYFILTERS" -gt 0 ]; then
    echo "[OK] EnvoyFilter configured ($ENVOYFILTERS filter(s))"
    kubectl get envoyfilter -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,AGE:.metadata.creationTimestamp 2>/dev/null | head -5
else
    echo "[WARN] No EnvoyFilter found"
    ((WARNINGS++))
fi

# Check pod sidecars
echo
echo "Istio Sidecar Injection:"
TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
PODS_WITH_SIDECAR=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].spec.containers[*].name}' 2>/dev/null | grep -o istio-proxy | wc -l | tr -d ' ')

echo "  Total pods: $TOTAL_PODS"
echo "  Pods with sidecar: $PODS_WITH_SIDECAR"

if [ "$TOTAL_PODS" -eq "$PODS_WITH_SIDECAR" ] && [ "$TOTAL_PODS" -gt 0 ]; then
    echo "[OK] All pods have sidecar"
elif [ "$PODS_WITH_SIDECAR" -gt 0 ]; then
    echo "[WARN] Some pods missing sidecar"
    ((WARNINGS++))
else
    echo "[WARN] No sidecars detected"
    ((WARNINGS++))
fi

# Summary
echo
echo "-----------------------------------"
echo "Summary:"
echo "  Errors: $ERRORS"
echo "  Warnings: $WARNINGS"

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo "  Status: All checks passed"
    exit 0
elif [ "$ERRORS" -eq 0 ]; then
    echo "  Status: Passed with warnings"
    exit 0
else
    echo "  Status: Failed"
    exit 1
fi
