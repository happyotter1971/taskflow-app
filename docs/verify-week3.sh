#!/bin/bash
echo "=== Week 3 Verification ==="
echo ""

ERRORS=0
NAMESPACE="happyotter-dev"

# Check database pod
echo "Checking database..."
DB_POD=$(/Users/billott/Documents/Projects/taskflow-app/get-db-pod.sh $NAMESPACE 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "[PASS] Database pod running: $DB_POD"
else
    echo "[FAIL] Database pod not found"
    ERRORS=$((ERRORS+1))
fi

# Check StatefulSet
if oc get statefulset taskflow-db -n $NAMESPACE &>/dev/null; then
    READY=$(oc get statefulset taskflow-db -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    if [ "$READY" = "1" ]; then
        echo "[PASS] StatefulSet ready (1/1)"
    else
        echo "[FAIL] StatefulSet not ready ($READY/1)"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "[FAIL] StatefulSet not found"
    ERRORS=$((ERRORS+1))
fi

# Check backend deployment
if oc get deployment taskflow-backend -n $NAMESPACE &>/dev/null; then
    READY=$(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    DESIRED=$(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    if [ "$READY" = "$DESIRED" ]; then
        echo "[PASS] Backend running ($READY/$DESIRED replicas)"
    else
        echo "[FAIL] Backend not ready ($READY/$DESIRED)"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "[FAIL] Backend deployment not found"
    ERRORS=$((ERRORS+1))
fi

# Check database secret
if oc get secret taskflow-db-secret -n $NAMESPACE &>/dev/null; then
    echo "[PASS] Database secret exists"
else
    echo "[FAIL] Database secret not found"
    ERRORS=$((ERRORS+1))
fi

# Test application with retries
echo ""
echo "Testing application..."
ROUTE=$(oc get route taskflow-backend -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null)

if [ -n "$ROUTE" ]; then
    # Wait for route to be ready
    sleep 10
    
    # Test with retries
    for i in {1..5}; do
        if curl -sf --max-time 10 https://$ROUTE/health 2>/dev/null | grep -q "connected"; then
            echo "[PASS] Application connected to database"
            break
        elif [ $i -eq 5 ]; then
            echo "[FAIL] Database connection failed after 5 attempts"
            ERRORS=$((ERRORS+1))
        else
            echo "[INFO] Retry $i/5..."
            sleep 10
        fi
    done
    
    # Test tasks endpoint
    if curl -sf --max-time 10 https://$ROUTE/api/tasks 2>/dev/null | grep -q "Learn Kubernetes"; then
        echo "[PASS] API returns tasks from database"
    else
        echo "[FAIL] Tasks endpoint failed"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "[FAIL] Route not found"
    ERRORS=$((ERRORS+1))
fi

# Check database schema
if [ -n "$DB_POD" ]; then
    if oc exec $DB_POD -n $NAMESPACE -- psql -U taskflowuser -d taskflowdb -c "\dt" 2>/dev/null | grep -q "tasks"; then
        echo "[PASS] Database schema initialized"
    else
        echo "[FAIL] Database schema not found"
        ERRORS=$((ERRORS+1))
    fi
fi

# Summary
echo ""
echo "==================================="
if [ $ERRORS -eq 0 ]; then
    echo "[PASS] Week 3 Complete!"
    echo ""
    echo "Application URLs:"
    echo "  API: https://$ROUTE"
    echo "  Health: https://$ROUTE/health"
    echo "  Tasks: https://$ROUTE/api/tasks"
    echo ""
    echo "Next steps:"
    echo "  1. Commit your work: git add . && git commit -m 'Week 3 complete'"
    echo "  2. Continue to Week 4: Ansible Automation"
    exit 0
else
    echo "[FAIL] $ERRORS error(s) found"
    echo ""
    echo "Common issues:"
    echo "  - Database pod not ready (wait 60s)"
    echo "  - Schema not loaded (run init.sql)"
    echo "  - Backend using wrong ConfigMap"
    echo "  - Route not accessible (wait 30s)"
    exit 1
fi