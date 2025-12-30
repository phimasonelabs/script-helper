#!/usr/bin/env bash
set -euo pipefail

HOSTNAME="$1"
NAMESPACE="harbor"
CERT_DIR="./harbor-cert"

if [[ -z "${HOSTNAME:-}" ]]; then
  echo "Usage: $0 <harbor-hostname>"
  exit 1
fi

kubectl get ns $NAMESPACE >/dev/null 2>&1 || kubectl create ns $NAMESPACE

echo "🔐 Creating Harbor TLS secret"
kubectl -n $NAMESPACE create secret tls harbor-tls \
  --cert="$CERT_DIR/tls.crt" \
  --key="$CERT_DIR/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "🔐 Creating Harbor CA secret"
kubectl -n $NAMESPACE create secret generic harbor-ca \
  --from-file=ca.crt="$CERT_DIR/ca.crt" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "🧩 Rendering Helm values"
sed "s/{{HOSTNAME}}/$HOSTNAME/g" values/harbor-values.tpl.yaml > /tmp/harbor-values.yaml

helm repo add harbor https://helm.goharbor.io
helm repo update

helm upgrade --install harbor harbor/harbor \
  -n $NAMESPACE \
  -f /tmp/harbor-values.yaml

echo "✅ Harbor installed at https://$HOSTNAME"
echo ""
echo "⚠️ IMPORTANT: Trust Harbor CA on ALL cluster nodes"
echo "Run the following on every Kubernetes node:"
echo ""
echo "  sudo cp harbor-cert/ca.crt /usr/local/share/ca-certificates/harbor-ca.crt"
echo "  sudo update-ca-certificates"
echo "  sudo systemctl restart containerd docker"
echo ""