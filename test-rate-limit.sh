#!/bin/bash
# Rate Limiting Test Script
# This script tests the rate limiting feature by sending multiple requests

echo "========================================="
echo "Testing Rate Limiting (10 req/min)"
echo "========================================="
echo ""
echo "Configuration: 10 requests per minute allowed"
echo "Expected: First 10 requests succeed (200), next 5+ fail (429)"
echo ""

# Set the target URL (update this based on your ingress configuration)
TARGET_URL="http://app.sms-detector.local"

# Counter for tracking
SUCCESS_COUNT=0
RATE_LIMITED_COUNT=0

echo "Sending 15 requests in rapid succession..."
echo ""

for i in {1..15}; do
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_URL")

  if [ "$RESPONSE" -eq 200 ]; then
    echo "Request $i: ✓ SUCCESS (HTTP 200)"
    ((SUCCESS_COUNT++))
  elif [ "$RESPONSE" -eq 429 ]; then
    echo "Request $i: ✗ RATE LIMITED (HTTP 429)"
    ((RATE_LIMITED_COUNT++))
  else
    echo "Request $i: ? UNEXPECTED (HTTP $RESPONSE)"
  fi

  # Small delay to see the output clearly
  sleep 0.1
done

echo ""
echo "========================================="
echo "Results:"
echo "  Successful requests: $SUCCESS_COUNT"
echo "  Rate limited requests: $RATE_LIMITED_COUNT"
echo "========================================="
echo ""

if [ $SUCCESS_COUNT -le 10 ] && [ $RATE_LIMITED_COUNT -ge 5 ]; then
  echo "✓ Rate limiting is working as expected!"
else
  echo "⚠ Rate limiting behavior unexpected. Check configuration."
fi

echo ""
echo "To check Envoy stats, run:"
echo "kubectl exec -n sms-app <frontend-pod> -c istio-proxy -- curl localhost:15000/stats | grep rate_limit"
