#!/bin/bash
# Database Pod Selection Helper - Fixed Logic

NAMESPACE=${1:-happyotter-dev}

# Try StatefulSet naming pattern FIRST (most reliable)
POD="taskflow-db-0"

if oc get pod $POD -n $NAMESPACE &>/dev/null; then
    POD_STATUS=$(oc get pod $POD -n $NAMESPACE -o jsonpath='{.status.phase}')
    if [ "$POD_STATUS" = "Running" ]; then
        echo "$POD"
        exit 0
    else
        echo "Error: Database pod $POD exists but is not Running (status: $POD_STATUS)" >&2
        exit 1
    fi
fi

# Fallback to label-based selection (Operator deployments)
POD=$(oc get pods -l app=taskflow,component=database -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$POD" ]; then
    POD_STATUS=$(oc get pod $POD -n $NAMESPACE -o jsonpath='{.status.phase}')
    if [ "$POD_STATUS" = "Running" ]; then
        echo "$POD"
        exit 0
    fi
fi

echo "Error: No database pod found in namespace $NAMESPACE" >&2
exit 1
