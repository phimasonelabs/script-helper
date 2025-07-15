#!/bin/bash
echo "[POSTGRES] Installing PostgreSQL..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install postgresql bitnami/postgresql \
  --namespace postgresql --create-namespace \
  --set auth.username=rancher \
  --set auth.password=rancher#2025 \
  --set auth.database=rancherdb \
  --set primary.persistence.storageClass=longhorn \
  --set primary.persistence.size=10Gi \
  --set service.type=LoadBalancer
