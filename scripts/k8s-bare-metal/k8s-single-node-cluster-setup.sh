#!/bin/bash
set -euo pipefail

# =============================================================================
# LOGGING SETUP
# =============================================================================
LOG_DIR="/var/log/k8s-setup"
LOG_FILE="$LOG_DIR/k8s-setup-$(date +%Y%m%d-%H%M%S).log"
CURRENT_STEP=""

# Create log directory
mkdir -p "$LOG_DIR"

# Function to log messages with timestamp
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg" | tee -a "$LOG_FILE"
}

# Function to log step start
log_step() {
  CURRENT_STEP="$1"
  log "=============================================="
  log "STEP: $CURRENT_STEP"
  log "=============================================="
}

# Function to log step completion
log_step_done() {
  log "✅ COMPLETED: $CURRENT_STEP"
  log ""
}

# Function to log warnings
log_warn() {
  log "⚠️  WARNING: $*"
}

# Function to log errors
log_error() {
  log "❌ ERROR: $*"
}

# Trap to log on exit/error
trap 'if [ $? -ne 0 ]; then log_error "Script failed at step: $CURRENT_STEP"; log "Check log file: $LOG_FILE"; fi' EXIT

# Start logging
log "=============================================="
log "K8s Single Node Cluster Setup - Started"
log "Log file: $LOG_FILE"
log "=============================================="

# Defaults
METALLB_IP_RANGE=""
RANCHER_HOSTNAME=""
INGRESS_IP=""
FORCE_MODE=false

# Function to detect primary IP address (most reliable method)
# Uses the IP that would be used to reach external destinations
get_primary_ip() {
  ip route get 1 2>/dev/null | awk '{print $(NF-2);exit}'
}

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --iprange <range>      MetalLB IP address pool (e.g., 192.168.1.100-192.168.1.110)"
  echo "                         If not provided, MetalLB is skipped (hostNetwork mode)"
  echo "  --hostname <hostname>  Rancher hostname (e.g., rancher.lab.local) [REQUIRED]"
  echo "  --ingressip <ip>       Static IP for Nginx Ingress LoadBalancer"
  echo "                         Required when --iprange is set, otherwise auto-detected"
  echo "  -y, --yes, --force     Skip confirmation prompts (non-interactive mode)"
  echo "  -h, --help             Show this help message"
  echo ""
  echo "Examples:"
  echo "  # Full setup with MetalLB LoadBalancer:"
  echo "  $0 --iprange 192.168.1.100-192.168.1.110 --hostname rancher.lab.local --ingressip 192.168.1.99"
  echo ""
  echo "  # Minimal setup without MetalLB (auto-detected IP, hostNetwork):"
  echo "  $0 --hostname rancher.lab.local"
  echo ""
  exit 1
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --iprange) METALLB_IP_RANGE="$2"; shift ;;
    --hostname) RANCHER_HOSTNAME="$2"; shift ;;
    --ingressip) INGRESS_IP="$2"; shift ;;
    -y|--yes|--force) FORCE_MODE=true ;;
    -h|--help) usage ;;
    *) echo "Unknown parameter passed: $1"; usage ;;
  esac
  shift
done

# Check if the script is run with sudo privileges (must be first!)
if [[ $EUID -ne 0 ]]; then
  echo ""
  echo "ERROR: This script must be run as root or with sudo."
  echo ""
  echo "Usage:"
  echo "  sudo $0 --hostname rancher.example.com"
  echo "  sudo $0 --hostname rancher.example.com --iprange 10.0.0.100-10.0.0.110 --ingressip 10.0.0.100"
  echo ""
  exit 1
fi

# Auto-detect primary IP
PRIMARY_IP=$(get_primary_ip)
echo "▶ Detected Primary IP: $PRIMARY_IP"

# Validate required parameters
if [[ -z "$RANCHER_HOSTNAME" ]]; then
  echo "Error: --hostname is required."
  usage
fi

