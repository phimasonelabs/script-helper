#!/usr/bin/env bash
set -e

NAMESPACE=actions-runner-system

echo "🚀 Installing Actions Runner Controller..."

kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update

helm upgrade --install actions-runner-controller \
  actions-runner-controller/actions-runner-controller \
  -n $NAMESPACE \
  --set certManager.enabled=false

echo "⏳ Waiting for controller..."
kubectl rollout status deployment/actions-runner-controller -n $NAMESPACE

echo "📦 Applying runner deployment..."
kubectl apply -f runner/runner-deployment.yaml

echo "✅ GitHub Actions Runner deployed successfully"