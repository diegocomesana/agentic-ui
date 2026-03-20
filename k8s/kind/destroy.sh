#!/bin/bash
set -e

CLUSTER_NAME="agentic-ui"

echo "==> Destroying Kind environment"
echo ""

# --- Cluster ---
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "==> Deleting Kind cluster '$CLUSTER_NAME'..."
  kind delete cluster --name "$CLUSTER_NAME"
else
  echo "==> Cluster '$CLUSTER_NAME' not found, skipping"
fi
echo ""

# --- Docker images ---
if docker images agentic-ui -q 2>/dev/null | grep -q .; then
  echo "==> Removing local Docker images..."
  docker rmi $(docker images agentic-ui -q) 2>/dev/null
else
  echo "==> No local Docker images found, skipping"
fi
echo ""

# --- Verify ---
echo "==> Verification:"
echo "    Clusters: $(kind get clusters 2>/dev/null || echo 'none')"
echo "    Images:   $(docker images agentic-ui -q 2>/dev/null | wc -l | tr -d ' ') remaining"
echo ""
echo "==> Done. Everything cleaned up."
