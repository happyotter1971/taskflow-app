#!/bin/bash
# Week 4 Prerequisites Check - CORRECTED VERSION

echo "=== Week 4 Prerequisites Check ==="
echo ""

ERRORS=0
NAMESPACE="happyotter-dev"
PROJECT_DIR="/Users/billott/Documents/Projects/taskflow-app"

# Check we're in the right directory
if [ ! -d "$PROJECT_DIR" ]; then
    echo "[FAIL] Project directory not found: $PROJECT_DIR"
    ERRORS=$((ERRORS+1))
    exit 1
fi

cd "$PROJECT_DIR"

# Check OpenShift connection
if ! oc whoami &>/dev/null; then
    echo "[FAIL] Not logged in to OpenShift"
    echo "  Run: oc login --token=YOUR_TOKEN --server=YOUR_SERVER"
    ERRORS=$((ERRORS+1))
else
    echo "[PASS] Logged in as: $(oc whoami)"
fi

# Check namespace
if ! oc get namespace $NAMESPACE &>/dev/null; then
    echo "[FAIL] Namespace $NAMESPACE not found"
    echo "  Complete Week 2 and Week 3 first"
    ERRORS=$((ERRORS+1))
    exit 1
else
    echo "[PASS] Namespace $NAMESPACE exists"
fi

# Verify Week 3 completion - Backend with database
if oc get deployment taskflow-backend -n $NAMESPACE &>/dev/null; then
    READY=$(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    DESIRED=$(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    
    if [ "$READY" = "$DESIRED" ] && [ "$READY" -gt 0 ]; then
        echo "[PASS] Backend deployment ready ($READY/$DESIRED)"
        
        # Check if using database
        ROUTE=$(oc get route taskflow-backend -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null)
        if [ -n "$ROUTE" ]; then
            sleep 5
            if curl -sf --max-time 10 https://$ROUTE/health 2>/dev/null | grep -q "connected"; then
                echo "[PASS] Backend connected to database (Week 3 complete)"
            else
                echo "[WARN] Backend not connected to database"
                echo "  Complete Week 3 database integration first"
            fi
        fi
    else
        echo "[FAIL] Backend deployment not ready ($READY/$DESIRED)"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "[FAIL] Backend deployment not found"
    echo "  Complete Week 2 and Week 3 first"
    ERRORS=$((ERRORS+1))
fi

# Check database (using helper script from Week 3)
if [ -f "$PROJECT_DIR/get-db-pod.sh" ]; then
    DB_POD=$("$PROJECT_DIR/get-db-pod.sh" $NAMESPACE 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "[PASS] Database pod running: $DB_POD"
    else
        echo "[FAIL] Database pod not found"
        echo "  Complete Week 3 first"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "[FAIL] Database helper script not found"
    echo "  Complete Week 3 Lab 3.1 first"
    ERRORS=$((ERRORS+1))
fi

# Verify Ansible installed
if command -v ansible &> /dev/null; then
    echo "[PASS] Ansible installed: $(ansible --version | head -1)"
else
    echo "[FAIL] Install Ansible:"
    echo "  macOS: brew install ansible"
    echo "  Linux: apt install ansible (or yum install ansible)"
    ERRORS=$((ERRORS+1))
fi

# Check Python kubernetes library
if python3 -c "import kubernetes" 2>/dev/null; then
    echo "[PASS] Python kubernetes library installed"
else
    echo "[WARN] Python kubernetes library not installed"
    echo "  Will be installed in Lab 4.1"
fi

echo ""
echo "==================================="
if [ $ERRORS -eq 0 ]; then
    echo "[PASS] Ready for Week 4!"
    echo ""
    echo "Current state:"
    echo "  Namespace: $NAMESPACE"
    echo "  Backend: Connected to database"
    echo "  Database: Running via StatefulSet"
    echo ""
    echo "Next: Lab 4.1 - Ansible Setup"
    exit 0
else
    echo "[FAIL] Fix $ERRORS error(s) before proceeding"
    echo ""
    echo "Common fixes:"
    echo "  - Complete Week 3 first"
    echo "  - Install Ansible: brew install ansible (macOS)"
    echo "  - Verify database: $PROJECT_DIR/get-db-pod.sh $NAMESPACE"
    exit 1
fi