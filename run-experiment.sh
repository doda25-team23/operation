#!/bin/bash
# Canary Experiment Runner
# Executes a full canary experiment workflow with validation and metrics collection

set -e

NAMESPACE="${1:-sms-app}"
DURATION="${2:-300}"  # default 5 minutes observation
TARGET_URL="${3:-http://app.sms-detector.local}"

echo "Canary Experiment Runner"
echo "-------------------------------------------"
echo "Namespace:    $NAMESPACE"
echo "Duration:     ${DURATION}s"
echo "Target:       $TARGET_URL"
echo "Started at:   $(date '+%Y-%m-%d %H:%M:%S')"
echo "-------------------------------------------"
echo

# Step 1: Validate deployment
echo "[1/4] Validating deployment..."
if ! ./validate-canary-setup.sh "$NAMESPACE" > /tmp/validation.log 2>&1; then
    echo "Validation failed. Check /tmp/validation.log"
    cat /tmp/validation.log
    exit 1
fi
echo "      Deployment validated"
echo

# Step 2: Check traffic split configuration
echo "[2/4] Checking traffic split..."
FRONTEND_VS=$(kubectl get virtualservice -n "$NAMESPACE" -o name 2>/dev/null | grep frontend | head -1)
if [ -n "$FRONTEND_VS" ]; then
    WEIGHTS=$(kubectl get "$FRONTEND_VS" -n "$NAMESPACE" -o jsonpath='{.spec.http[0].route[*].weight}' 2>/dev/null)
    echo "      Current weights: $WEIGHTS"
else
    echo "      No VirtualService found - using default routing"
fi
echo

# Step 3: Generate traffic and collect responses
echo "[3/4] Generating traffic for ${DURATION}s..."
echo "      (sending requests every 2 seconds)"

V1_COUNT=0
V2_COUNT=0
ERROR_COUNT=0
TOTAL_COUNT=0
START_TIME=$(date +%s)

while [ $(($(date +%s) - START_TIME)) -lt "$DURATION" ]; do
    RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 "$TARGET_URL" 2>/dev/null || echo -e "\n000")
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | head -n -1)
    
    ((TOTAL_COUNT++))
    
    if [ "$HTTP_CODE" = "200" ]; then
        # Try to detect version from response if available
        if echo "$BODY" | grep -q "v2\|version.*2" 2>/dev/null; then
            ((V2_COUNT++))
        else
            ((V1_COUNT++))
        fi
    else
        ((ERROR_COUNT++))
    fi
    
    # Progress indicator every 30 requests
    if [ $((TOTAL_COUNT % 30)) -eq 0 ]; then
        ELAPSED=$(($(date +%s) - START_TIME))
        echo "      ${ELAPSED}s elapsed - ${TOTAL_COUNT} requests sent"
    fi
    
    sleep 2
done

echo
echo "[4/4] Experiment complete"
echo

# Step 4: Summary
echo "-------------------------------------------"
echo "Results Summary"
echo "-------------------------------------------"
echo "Total requests:  $TOTAL_COUNT"
echo "Successful:      $((V1_COUNT + V2_COUNT))"
echo "  - v1 responses: $V1_COUNT"
echo "  - v2 responses: $V2_COUNT"
echo "Errors:          $ERROR_COUNT"
echo

if [ "$TOTAL_COUNT" -gt 0 ]; then
    SUCCESS_RATE=$(( (V1_COUNT + V2_COUNT) * 100 / TOTAL_COUNT ))
    echo "Success rate:    ${SUCCESS_RATE}%"
    
    if [ $((V1_COUNT + V2_COUNT)) -gt 0 ]; then
        V2_PERCENTAGE=$(( V2_COUNT * 100 / (V1_COUNT + V2_COUNT) ))
        echo "v2 traffic:      ${V2_PERCENTAGE}%"
    fi
fi

echo
echo "-------------------------------------------"
echo "Next steps:"
echo "  1. Check Grafana for latency comparison"
echo "  2. Review Prometheus metrics:"
echo "     kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "  3. Query: rate(app_predictions_total[5m])"
echo "-------------------------------------------"
echo "Completed at: $(date '+%Y-%m-%d %H:%M:%S')"
