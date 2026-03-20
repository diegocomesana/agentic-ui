#!/bin/bash
set -e

ENV_FILE="${1:-.env.k8s.prod}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: $ENV_FILE not found"
  echo "Usage: ./k8s/common/create-secrets.sh [env-file]"
  echo "Examples:"
  echo "  ./k8s/common/create-secrets.sh              # reads .env.k8s.prod"
  echo "  ./k8s/common/create-secrets.sh .env.k8s.dev # reads .env.k8s.dev"
  exit 1
fi

# Source the env file to get the values
set -a
source "$ENV_FILE"
set +a

# Validate required vars
for var in SECRET_KEY_BASE OPENAI_API_KEY; do
  if [ -z "${!var}" ]; then
    echo "Error: $var is not set in $ENV_FILE"
    exit 1
  fi
done

echo "==> Deleting old secret (if exists)..."
kubectl delete secret agentic-ui-secrets --namespace=agentic-ui 2>/dev/null || true

echo "==> Creating secrets..."
kubectl create secret generic agentic-ui-secrets \
  --namespace=agentic-ui \
  --from-literal=SECRET_KEY_BASE="$SECRET_KEY_BASE" \
  --from-literal=OPENAI_API_KEY="$OPENAI_API_KEY"

echo "==> Done. Secrets created:"
echo "    - SECRET_KEY_BASE"
echo "    - OPENAI_API_KEY"
echo ""
echo "To verify: kubectl get secret agentic-ui-secrets -n agentic-ui"
echo "To restart pods: kubectl rollout restart deployment/agentic-ui -n agentic-ui"
