#!/bin/bash

# Update and upgrade packages
sudo apt-get update && sudo apt-get upgrade -y

# Install essential tools
sudo apt-get install -y vim nfs-common apt-transport-https ca-certificates curl gnupg

# Add Kubernetes repository key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository source
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list

# Update package list and install kubelet, kubeadm, and kubectl
sudo apt-get update && sudo apt-get install -y kubectl kubelet kubeadm

# Add Docker repository key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository source
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package list and install containerd
sudo apt-get update && sudo apt install -y containerd.io

# Configure containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Enable systemd cgroup for containerd
sudo sed -i '/^\s*SystemdCgroup\s*=/s/false/true/' /etc/containerd/config.toml

# Enable and restart containerd service
sudo systemctl enable containerd
sudo systemctl restart containerd

# Disable swap
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# Load kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Flush iptables rules
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X

echo "Kubernetes installation preparation completed."
echo "----------------------------------------------------"
echo "Starting Helm installation..."

# Determine architecture for Helm installation
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
    echo "Warning: Architecture '$ARCH' not explicitly supported for Helm installation in this script."
    echo "Please refer to the official Helm documentation for installation instructions:"
    echo "https://helm.sh/docs/intro/install/"
    exit 1
    ;;
esac

HELM_FILENAME="helm-${HELM_VERSION}-${HELM_OS}-${HELM_ARCH}.tar.gz"
HELM_DOWNLOAD_URL="https://get.helm.sh/${HELM_FILENAME}"

echo "Downloading Helm ${HELM_VERSION} for ${HELM_OS} ${HELM_ARCH}..."
wget "$HELM_DOWNLOAD_URL"

if [ -f "$HELM_FILENAME" ]; then
  echo "Unpacking Helm..."
  tar -zxvf "$HELM_FILENAME"
  HELM_BINARY_PATH="${HELM_OS}-${HELM_ARCH}/helm"

  if [ -f "$HELM_BINARY_PATH" ]; then
    echo "Installing Helm to /usr/local/bin/helm..."
    sudo mv "$HELM_BINARY_PATH" /usr/local/bin/helm
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

echo "Helm installation completed."
