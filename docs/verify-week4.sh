#!/bin/bash
echo "=== Week 4 Verification ==="
echo ""

ERRORS=0
NAMESPACE="happyotter-dev"
PROJECT_DIR="/Users/billott/Documents/Projects/taskflow-app"

cd "$PROJECT_DIR"

# Check Ansible directory structure
if [ -d "ansible/roles/taskflow-backend" ] && [ -d "ansible/roles/taskflow-database" ]; then
    echo "[PASS] Ansible roles exist"
else
    echo "[FAIL] Ansible roles not found"
    ERRORS=$((ERRORS+1))
fi

# Check playbooks
if [ -f "ansible/playbooks/deploy-full-stack.yml" ]; then
    echo "[PASS] Deploy playbook exists"
else
    echo "[FAIL] Deploy playbook not found"
    ERRORS=$((ERRORS+1))
fi

# Check inventory uses correct namespace
if grep -q "happyotter-dev" ansible/inventory/openshift.yml; then
    echo "[PASS] Inventory uses correct namespace"
else
    echo "[FAIL] Inventory has wrong namespace"
    ERRORS=$((ERRORS+1))
fi

# Check deployment
if oc get deployment taskflow-backend -n $NAMESPACE &>/dev/null; then
    READY=$(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    DESIRED=$(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    
    if [ "$READY" = "$DESIRED" ]; then
        echo "[PASS] Backend deployment ready ($READY/$DESIRED)"
    else
        echo "[FAIL] Backend deployment not ready ($READY/$DESIRED)"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "[FAIL] Backend deployment not found"
    ERRORS=$((ERRORS+1))
fi

# Check database using helper script from Week 3
if [ -f "$PROJECT_DIR/get-db-pod.sh" ]; then
    DB_POD=$("$PROJECT_DIR/get-db-pod.sh" $NAMESPACE 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "[PASS] Database pod running: $DB_POD"
    else
        echo "[FAIL] Database pod not found"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "[WARN] Database helper script not found (from Week 3)"
fi

# Test application
ROUTE=$(oc get route taskflow-backend -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null)

if [ -n "$ROUTE" ]; then
    sleep 10
    
    if curl -sf --max-time 10 https://$ROUTE/health 2>/dev/null | grep -q "connected"; then
        echo "[PASS] Application accessible and connected to database"
    else
        echo "[FAIL] Application not responding correctly"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "[FAIL] Route not found"
    ERRORS=$((ERRORS+1))
fi

echo ""
echo "==================================="
if [ $ERRORS -eq 0 ]; then
    echo "[PASS] Week 4 Complete!"
    echo ""
    echo "You can now deploy the entire stack with one command:"
    echo "  cd $PROJECT_DIR/ansible"
    echo "  source env.sh"
    echo "  ansible-playbook playbooks/deploy-full-stack.yml"
    echo ""
    echo "Next: Week 5 - Frontend and Production Operations"
    exit 0
else
    echo "[FAIL] $ERRORS error(s) found"
    echo ""
    echo "Common fixes:"
    echo "  - Verify namespace is happyotter-dev in all files"
    echo "  - Run: source ansible/env.sh"
    echo "  - Check: pip3 install kubernetes openshift"
    exit 1
fi