# Determine if MetalLB should be enabled (based on whether --iprange is provided)
if [[ -n "$METALLB_IP_RANGE" ]]; then
  ENABLE_METALLB=true
  # When MetalLB is enabled, --ingressip is required
  if [[ -z "$INGRESS_IP" ]]; then
    echo "Error: --ingressip is required when --iprange is set."
    usage
  fi
else
  ENABLE_METALLB=false
  # When MetalLB is skipped, use primary IP for ingress (hostNetwork mode)
  INGRESS_IP="${INGRESS_IP:-$PRIMARY_IP}"
fi

echo "=============================================="
echo "Configuration Summary"
echo "=============================================="
echo "▶ Rancher Hostname: $RANCHER_HOSTNAME"
if [[ "$ENABLE_METALLB" == true ]]; then
  echo "▶ MetalLB IP Range: $METALLB_IP_RANGE"
  echo "▶ Ingress LoadBalancer IP: $INGRESS_IP"
else
  echo "▶ MetalLB: SKIPPED (no --iprange provided)"
  echo "▶ Ingress IP (hostNetwork): $INGRESS_IP"
fi
echo "=============================================="

# =============================================================================
# PHASE 1: NODE PREPARATION (Pre-requisites)
# =============================================================================

log_step "Phase 1: Node Preparation"

# --- Update and Upgrade System ---
log "Updating and upgrading system packages..."
apt-get update 2>&1 | tee -a "$LOG_FILE"
apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE"

# --- Install Essential Tools ---
log "Installing essential tools..."
apt-get install -y \
  vim \
  nfs-common \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  conntrack \
  ebtables \
  socat \
  ipset 2>&1 | tee -a "$LOG_FILE"

# --- Add Kubernetes Repository ---
echo "Adding Kubernetes GPG key and repository..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
chmod 644 /etc/apt/sources.list.d/kubernetes.list

# --- Install Kubernetes Components ---
echo "Installing kubectl, kubelet, kubeadm..."
apt-get update && apt-get install -y kubectl kubelet kubeadm

# --- Add Docker Repository (for containerd) ---
echo "Adding Docker GPG key and repository..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# --- Install and Configure containerd ---
echo "Installing containerd.io..."
apt-get update && apt-get install -y containerd.io

echo "Configuring containerd..."
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Enable SystemdCgroup in containerd config
echo "Enabling SystemdCgroup for containerd..."
sed -i '/^\s*SystemdCgroup\s*=/s/false/true/' /etc/containerd/config.toml

# Enable and restart containerd service
echo "Enabling and restarting containerd service..."
systemctl enable containerd
systemctl restart containerd

# --- Disable Swap ---
echo "Disabling swap..."
# Check if swap is in use
if [ "$(swapon --show 2>/dev/null | wc -l)" -gt 0 ]; then
  # Try to disable swap (may fail in LXC containers)
  if swapoff -a 2>/dev/null; then
    echo "Swap disabled successfully."
  else
    echo "WARNING: Could not disable swap (swapoff failed)."
    echo "         This is normal in LXC containers where swap is managed by the host."
    echo "         Make sure swap is disabled on the Proxmox host or set 'swap: 0' in container config."
  fi
else
  echo "No swap detected, skipping swapoff."
fi

# Remove swap entries from fstab (if any) - this won't fail in LXC
if grep -q swap /etc/fstab 2>/dev/null; then
  sed -i '/swap/d' /etc/fstab
  echo "Removed swap entries from /etc/fstab."
else
  echo "No swap entries in /etc/fstab."
fi

# --- Load Kernel Modules ---
echo "Loading required kernel modules (overlay, br_netfilter)..."

# Write module config (useful for VMs, may not work in LXC)
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Function to check if a kernel module is loaded
module_loaded() {
  lsmod | grep -q "^$1 " || [ -d "/sys/module/$1" ]
}

# Try to load overlay module
if module_loaded overlay; then
  echo "Module 'overlay' is already loaded."
