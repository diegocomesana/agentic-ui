#!/bin/bash
set -e

CLUSTER_NAME="agentic-ui"
ENV_FILE="${1:-.env.k8s.dev}"
GIT_SHA=$(git rev-parse --short HEAD)
if [ -n "$(git status --porcelain)" ]; then
  GIT_SHA="${GIT_SHA}-dirty"
fi
IMAGE="agentic-ui:$GIT_SHA"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found"
  echo "Usage: ./k8s/kind/deploy.sh [env-file]"
  echo "Examples:"
  echo "  ./k8s/kind/deploy.sh              # reads .env.k8s.dev"
  echo "  ./k8s/kind/deploy.sh .env.k8s.qa  # reads .env.k8s.qa"
  exit 1
fi

echo "==> Deploy to Kind | image=$IMAGE | env=$ENV_FILE"
echo ""

# --- Paso 1: Cluster ---
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "==> Cluster '$CLUSTER_NAME' already exists, skipping creation"
else
  echo "==> Creating Kind cluster '$CLUSTER_NAME'..."
  kind create cluster --name "$CLUSTER_NAME" --config k8s/kind/kind-config.yaml
fi
echo ""

# --- Paso 2: Build ---
echo "==> Building Docker image $IMAGE..."
docker build -t "$IMAGE" .
echo ""

# --- Paso 3: Load image into Kind ---
echo "==> Loading image into Kind..."
kind load docker-image "$IMAGE" --name "$CLUSTER_NAME"
echo ""

# --- Paso 4: Namespace ---
echo "==> Applying namespace..."
kubectl apply -f k8s/common/namespace.yaml
echo ""

# --- Paso 5: Secrets ---
if kubectl get secret agentic-ui-secrets -n agentic-ui >/dev/null 2>&1; then
  echo "==> Secrets already exist, skipping (delete manually to recreate)"
else
  echo "==> Creating secrets from $ENV_FILE..."
  bash k8s/common/create-secrets.sh "$ENV_FILE"
fi
echo ""

# --- Paso 6: Deploy ---
echo "==> Applying deployment (image=$IMAGE)..."
sed 's|${IMAGE}|'"$IMAGE"'|' k8s/common/deployment.yaml | kubectl apply -f -
echo ""

echo "==> Applying service..."
kubectl apply -f k8s/kind/service.yaml
echo ""

# --- Verificación ---
echo "==> Waiting for pods to be ready..."
kubectl rollout status deployment/agentic-ui -n agentic-ui --timeout=60s
echo ""

echo "==> Pod status:"
kubectl get pods -n agentic-ui
echo ""

echo "==> Deploy complete!"
echo "    App: http://localhost:30080"
echo "    Logs: kubectl logs -n agentic-ui -l app=agentic-ui --tail=30 -f"
