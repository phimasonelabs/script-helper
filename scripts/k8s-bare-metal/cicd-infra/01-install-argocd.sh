#!/usr/bin/env bash
set -e

NAMESPACE=argocd

echo "🚀 Installing ArgoCD..."

kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n $NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Waiting for ArgoCD to be ready..."
kubectl rollout status deployment/argocd-server -n $NAMESPACE

echo "✅ ArgoCD installed successfully"

echo "🔐 Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo