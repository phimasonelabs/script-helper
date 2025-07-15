#!/bin/bash
set -euo pipefail

# Check if the script is run with sudo privileges
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root or with sudo privileges."
  exit 1
fi

# Prompt for MetalLB IP address range
read -p "Enter the IP address range for MetalLB (e.g., 192.168.1.100-192.168.1.110): " METALLB_IP_RANGE
if [[ -z "$METALLB_IP_RANGE" ]]; then
  echo "Error: MetalLB IP address range is required. Please run the script again and provide the input."
  exit 1
fi

# Prompt for Rancher hostname
read -p "Enter the desired Rancher hostname (e.g., rancher.example.com): " RANCHER_HOSTNAME
if [[ -z "$RANCHER_HOSTNAME" ]]; then
  echo "Error: Rancher hostname is required. Please run the script again and provide the input."
  exit 1
fi

# Prompt for Ingress Nginx LoadBalancer IP
read -p "Enter the static IP address for the Nginx Ingress Controller LoadBalancer: " INGRESS_IP
if [[ -z "$INGRESS_IP" ]]; then
  echo "Error: Static IP address for the Nginx Ingress Controller is required. Please run the script again and provide the input."
  exit 1
fi

# --- Control Plane Setup ---
echo "Setting up the Kubernetes control plane..."
kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

echo "Control plane setup completed. Please label your worker nodes using 'kubectl label nodes --all node-role.kubernetes.io/worker=worker'."
read -p "Press Enter to continue with network setup (Flannel)..."

# --- Deploy Flannel Network ---
echo "Deploying Flannel CNI network..."
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
echo "Flannel network deployed."
read -p "Press Enter to continue with Longhorn storage setup..."

# --- Setup Longhorn Storage ---
echo "Setting up Longhorn storage..."
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version 1.7.2
echo "Longhorn storage deployed."
read -p "Press Enter to continue with Metrics Server setup..."

# --- Setup Metrics Server ---
echo "Setting up Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[{
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }]'
echo "Metrics Server deployed."
read -p "Press Enter to continue with cert-manager installation..."

# --- Install cert-manager ---
echo "Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io
helm repo update
kubectl apply --validate=false -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.3/cert-manager.crds.yaml
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.12.3
echo "cert-manager installed."
read -p "Press Enter to continue with MetalLB load-balancer deployment..."

# --- Deploy MetalLB Load-Balancer ---
echo "Deploying MetalLB load-balancer..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - $METALLB_IP_RANGE
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2
  namespace: metallb-system
EOF
echo "MetalLB load-balancer deployed with IP range: $METALLB_IP_RANGE"
read -p "Press Enter to continue with PostgreSQL deployment for Rancher..."

# --- Deploy PostgreSQL for Rancher Web UI ---
echo "Deploying PostgreSQL for Rancher web UI..."
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
echo "PostgreSQL for Rancher deployed."
read -p "Press Enter to continue with Rancher web UI setup..."

# --- Setup Rancher Web UI ---
echo "Setting up Rancher web UI..."
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
echo "Rancher Web UI deployment initiated with hostname: $RANCHER_HOSTNAME."
read -p "Press Enter to continue with Nginx Ingress Controller installation..."

# --- Install Nginx Ingress Controller ---
echo "Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml

echo "Waiting for ingress-nginx-controller deployment to be ready..."
kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx

echo "Patching ingress-nginx-controller to use hostNetwork and proper dnsPolicy..."
kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
  --type='json' \
  -p='[
    {"op": "add", "path": "/spec/template/spec/hostNetwork", "value": true},
    {"op": "replace", "path": "/spec/template/spec/dnsPolicy", "value": "ClusterFirstWithHostNet"}
  ]'

echo "Restarting ingress-nginx-controller..."
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx

echo "Patching ingress-nginx service to assign LoadBalancer IP: $INGRESS_IP..."
kubectl patch svc ingress-nginx-controller -n ingress-nginx \
  -p "{\"spec\": {\"type\": \"LoadBalancer\", \"loadBalancerIP\": \"$INGRESS_IP\"}}"

echo "Ingress NGINX configured with LoadBalancer IP: $INGRESS_IP and host networking."
echo "----------------------------------------------------"

# --- Final Notes ---
echo "Kubernetes cluster setup completed!"
echo "Access Rancher Web UI at: https://$RANCHER_HOSTNAME"
echo ""
echo "Commands to join other nodes to the cluster:"
echo ""
echo "To join a worker node, run the following command on the worker node:"
echo "  sudo kubeadm join <control-plane-IP>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
echo ""
echo "To get the actual command again:"
echo "  sudo kubeadm token create --print-join-command"