else
  if modprobe overlay 2>/dev/null; then
    echo "Module 'overlay' loaded successfully."
  else
    echo "WARNING: Could not load 'overlay' module (modprobe failed)."
    echo "         In LXC containers, modules must be loaded on the Proxmox HOST."
    echo "         Run on HOST: modprobe overlay"
  fi
fi

# Try to load br_netfilter module
if module_loaded br_netfilter; then
  echo "Module 'br_netfilter' is already loaded."
else
  if modprobe br_netfilter 2>/dev/null; then
    echo "Module 'br_netfilter' loaded successfully."
  else
    echo "WARNING: Could not load 'br_netfilter' module (modprobe failed)."
    echo "         In LXC containers, modules must be loaded on the Proxmox HOST."
    echo "         Run on HOST: modprobe br_netfilter"
  fi
fi

# --- Configure Sysctl Parameters ---
echo "Configuring sysctl parameters for Kubernetes networking..."

# Write sysctl config
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl settings
if sysctl --system 2>/dev/null | grep -q "net.ipv4.ip_forward"; then
  echo "Sysctl parameters applied successfully."
else
  echo "WARNING: sysctl --system may have partially failed."
  echo "         Trying direct write to /proc/sys..."
  # Fallback: directly set values (works in most LXC containers)
  echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true
  if [ -f /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
    echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables 2>/dev/null || true
    echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables 2>/dev/null || true
  fi
  echo "         Direct write attempted. Verify with: sysctl net.ipv4.ip_forward"
fi

# --- Flush iptables Rules ---
echo "Flushing iptables rules..."
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# --- Install Helm ---
echo "Installing Helm..."
ARCH=$(uname -m)
HELM_VERSION="v3.16.3"

case "$ARCH" in
  x86_64)
    HELM_OS="linux"
    HELM_ARCH="amd64"
    ;;
  aarch64)
    HELM_OS="linux"
    HELM_ARCH="arm64"
    ;;
  *)
    echo "Warning: Architecture '$ARCH' not explicitly supported for Helm installation."
    echo "Please install Helm manually: https://helm.sh/docs/intro/install/"
    exit 1
    ;;
esac

HELM_FILENAME="helm-${HELM_VERSION}-${HELM_OS}-${HELM_ARCH}.tar.gz"
HELM_DOWNLOAD_URL="https://get.helm.sh/${HELM_FILENAME}"

echo "Downloading Helm ${HELM_VERSION} for ${HELM_OS} ${HELM_ARCH}..."
cd /tmp
wget "$HELM_DOWNLOAD_URL"

if [ -f "$HELM_FILENAME" ]; then
  echo "Unpacking Helm..."
  tar -zxvf "$HELM_FILENAME"
  HELM_BINARY_PATH="${HELM_OS}-${HELM_ARCH}/helm"

  if [ -f "$HELM_BINARY_PATH" ]; then
    echo "Installing Helm to /usr/local/bin/helm..."
    mv "$HELM_BINARY_PATH" /usr/local/bin/helm
    echo "Helm installed successfully."
  else
    echo "Error: Helm binary not found after unpacking."
    rm -rf "$HELM_FILENAME" "${HELM_OS}-${HELM_ARCH}"
    exit 1
  fi
  rm -rf "$HELM_FILENAME" "${HELM_OS}-${HELM_ARCH}"
else
  echo "Error: Helm download failed."
  exit 1
fi

echo "Verifying Helm installation..."
helm version

echo "=============================================="
echo "PHASE 1 COMPLETE: Node preparation finished!"
echo "=============================================="
if [[ "$FORCE_MODE" == false ]]; then
  read -p "Press Enter to continue with Control Plane setup..."
fi

# =============================================================================
# PHASE 2: CONTROL PLANE SETUP
# =============================================================================

# --- Control Plane Setup ---
log_step "Phase 2: Control Plane Setup"
log "Initializing Kubernetes control plane..."
kubeadm init --pod-network-cidr=10.244.0.0/16

