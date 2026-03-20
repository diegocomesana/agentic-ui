#!/bin/bash
set -e

CLUSTER_NAME="agentic-ui"
REGION="${AWS_REGION:-us-east-1}"

echo "==> Destroying EKS environment"
echo "    Cluster: $CLUSTER_NAME"
echo "    Region: $REGION"
echo ""

# --- K8s resources (libera el LoadBalancer antes de borrar el cluster) ---
if eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo "==> Deleting K8s resources..."
  kubectl delete -f k8s/eks/service.yaml --ignore-not-found
  kubectl delete -f k8s/common/namespace.yaml --ignore-not-found
  echo ""

  echo "==> Deleting EKS cluster '$CLUSTER_NAME' (~10 min)..."
  eksctl delete cluster --name "$CLUSTER_NAME" --region "$REGION"
else
  echo "==> Cluster '$CLUSTER_NAME' not found, skipping"
fi
echo ""

# --- ECR ---
echo "==> Deleting ECR repository (if exists)..."
aws ecr delete-repository --repository-name agentic-ui --region "$REGION" --force 2>/dev/null || echo "    ECR not found, skipping"
echo ""

# --- Local Docker images ---
if docker images agentic-ui -q 2>/dev/null | grep -q .; then
  echo "==> Removing local Docker images..."
  docker rmi $(docker images agentic-ui -q) 2>/dev/null
else
  echo "==> No local Docker images found, skipping"
fi
echo ""

echo "==> Done. Everything cleaned up."
echo "    Verify in AWS console: https://console.aws.amazon.com"
