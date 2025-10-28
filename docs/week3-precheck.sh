#!/bin/bash
# Week 3 Prerequisites Check - happyotter-dev version

echo "=== Week 3 Prerequisites Check ==="
echo ""

ERRORS=0
NAMESPACE="happyotter-dev"

# Check OpenShift connection
if ! oc whoami &>/dev/null; then
    echo "[FAIL] Not logged in to OpenShift"
    echo "  Run: oc login --token=YOUR_TOKEN --server=YOUR_SERVER"
    ERRORS=$((ERRORS+1))
else
    echo "[PASS] Logged in as: $(oc whoami)"
fi

# Check namespace exists
if oc get namespace $NAMESPACE &>/dev/null; then
    echo "[PASS] Namespace $NAMESPACE exists"
else
    echo "[FAIL] Namespace $NAMESPACE not found"
    echo "  Complete Week 2 first"
    ERRORS=$((ERRORS+1))
    exit 1
fi

# Switch to namespace
oc project $NAMESPACE &>/dev/null

# Check for backend deployment (Week 2 creates taskflow-backend)
if oc get deployment taskflow-backend -n $NAMESPACE &>/dev/null; then
    READY=$(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    DESIRED=$(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    
    if [ "$DESIRED" -eq 0 ]; then
        echo "[INFO] Backend deployment exists but scaled to 0"
        echo "  Scaling up to 2 replicas..."
        oc scale deployment/taskflow-backend --replicas=2 -n $NAMESPACE
        sleep 10
        READY=$(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
        DESIRED=$(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    fi
    
    if [ "$READY" = "$DESIRED" ]; then
        echo "[PASS] Backend deployment ready ($READY/$DESIRED)"
    else
        echo "[WARN] Backend deployment not fully ready ($READY/$DESIRED)"
        echo "  Waiting 30 more seconds..."
        sleep 30
        READY=$(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
        if [ "$READY" = "$DESIRED" ]; then
            echo "[PASS] Backend deployment now ready"
        else
            echo "[FAIL] Backend deployment not ready after waiting"
            ERRORS=$((ERRORS+1))
        fi
    fi
else
    echo "[FAIL] Backend deployment not found"
    echo "  Complete Week 2 first"
    ERRORS=$((ERRORS+1))
fi

# Check service exists
if oc get service taskflow-backend -n $NAMESPACE &>/dev/null; then
    echo "[PASS] Backend service exists"
else
    echo "[FAIL] Backend service not found"
    ERRORS=$((ERRORS+1))
fi

# Check route exists
if oc get route taskflow-backend -n $NAMESPACE &>/dev/null; then
    echo "[PASS] Route exists"
else
    echo "[FAIL] Route not found"
    ERRORS=$((ERRORS+1))
fi

# Test route (with retry)
ROUTE=$(oc get route taskflow-backend -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null)

if [ -n "$ROUTE" ]; then
    echo "[INFO] Testing route: https://$ROUTE"
    sleep 5
    
    ROUTE_OK=false
    for i in {1..3}; do
        if curl -sf --max-time 10 https://$ROUTE/health 2>/dev/null | grep -q "healthy"; then
            echo "[PASS] Backend accessible via route"
            ROUTE_OK=true
            break
        fi
        echo "  Retry $i/3..."
        sleep 5
    done
    
    if [ "$ROUTE_OK" = false ]; then
        echo "[WARN] Route not responding yet"
        echo "  Check pods: oc get pods -n $NAMESPACE"
        echo "  Check logs: oc logs -l component=backend -n $NAMESPACE"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "[WARN] Could not get route hostname"
fi

# Check ConfigMap
if oc get configmap taskflow-config -n $NAMESPACE &>/dev/null; then
    echo "[PASS] ConfigMap exists"
else
    echo "[INFO] ConfigMap will be updated in Week 3"
fi

# Check Git repository
cd ~/taskflow-app 2>/dev/null || {
    echo "[FAIL] ~/taskflow-app directory not found"
    ERRORS=$((ERRORS+1))
    exit 1
}

if [ -d .git ]; then
    echo "[PASS] Git repository initialized"
    
    # Check for uncommitted changes
    if [[ -n $(git status -s) ]]; then
        echo "[WARN] Uncommitted changes exist"
        echo "  Consider: git add . && git commit -m 'Pre-Week 3 checkpoint'"
    else
        echo "[PASS] Git working directory clean"
    fi
else
    echo "[WARN] Git not initialized (optional but recommended)"
fi

# Summary
echo ""
echo "==================================="
if [ $ERRORS -eq 0 ]; then
    echo "[PASS] Ready for Week 3!"
    echo ""
    echo "Application status:"
    echo "  Namespace: $NAMESPACE"
    echo "  Backend: $(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')/$(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.spec.replicas}') pods ready"
    echo "  Route: https://$ROUTE"
    echo ""
    echo "Next: Lab 3.1 - Create database pod helper script"
    exit 0
else
    echo "[FAIL] Fix $ERRORS error(s) before proceeding"
    echo ""
    echo "Common fixes:"
    echo "  - Complete Week 2 first"
    echo "  - Scale up deployment: oc scale deployment/taskflow-backend --replicas=2 -n $NAMESPACE"
    echo "  - Check pod status: oc get pods -n $NAMESPACE"
    echo "  - Check pod logs: oc logs -l component=backend -n $NAMESPACE"
    exit 1
fi