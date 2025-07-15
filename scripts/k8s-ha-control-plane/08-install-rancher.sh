#!/bin/bash
read -p "Enter Rancher hostname (e.g., rancher.example.com): " RANCHER_HOSTNAME
echo "[RANCHER] Installing Rancher..."
kubectl create namespace cattle-system

kubectl create secret docker-registry rancher-registry-secret \
  --docker-server=docker.io \
  --docker-username=' ' \
  --docker-password=' ' \
  --docker-email=' ' \
  --namespace=cattle-system

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

helm install rancher rancher-latest/rancher \
  --namespace cattle-system --create-namespace \
  --set hostname="$RANCHER_HOSTNAME" \
  --set replicas=4 \
  --set global.cattle.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].key=kubernetes.io/hostname \
  --set global.cattle.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].operator=Exists \
  --set global.database.external.host=postgresql.postgresql.svc.cluster.local \
  --set global.database.external.port=5432 \
  --set global.database.external.username=rancher \
  --set global.database.external.password='rancher#2025' \
  --set global.database.external.database=rancherdb \
  --set global.imagePullSecrets=rancher-registry-secret
