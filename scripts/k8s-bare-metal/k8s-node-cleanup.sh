#!/bin/bash
set -euo pipefail

# =============================================================================
# K8s Node Cleanup Script
# Resets the node to pre-Kubernetes state
# =============================================================================

LOG_DIR="/var/log/k8s-setup"
LOG_FILE="$LOG_DIR/k8s-cleanup-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "$LOG_DIR"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg" | tee -a "$LOG_FILE"
}

log_step() {
  log "=============================================="
  log "STEP: $1"
  log "=============================================="
}

log_warn() {
  log "⚠️  WARNING: $*"
}

# Check for root
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root or with sudo."
  exit 1
fi

log "=============================================="
log "K8s Node Cleanup - Started"
log "Log file: $LOG_FILE"
log "=============================================="

# Check for force flag
FORCE_MODE=false
for arg in "$@"; do
  case $arg in
    -y|--yes|--force)
      FORCE_MODE=true
      shift
      ;;
  esac
done

if [[ "$FORCE_MODE" == false ]]; then
  echo ""
  echo "⚠️  WARNING: This will completely remove Kubernetes from this node!"
  echo ""
  echo "The following will be removed:"
  echo "  - All Kubernetes pods, services, and configurations"
  echo "  - kubeadm, kubelet, kubectl"
  echo "  - containerd"
  echo "  - Helm"
  echo "  - All K8s-related configurations"
  echo ""
  read -p "Are you sure you want to continue? [y/N]: " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
else
  log "Force mode enabled: Skipping confirmation prompt."
fi

# =============================================================================
# STEP 1: Reset Kubernetes
# =============================================================================
log_step "Reset Kubernetes (kubeadm reset)"

if command -v kubeadm &>/dev/null; then
  log "Running kubeadm reset..."
  kubeadm reset -f 2>&1 | tee -a "$LOG_FILE" || true
else
  log_warn "kubeadm not found, skipping reset"
fi

# Remove kubeconfig
log "Removing kubeconfig directories..."
rm -rf "$HOME/.kube" 2>/dev/null || true
rm -rf /root/.kube 2>/dev/null || true
# Also check for common user home directories
for user_home in /home/*; do
  if [ -d "$user_home/.kube" ]; then
    log "Removing $user_home/.kube"
    rm -rf "$user_home/.kube" 2>/dev/null || true
  fi
done

# =============================================================================
# STEP 2: Stop and disable services
# =============================================================================
log_step "Stop and disable K8s services"

log "Stopping kubelet..."
systemctl stop kubelet 2>/dev/null || true
systemctl disable kubelet 2>/dev/null || true

log "Stopping containerd..."
systemctl stop containerd 2>/dev/null || true
systemctl disable containerd 2>/dev/null || true

# =============================================================================
# STEP 3: Remove Kubernetes packages
# =============================================================================
log_step "Remove Kubernetes packages"

log "Removing kubeadm, kubelet, kubectl..."
apt-get purge -y kubeadm kubelet kubectl kubernetes-cni 2>&1 | tee -a "$LOG_FILE" || true
apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE" || true

# =============================================================================
# STEP 4: Remove containerd
# =============================================================================
log_step "Remove containerd"

log "Removing containerd..."
apt-get purge -y containerd containerd.io 2>&1 | tee -a "$LOG_FILE" || true

# =============================================================================
# STEP 5: Clean up configurations
# =============================================================================
log_step "Clean up configurations"

log "Removing Kubernetes configurations..."
rm -rf /etc/kubernetes 2>/dev/null || true
rm -rf /var/lib/kubelet 2>/dev/null || true
rm -rf /var/lib/etcd 2>/dev/null || true
rm -rf /var/lib/cni 2>/dev/null || true
rm -rf /etc/cni 2>/dev/null || true
rm -rf /opt/cni 2>/dev/null || true

log "Removing containerd configurations..."
rm -rf /etc/containerd 2>/dev/null || true
rm -rf /var/lib/containerd 2>/dev/null || true

log "Removing apt repository configurations..."
rm -f /etc/apt/sources.list.d/kubernetes.list 2>/dev/null || true
rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null || true
rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null || true
rm -f /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null || true

log "Removing sysctl and module configurations..."
rm -f /etc/sysctl.d/k8s.conf 2>/dev/null || true
rm -f /etc/modules-load.d/k8s.conf 2>/dev/null || true

# =============================================================================
# STEP 6: Remove Helm
# =============================================================================
log_step "Remove Helm"

if [ -f /usr/local/bin/helm ]; then
  log "Removing Helm..."
  rm -f /usr/local/bin/helm
else
  log_warn "Helm not found at /usr/local/bin/helm"
fi

# =============================================================================
# STEP 7: Clean up network
# =============================================================================
log_step "Clean up network interfaces"

log "Removing CNI network interfaces..."
ip link delete cni0 2>/dev/null || true
ip link delete flannel.1 2>/dev/null || true
ip link delete docker0 2>/dev/null || true
# Calico interfaces
ip link delete tunl0 2>/dev/null || true
ip link delete vxlan.calico 2>/dev/null || true
for iface in $(ip link show | grep -oP 'cali[a-f0-9]+' | sort -u); do
  ip link delete "$iface" 2>/dev/null || true
done

log "Flushing iptables rules..."
iptables -F 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -X 2>/dev/null || true

# =============================================================================
# STEP 8: Optional - Clean up Longhorn data
# =============================================================================
log_step "Clean up storage (Longhorn)"

if [ -d /var/lib/longhorn ]; then
  if [[ "$FORCE_MODE" == false ]]; then
    read -p "Remove Longhorn storage data? This will DELETE ALL PERSISTENT DATA! [y/N]: " confirm_longhorn
    if [[ "$confirm_longhorn" =~ ^[Yy]$ ]]; then
      log "Removing Longhorn data..."
      rm -rf /var/lib/longhorn
    else
      log_warn "Longhorn data preserved at /var/lib/longhorn"
    fi
  else
    log "Force mode enabled: Removing Longhorn data..."
    rm -rf /var/lib/longhorn
  fi
else
  log "No Longhorn data found"
fi

# =============================================================================
# Final cleanup
# =============================================================================
log_step "Final cleanup"

log "Running apt autoremove..."
apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE" || true

log "Updating apt cache..."
apt-get update 2>&1 | tee -a "$LOG_FILE" || true

log ""
log "=============================================="
log "✅ K8s Node Cleanup Completed!"
log "=============================================="
log ""
log "📋 Cleanup log saved to: $LOG_FILE"
log ""
log "The following have been removed:"
log "  ✓ Kubernetes (kubeadm, kubelet, kubectl)"
log "  ✓ containerd"
log "  ✓ Helm"
log "  ✓ CNI configurations"
log "  ✓ Network interfaces (cni0, flannel.1, calico)"
log "  ✓ iptables rules"
log ""
log "You may want to reboot the node: sudo reboot"