# Setup kubeconfig for root (current user)
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Setup kubeconfig for the user who called sudo
if [[ -n "${SUDO_USER:-}" ]]; then
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  log "Setting up kubeconfig for user: $SUDO_USER ($USER_HOME)..."
  mkdir -p "$USER_HOME/.kube"
  sudo cp /etc/kubernetes/admin.conf "$USER_HOME/.kube/config"
  sudo chown $(id -u "$SUDO_USER"):$(id -g "$SUDO_USER") "$USER_HOME/.kube/config"
  log "Kubeconfig setup for $SUDO_USER assigned."
fi
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

echo "Control plane setup completed. Please label your worker nodes using 'kubectl label nodes --all node-role.kubernetes.io/worker=worker'."
if [[ "$FORCE_MODE" == false ]]; then
  read -p "Press Enter to continue with network setup (Flannel)..."
fi

# --- Deploy Calico Network ---
log_step "Phase 3: Deploy Calico CNI"
log "Deploying Calico CNI network..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml 2>&1 | tee -a "$LOG_FILE"
log "Calico network deployed."
if [[ "$FORCE_MODE" == false ]]; then
  read -p "Press Enter to continue with Longhorn storage setup..."
fi

# --- Setup Longhorn Storage ---
log_step "Phase 4: Setup Longhorn Storage"
log "Installing Longhorn storage..."
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version 1.7.2
echo "Longhorn storage deployed."
if [[ "$FORCE_MODE" == false ]]; then
  read -p "Press Enter to continue with Metrics Server setup..."
fi

# --- Setup Metrics Server ---
log_step "Phase 5: Setup Metrics Server"
log "Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[{
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }]'
echo "Metrics Server deployed."
if [[ "$FORCE_MODE" == false ]]; then
  read -p "Press Enter to continue with cert-manager installation..."
fi

# --- Install cert-manager ---
log_step "Phase 6: Install cert-manager"
log "Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io
helm repo update
kubectl apply --validate=false -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.3/cert-manager.crds.yaml
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.12.3
echo "cert-manager installed."

# --- Deploy MetalLB Load-Balancer (Conditional) ---
if [[ "$ENABLE_METALLB" == true ]]; then
  log_step "Phase 7: Deploy MetalLB Load-Balancer"
  if [[ "$FORCE_MODE" == false ]]; then
    read -p "Press Enter to continue with MetalLB load-balancer deployment..."
  fi
  
  log "Deploying MetalLB load-balancer..."
  kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml 2>&1 | tee -a "$LOG_FILE"
  
  # Wait for MetalLB controller to be ready
  echo "Waiting for MetalLB controller to be ready..."
  kubectl wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=120s || true
  sleep 10
  
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
else
  echo "Skipping MetalLB installation (--skip-metallb flag set)"
fi

if [[ "$FORCE_MODE" == false ]]; then
  read -p "Press Enter to continue with PostgreSQL deployment for Rancher..."
fi

# --- Deploy PostgreSQL for Rancher Web UI ---
log_step "Phase 8: Deploy PostgreSQL for Rancher"
log "Installing PostgreSQL..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

if [[ "$ENABLE_METALLB" == true ]]; then
  # With MetalLB: Use LoadBalancer service type
  helm install postgresql bitnami/postgresql \
    --namespace postgresql --create-namespace \
    --set auth.username=rancher \
    --set auth.password=rancher#2025 \
    --set auth.database=rancherdb \
    --set primary.persistence.storageClass=longhorn \
    --set primary.persistence.size=10Gi \
    --set service.type=LoadBalancer
else
  # Without MetalLB: Use ClusterIP (internal access only)
  helm install postgresql bitnami/postgresql \
    --namespace postgresql --create-namespace \
    --set auth.username=rancher \
    --set auth.password=rancher#2025 \
    --set auth.database=rancherdb \
    --set primary.persistence.storageClass=longhorn \
    --set primary.persistence.size=10Gi \
    --set service.type=ClusterIP
fi
echo "PostgreSQL for Rancher deployed."
if [[ "$FORCE_MODE" == false ]]; then
  read -p "Press Enter to continue with Rancher web UI setup..."
