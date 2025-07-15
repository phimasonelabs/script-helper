#!/bin/bash
read -p "Enter the static IP for NGINX Ingress LoadBalancer: " INGRESS_IP
echo "[NGINX] Installing Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml

kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx

kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
  --type='json' \
  -p='[
    {"op": "add", "path": "/spec/template/spec/hostNetwork", "value": true},
    {"op": "replace", "path": "/spec/template/spec/dnsPolicy", "value": "ClusterFirstWithHostNet"}
  ]'

kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx

kubectl patch svc ingress-nginx-controller -n ingress-nginx \
  -p "{"spec": {"type": "LoadBalancer", "loadBalancerIP": "$INGRESS_IP"}}"
