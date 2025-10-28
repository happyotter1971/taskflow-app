#!/bin/bash
# Environment setup for Ansible automation
# Copy to env.sh and customize

echo "=== TaskFlow Ansible Environment Setup ==="

PROJECT_DIR="/Users/billott/Documents/Projects/taskflow-app"

# Ensure we're in the right directory
if [ ! -d "$PROJECT_DIR" ]; then
    echo "[FAIL] Project directory not found: $PROJECT_DIR"
    return 1
fi

cd "$PROJECT_DIR/ansible"

# Ensure collections directory exists
if [ ! -d ~/.ansible/collections/ansible_collections ]; then
    mkdir -p ~/.ansible/collections/ansible_collections
    echo "[PASS] Created collections directory"
fi

# Set your Quay.io username
export QUAY_USERNAME="happyotter"

# Verify OpenShift connection
if ! oc whoami &> /dev/null; then
    echo "[FAIL] Not logged in to OpenShift"
    echo "Run: oc login --token=YOUR_TOKEN --server=YOUR_SERVER"
    return 1
fi

echo "[PASS] OpenShift: $(oc whoami) @ $(oc whoami --show-server)"

# Verify dependencies (consolidated check)
DEPS_OK=true

for lib in kubernetes openshift; do
    if ! python3 -c "import $lib" 2>/dev/null; then
        echo "[FAIL] Python library '$lib' missing"
        DEPS_OK=false
    fi
done

for collection in kubernetes.core community.okd; do
    if ! ansible-galaxy collection list 2>/dev/null | grep -q "$collection"; then
        echo "[FAIL] Ansible collection '$collection' missing"
        DEPS_OK=false
    fi
done

# Auto-install missing dependencies
if [ "$DEPS_OK" = false ]; then
    echo "Installing missing dependencies..."
    pip3 install kubernetes openshift
    ansible-galaxy collection install kubernetes.core community.okd
fi

# Verify username
if [ -z "$QUAY_USERNAME" ] || [ "$QUAY_USERNAME" = "happyotter" ]; then
    echo "[WARN] Set QUAY_USERNAME in env.sh"
else
    echo "[PASS] QUAY_USERNAME: $QUAY_USERNAME"
fi

echo "[PASS] Environment ready"