fi

# --- Setup Rancher Web UI ---
log_step "Phase 9: Setup Rancher Web UI"
log "Installing Rancher..."
kubectl create namespace cattle-system || true

kubectl create secret docker-registry rancher-registry-secret \
  --docker-server=docker.io \
  --docker-username=' ' \
  --docker-password=' ' \
  --docker-email=' ' \
  --namespace=cattle-system || true

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update

helm install rancher rancher-latest/rancher \
  --namespace cattle-system --create-namespace \
  --set hostname="$RANCHER_HOSTNAME" \
  --set replicas=1 \
  --set global.cattle.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].key=kubernetes.io/hostname \
  --set global.cattle.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].operator=Exists \
  --set global.database.external.host=postgresql.postgresql.svc.cluster.local \
  --set global.database.external.port=5432 \
  --set global.database.external.username=rancher \
  --set global.database.external.password='rancher#2025' \
  --set global.database.external.database=rancherdb \
  --set global.imagePullSecrets=rancher-registry-secret
echo "Rancher Web UI deployment initiated with hostname: $RANCHER_HOSTNAME."
if [[ "$FORCE_MODE" == false ]]; then
  read -p "Press Enter to continue with Nginx Ingress Controller installation..."
fi

# --- Install Nginx Ingress Controller ---
log_step "Phase 10: Install Nginx Ingress Controller"
log "Installing Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml 2>&1 | tee -a "$LOG_FILE"

log "Waiting for ingress-nginx-controller deployment to be ready..."
while true; do
  READY=$(kubectl get deployment ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  DESIRED=$(kubectl get deployment ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
  
  if [[ "$READY" == "$DESIRED" ]] && [[ "$READY" != "0" ]] && [[ -n "$READY" ]]; then
    log "✅ ingress-nginx-controller is ready ($READY/$DESIRED replicas)"
    break
  fi
  
  log "⏳ Waiting for ingress-nginx-controller... ($READY/$DESIRED replicas ready)"
  sleep 10
done

echo "Patching ingress-nginx-controller to use hostNetwork and proper dnsPolicy..."
kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
  --type='json' \
  -p='[
    {"op": "add", "path": "/spec/template/spec/hostNetwork", "value": true},
    {"op": "replace", "path": "/spec/template/spec/dnsPolicy", "value": "ClusterFirstWithHostNet"}
  ]'

echo "Restarting ingress-nginx-controller..."
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx

if [[ "$ENABLE_METALLB" == true ]]; then
  echo "Patching ingress-nginx service to assign LoadBalancer IP: $INGRESS_IP..."
  kubectl patch svc ingress-nginx-controller -n ingress-nginx \
    -p "{\"spec\": {\"type\": \"LoadBalancer\", \"loadBalancerIP\": \"$INGRESS_IP\"}}"
  echo "Ingress NGINX configured with LoadBalancer IP: $INGRESS_IP and host networking."
else
  echo "Ingress NGINX configured with hostNetwork mode (accessible via node IP: $INGRESS_IP)."
fi
echo "----------------------------------------------------"

# --- Final Notes ---
log_step "Setup Complete"

log ""
log "=============================================="
log "✅ Kubernetes cluster setup completed!"
log "=============================================="
log ""
log "📋 Log file: $LOG_FILE"
log ""
log "🌐 Access Rancher Web UI at: https://$RANCHER_HOSTNAME"
log ""
if [[ "$ENABLE_METALLB" == false ]]; then
  log "NOTE: MetalLB was skipped. Services use hostNetwork/ClusterIP."
  log "      Make sure DNS or /etc/hosts points $RANCHER_HOSTNAME to $INGRESS_IP"
fi
log ""
log "Commands to join other nodes to the cluster:"
log ""
log "To join a worker node, run the following command on the worker node:"
log "  sudo kubeadm join $PRIMARY_IP:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
log ""
log "To get the actual join command:"
log "  sudo kubeadm token create --print-join-command"
log ""
log "📋 Full installation log saved to: $LOG_FILE"
