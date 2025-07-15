#!/bin/bash
set -euo pipefail

CONTROL_PLANE_ENDPOINT="10.0.0.100:6443"
POD_CIDR="10.244.0.0/16"

echo "[BOOTSTRAP] Initializing control plane..."
kubeadm init \
  --control-plane-endpoint "$CONTROL_PLANE_ENDPOINT" \
  --upload-certs \
  --pod-network-cidr="$POD_CIDR"

mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

echo "Saving join commands..."
kubeadm token create --print-join-command > join-worker.sh
chmod +x join-worker.sh
CERT_KEY=$(kubeadm init phase upload-certs --upload-certs | tail -n1)

cat <<EOF > join-control-plane.sh
#!/bin/bash
kubeadm join $CONTROL_PLANE_ENDPOINT --control-plane --certificate-key $CERT_KEY --token <your-token> --discovery-token-ca-cert-hash sha256:<your-hash>
EOF
chmod +x join-control-plane.sh

echo "Run 'join-worker.sh' on workers and 'join-control-plane.sh' on secondary control plane nodes."
