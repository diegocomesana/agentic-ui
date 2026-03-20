#!/bin/bash
set -e

CLUSTER_NAME="agentic-ui"
REGION="${AWS_REGION:-us-east-1}"
NODE_TYPE="${EKS_NODE_TYPE:-t3.small}"
NODE_COUNT="${EKS_NODE_COUNT:-2}"
ENV_FILE="${1:-.env.k8s.prod}"
GIT_SHA=$(git rev-parse --short HEAD)

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found"
  echo "Usage: ./k8s/eks/deploy.sh [env-file]"
  echo "Examples:"
  echo "  ./k8s/eks/deploy.sh                # reads .env.k8s.prod"
  echo "  ./k8s/eks/deploy.sh .env.k8s.qa    # reads .env.k8s.qa"
  exit 1
fi

# --- Prerequisitos: AWS credentials ---
echo "==> Checking AWS credentials..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "ERROR: AWS credentials not configured or expired."
  echo ""
  echo "Run 'aws configure' first. You need:"
  echo "  - AWS Access Key ID"
  echo "  - AWS Secret Access Key"
  echo "  - Region (default: us-east-1)"
  echo ""
  echo "Get your keys from: AWS Console → IAM → Your user → Security credentials → Create access key"
  exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
AWS_USER=$(aws sts get-caller-identity --query 'Arn' --output text)
echo "    Account: $AWS_ACCOUNT"
echo "    User: $AWS_USER"
echo "    Region: $REGION"
echo ""

# --- Prerequisitos: CLI tools ---
for cmd in docker eksctl kubectl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: '$cmd' not found. Install with: brew install $cmd"
    exit 1
  fi
done

# --- Paso 1: ECR ---
echo "==> Checking ECR repository..."
ECR_URI=$(aws ecr describe-repositories --repository-names agentic-ui --region "$REGION" --query 'repositories[0].repositoryUri' --output text 2>/dev/null || true)

if [ -z "$ECR_URI" ] || [ "$ECR_URI" = "None" ]; then
  echo "==> Creating ECR repository..."
  ECR_URI=$(aws ecr create-repository --repository-name agentic-ui --region "$REGION" --query 'repository.repositoryUri' --output text)
fi

IMAGE="$ECR_URI:$GIT_SHA"
echo "    ECR: $ECR_URI"
echo "    Image: $IMAGE"
echo ""

# --- Paso 2: Build & push ---
echo "==> Logging into ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_URI"
echo ""

echo "==> Building Docker image..."
docker build -t agentic-ui .
echo ""

echo "==> Tagging and pushing to ECR..."
docker tag agentic-ui:latest "$IMAGE"
docker push "$IMAGE"
echo ""

# --- Paso 3: EKS cluster ---
if eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo "==> Cluster '$CLUSTER_NAME' already exists, skipping creation"
else
  echo "==> Creating EKS cluster '$CLUSTER_NAME' ($NODE_COUNT x $NODE_TYPE)..."
  echo "    This takes ~15-20 minutes."
  eksctl create cluster \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --nodes "$NODE_COUNT" \
    --node-type "$NODE_TYPE"
fi
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
kubectl apply -f k8s/eks/service.yaml
echo ""

# --- Verificación ---
echo "==> Waiting for pods to be ready..."
kubectl rollout status deployment/agentic-ui -n agentic-ui --timeout=120s
echo ""

echo "==> Pod status:"
kubectl get pods -n agentic-ui
echo ""

echo "==> Service:"
kubectl get service agentic-ui -n agentic-ui
echo ""

echo "==> Deploy complete!"
echo "    URL: $(kubectl get service agentic-ui -n agentic-ui -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo 'pending (may take 1-2 min)')"
echo "    Logs: kubectl logs -n agentic-ui -l app=agentic-ui --tail=30 -f"
