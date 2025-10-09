#!/bin/bash
echo "=== Week 1 Verification ==="
echo ""

PASS=0
FAIL=0

# Check namespace
if oc get namespace happyotter-dev &>/dev/null; then
    echo "[PASS] Namespace exists"
    PASS=$((PASS+1))
else
    echo "[FAIL] Namespace not found"
    FAIL=$((FAIL+1))
fi

# Check deployment
REPLICAS=$(oc get deployment taskflow-backend -n happyotter-dev -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$REPLICAS" = "2" ]; then
    echo "[PASS] Deployment has 2 ready replicas"
    PASS=$((PASS+1))
else
    echo "[FAIL] Deployment not ready (found $REPLICAS replicas)"
    FAIL=$((FAIL+1))
fi

# Check service
if oc get service taskflow-backend -n happyotter-dev &>/dev/null; then
    echo "[PASS] Service exists"
    PASS=$((PASS+1))
else
    echo "[FAIL] Service not found"
    FAIL=$((FAIL+1))
fi

# Check endpoints
ENDPOINTS=$(oc get endpoints taskflow-backend -n happyotter-dev -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null | wc -w)
if [ "$ENDPOINTS" -eq 2 ]; then
    echo "[PASS] Service has 2 endpoints"
    PASS=$((PASS+1))
else
    echo "[FAIL] Service has $ENDPOINTS endpoints (expected 2)"
    FAIL=$((FAIL+1))
fi

# Test API with retries
echo "Testing API connectivity..."
oc port-forward svc/taskflow-backend 8080:8080 -n happyotter-dev >/dev/null 2>&1 &
PF_PID=$!
sleep 10

# Retry health check
for i in {1..3}; do
    if curl -sf --max-time 10 http://localhost:8080/health 2>/dev/null | grep -q "healthy"; then
        echo "[PASS] API health check passed"
        PASS=$((PASS+1))
        break
    fi
    if [ $i -eq 3 ]; then
        echo "[FAIL] API health check failed after 3 attempts"
        FAIL=$((FAIL+1))
    fi
    sleep 5
done

# Test API info endpoint
if curl -sf --max-time 10 http://localhost:8080/api 2>/dev/null | grep -q "TaskFlow API"; then
    echo "[PASS] API info endpoint works"
    PASS=$((PASS+1))
else
    echo "[FAIL] API info endpoint failed"
    FAIL=$((FAIL+1))
fi

# Test tasks endpoint
if curl -sf --max-time 10 http://localhost:8080/api/tasks 2>/dev/null | grep -q "Learn Kubernetes"; then
    echo "[PASS] API returns tasks"
    PASS=$((PASS+1))
else
    echo "[FAIL] API tasks endpoint failed"
    FAIL=$((FAIL+1))
fi

# Cleanup port-forward (cross-platform)
kill $PF_PID 2>/dev/null || true
sleep 1
pkill -f "port-forward.*taskflow-backend" 2>/dev/null || true

echo ""
echo "==================================="
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "[PASS] Week 1 Complete! Ready for Week 2."
    echo ""
    echo "Before starting Week 2, commit your work:"
    echo "  cd ~/taskflow-app"
    echo "  git add ."
    echo "  git commit -m 'Week 1 complete - Backend application'"
    exit 0
else
    echo "[FAIL] Fix failed checks before proceeding to Week 2."
    exit 1
fi