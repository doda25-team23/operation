#!/bin/bash
# Canary Experiment Runner
# Executes a full canary experiment workflow with validation and metrics collection

set -euo pipefail

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
./validate-canary-setup.sh "$NAMESPACE" > /tmp/validation.log 2>&1 || true
if grep -q "\[ERROR\]" /tmp/validation.log; then
    echo "Validation failed with errors. Check /tmp/validation.log"
    cat /tmp/validation.log
    exit 1
fi
echo "      Deployment validated (warnings may exist)"
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
echo "[3/4] Generating prediction traffic for ${DURATION}s..."
echo "      (sending POST requests every 2 seconds)"

# Sample SMS messages for testing (mix of ham and spam-like)
SMS_MESSAGES=(
    "Hey, are you free for lunch today?"
    "CONGRATULATIONS! You won a FREE prize! Call now!"
    "Meeting rescheduled to 3pm tomorrow"
    "FREE entry in our weekly contest! Text WIN to 12345"
    "Can you pick up milk on your way home?"
    "URGENT: Your account has been compromised, click here"
    "Happy birthday! Hope you have a great day"
    "You have been selected for a cash prize! Claim now"
    "Running late, be there in 10 minutes"
    "Win a brand new iPhone! Reply YES to claim"
)

V1_COUNT=0
V2_COUNT=0
ERROR_COUNT=0
TOTAL_COUNT=0
START_TIME=$(date +%s)

while [ $(($(date +%s) - START_TIME)) -lt "$DURATION" ]; do
    # Pick a random SMS message
    SMS="${SMS_MESSAGES[$((RANDOM % ${#SMS_MESSAGES[@]}))]}"

    # Make POST request to trigger actual prediction
    # Host header required for Istio VirtualService routing
    RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 \
        -X POST \
        -H "Host: app.sms-detector.local" \
        --data-urlencode "sms=$SMS" \
        "${TARGET_URL}/sms/" 2>/dev/null || echo -e "\n000")
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | head -n -1)

    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    if [ "$HTTP_CODE" = "200" ]; then
        # Try to detect version from response if available
        if echo "$BODY" | grep -q "v2\|version.*2" 2>/dev/null; then
            V2_COUNT=$((V2_COUNT + 1))
        else
            V1_COUNT=$((V1_COUNT + 1))
        fi
    else
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi

    # Progress indicator every 30 requests
    if [ $((TOTAL_COUNT % 30)) -eq 0 ]; then
        ELAPSED=$(($(date +%s) - START_TIME))
        echo "      ${ELAPSED}s elapsed - ${TOTAL_COUNT} requests sent (v1: $V1_COUNT, v2: $V2_COUNT, errors: $ERROR_COUNT)"
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
