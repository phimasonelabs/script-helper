# 🧰 Script Helper

A collection of modular scripts for provisioning Kubernetes clusters on bare-metal or on-prem environments.

---

## 🚀 Quick Start

### ✅ Full Setup with MetalLB LoadBalancer

Provision a Kubernetes cluster with **MetalLB** for LoadBalancer services — ideal for production or multi-node clusters.

```bash
curl -fsSL https://raw.githubusercontent.com/phimasonelabs/script-helper/main/scripts/k8s-bare-metal/k8s-single-node-cluster-setup.sh | sudo bash -s -- \
  --iprange 10.88.1.240-10.88.1.245 \
  --hostname pms.example.local \
  --ingressip 10.88.1.241
```

### ✅ Minimal Setup (No MetalLB)

Provision a Kubernetes cluster **without MetalLB** — uses hostNetwork for ingress. Just omit `--iprange`.

```bash
curl -fsSL https://raw.githubusercontent.com/phimasonelabs/script-helper/main/scripts/k8s-bare-metal/k8s-single-node-cluster-setup.sh | sudo bash -s -- \
  --hostname rancher.lab.local
```

### ⚡ Non-Interactive Mode (Zero Touch)

Use the `-y` or `--force` flag to skip all confirmation prompts:

```bash
sudo bash k8s-single-node-cluster-setup.sh --hostname rancher.lab.local -y
```

### 🔥 High Availability (HA) Setup

Provision the **first control plane node** of an HA cluster. Requires an external load balancer (e.g., HAProxy, Nginx, or kube-vip) to be pre-configured.

```bash
sudo bash k8s-single-node-cluster-setup.sh \
  --hostname rancher.example.com \
  --ha \
  --endpoint "loadbalancer.example.com:6443"
```
*Note: The script will output the join commands for other control plane nodes.*

---

## 📋 Options

| Option | Required | Description |
|--------|----------|-------------|
| `--hostname` | **Yes** | Rancher hostname (e.g., `rancher.example.com`) |
| `--iprange` | No | MetalLB IP pool range. If not provided, MetalLB is skipped. |
| `--ingressip` | Conditional | Static IP for Ingress. Required if `--iprange` is set. |
| `--ha` | No | Enable High Availability mode (init first control plane node). |
| `--endpoint` | Conditional | Control Plane Endpoint (host:port). Defaults to `hostname:6443` if not set. |
| `-y`, `--force` | No | Skip all interactive confirmation prompts. |

---

## 📁 What's Included

The script automatically handles the entire lifecycle:

1.  **Node Preparation**:
    *   System updates & essential tools (`conntrack`, `socat`, `ipset`, etc.)
    *   **Containerd** runtime configuration
    *   **Kubeadm**, **kubelet**, **kubectl** installation
    *   Disabling swap & loading kernel modules
2.  **Cluster Bootstrap**:
    *   `kubeadm init`
    *   **Calico CNI** (Pod Networking)
3.  **Storage & Components**:
    *   **Longhorn** (Distributed Block Storage)
    *   **Metrics Server**
    *   **cert-manager**
4.  **Load Balancing** (Optional):
    *   **MetalLB** (Layer 2 mode) if `--iprange` provided
5.  **Rancher Platform**:
    *   **PostgreSQL** database
    *   **Rancher** (v2.10+) via Helm
6.  **Ingress**:
    *   **Nginx Ingress Controller** (hostNetwork mode)

---

## 🧹 Maintenance & Cleanup

### Reset Node (Cleanup)
To completely remove Kubernetes and reset the node to a clean state, run the cleanup script:

```bash
# Interactive mode (asks for confirmation)
curl -fsSL https://raw.githubusercontent.com/phimasonelabs/script-helper/main/scripts/k8s-bare-metal/k8s-node-cleanup.sh | sudo bash

# Force mode (no confirmation, deletes data)
sudo bash k8s-node-cleanup.sh -y
```

**⚠️ Warning:** This removes everything including Longhorn persistent data!

---

## 📝 Logs

All installation and cleanup logs are saved to:
`var/log/k8s-setup/`

*   Setup log: `k8s-setup-YYYYMMDD-HHMMSS.log`
*   Cleanup log: `k8s-cleanup-YYYYMMDD-HHMMSS.log`

