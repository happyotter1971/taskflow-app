#!/bin/bash
echo "=== Week 2 Verification ==="
echo ""

NAMESPACE="happyotter-dev"
ERRORS=0

# Check namespace
if oc get namespace $NAMESPACE &>/dev/null; then
    echo "[PASS] Namespace exists"
else
    echo "[FAIL] Namespace not found"
    ERRORS=$((ERRORS+1))
fi

# Check manual deployment
if oc get deployment taskflow-backend -n $NAMESPACE &>/dev/null; then
    READY=$(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    DESIRED=$(oc get deployment taskflow-backend -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    if [ "$READY" = "$DESIRED" ]; then
        echo "[PASS] Manual deployment ready ($READY/$DESIRED)"
    else
        echo "[FAIL] Manual deployment not ready ($READY/$DESIRED)"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "[WARN] Manual deployment not found"
fi

# Check S2I deployment
if oc get deployment taskflow-backend-s2i -n $NAMESPACE &>/dev/null; then
    READY=$(oc get deployment taskflow-backend-s2i -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    DESIRED=$(oc get deployment taskflow-backend-s2i -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    if [ "$READY" = "$DESIRED" ]; then
        echo "[PASS] S2I deployment ready ($READY/$DESIRED)"
    else
        echo "[FAIL] S2I deployment not ready ($READY/$DESIRED)"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "[FAIL] S2I deployment not found"
    ERRORS=$((ERRORS+1))
fi

# Check ImageStream
if oc get imagestream taskflow-backend -n $NAMESPACE &>/dev/null; then
    echo "[PASS] ImageStream exists"
else
    echo "[FAIL] ImageStream not found"
    ERRORS=$((ERRORS+1))
fi

# Check BuildConfig
if oc get buildconfig taskflow-backend -n $NAMESPACE &>/dev/null; then
    echo "[PASS] BuildConfig exists"
else
    echo "[FAIL] BuildConfig not found"
    ERRORS=$((ERRORS+1))
fi

# Check successful build
BUILD_COUNT=$(oc get builds -n $NAMESPACE -o jsonpath='{.items[?(@.status.phase=="Complete")].metadata.name}' | wc -w)
if [ "$BUILD_COUNT" -gt 0 ]; then
    echo "[PASS] Found $BUILD_COUNT successful build(s)"
else
    echo "[FAIL] No successful builds found"
    ERRORS=$((ERRORS+1))
fi

# Check routes
if oc get route taskflow-backend-s2i -n $NAMESPACE &>/dev/null; then
    ROUTE=$(oc get route taskflow-backend-s2i -n $NAMESPACE -o jsonpath='{.spec.host}')
    echo "[PASS] S2I route exists: https://$ROUTE"
    
    sleep 5
    if curl -sf --max-time 10 https://$ROUTE/health | grep -q "healthy"; then
        echo "[PASS] S2I route is accessible"
    else
        echo "[FAIL] S2I route not accessible"
        ERRORS=$((ERRORS+1))
    fi
else
    echo "[FAIL] S2I route not found"
    ERRORS=$((ERRORS+1))
fi

# Check CI/CD
if [ -f .github/workflows/dev-ci.yml ]; then
    echo "[PASS] CI/CD workflow file exists"
else
    echo "[FAIL] CI/CD workflow not found"
    ERRORS=$((ERRORS+1))
fi

# Check Git
if [ -d .git ]; then
    echo "[PASS] Git repository initialized"
    
    if git remote | grep -q origin; then
        REMOTE=$(git remote get-url origin)
        echo "[PASS] Git remote configured: $REMOTE"
    else
        echo "[WARN] Git remote not configured"
    fi
else
    echo "[FAIL] Git repository not found"
    ERRORS=$((ERRORS+1))
fi

echo ""
echo "==================================="
if [ $ERRORS -eq 0 ]; then
    echo "[PASS] Week 2 Complete!"
    echo ""
    echo "You now have:"
    echo "  - happyotter-dev namespace"
    echo "  - S2I build pipeline from GitHub"
    echo "  - CI/CD with security scanning"
    echo "  - Automated deployment"
    echo "  - OpenShift Routes with HTTPS"
    echo ""
    echo "Next: Week 3 - Database Integration"
    exit 0
else
    echo "[FAIL] $ERRORS error(s) found"
    echo ""
    echo "Common fixes:"
    echo "  - Wait for build to complete: oc get builds"
    echo "  - Check build logs: oc logs -f bc/taskflow-backend"
    echo "  - Verify GitHub repo is public"
    echo "  - Check GitHub Actions secrets are configured"
    exit 1
fi