#!/bin/bash
# Rate Limiting Test Script
# Tests the Istio rate limiting feature by sending rapid requests

set -euo pipefail

TARGET_URL="${1:-http://app.sms-detector.local}"
NUM_REQUESTS="${2:-15}"
EXPECTED_LIMIT="${3:-10}"

echo "Rate Limiting Test"
echo "-------------------------------------------"
echo "Target:         $TARGET_URL"
echo "Total requests: $NUM_REQUESTS"
echo "Expected limit: $EXPECTED_LIMIT req/min"
echo "-------------------------------------------"
echo

SUCCESS_COUNT=0
RATE_LIMITED_COUNT=0
OTHER_COUNT=0

for i in $(seq 1 $NUM_REQUESTS); do
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$TARGET_URL" 2>/dev/null || echo "000")

  case "$RESPONSE" in
    200)
      echo "Request $i: OK (HTTP 200)"
      ((SUCCESS_COUNT++))
      ;;
    429)
      echo "Request $i: RATE LIMITED (HTTP 429)"
      ((RATE_LIMITED_COUNT++))
      ;;
    000)
      echo "Request $i: TIMEOUT/ERROR"
      ((OTHER_COUNT++))
      ;;
    *)
      echo "Request $i: HTTP $RESPONSE"
      ((OTHER_COUNT++))
      ;;
  esac

  sleep 0.1
done

echo
echo "-------------------------------------------"
echo "Results:"
echo "  Successful:    $SUCCESS_COUNT"
echo "  Rate limited:  $RATE_LIMITED_COUNT"
echo "  Other/errors:  $OTHER_COUNT"
echo "-------------------------------------------"

if [ $OTHER_COUNT -gt 0 ]; then
  echo "Status: Some requests failed - check connectivity"
  exit 1
elif [ $SUCCESS_COUNT -le $EXPECTED_LIMIT ] && [ $RATE_LIMITED_COUNT -ge 1 ]; then
  echo "Status: Rate limiting working correctly"
  exit 0
elif [ $RATE_LIMITED_COUNT -eq 0 ]; then
  echo "Status: No rate limiting detected - check EnvoyFilter config"
  exit 1
else
  echo "Status: Unexpected behavior - review results"
  exit 1
fi
