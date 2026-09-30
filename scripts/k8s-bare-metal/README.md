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
### 🤝 Joining an Existing Cluster

Use the script to prepare a blank node and join it to the cluster (as Worker or HA Control Plane). The script handles all node preparation (packages, kernel modules, systcl) automatically before joining.

**Option A: Using the Script (Recommended for fresh nodes)**
The script handles all node preparation (packages, kernel modules, sysctl) before joining.

worker:
```bash
sudo bash k8s-single-node-cluster-setup.sh \
  --join 192.168.1.100:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

control-plane (HA):
```bash
sudo bash k8s-single-node-cluster-setup.sh \
  --join loadbalancer.example.com:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <key>
```

**Option B: Using Native `kubeadm` (Manual)**
If your node is already prepared (container runtime installed, swap off, etc.), you can run the join command directly:

worker:
```bash
sudo kubeadm join 192.168.1.100:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

control-plane (HA):
```bash
sudo kubeadm join loadbalancer.example.com:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane --certificate-key <key>
```

---

## 📋 Options

| Option | Required | Description |
|--------|----------|-------------|
| `--hostname` | **Yes** (Init) | Rancher hostname (e.g., `rancher.example.com`) |
| `--iprange` | No | MetalLB IP pool range. If not provided, MetalLB is skipped. |
| `--ingressip` | Conditional | Static IP for Ingress. Required if `--iprange` is set. |
| `--ha` | No | Enable High Availability mode (init first control plane node). |
| `--endpoint` | Conditional | Control Plane Endpoint (host:port). Defaults to `hostname:6443` if not set. |
| `--join` | No | Join an existing cluster. Provide endpoint `host:port`. |
| `--token` | Yes (Join) | Token for joining the cluster. |
| `--discovery...` | Yes (Join) | Discovery token CA cert hash. |
| `--control-plane`| No | Join as a Control Plane node. |
| `--certificate-key`| Yes (CP Join)| Certificate key for joining as Control Plane. |
| `--ntp-servers` | Recommended | Comma-separated NTP server(s) reachable from the node, e.g. `10.0.0.13`. See [Time sync](#-time-sync-ntp). |
| `-y`, `--force` | No | Skip all interactive confirmation prompts. |

### 🕒 Time sync (NTP)

Kubernetes needs node clocks within about a second of each other: TLS certificate validity,
ServiceAccount token `nbf`/`exp`, leader-election leases and CronJob timing all compare timestamps
across nodes. Ubuntu's default time server (`ntp.ubuntu.com`) is **unreachable wherever outbound
UDP/123 is blocked**, and the clock then never syncs; nodes drift silently (minutes apart after a
few months).

- `--ntp-servers 10.0.0.13[,10.0.0.14]` points the node's time daemon at reachable servers
  (a drop-in for `systemd-timesyncd`, or `sources.d` if `chrony` is active), then waits up to 60s
  for sync.
- This step runs on **every** invocation, outside the phase checkpoints. Re-running the provisioner
  on an already-built node with `--ntp-servers` applies it without redoing anything else.
- Without the flag, the script **warns** if the clock is not synchronized. It never aborts a build over time sync.
- `k8s-installation.sh` takes the same setting as an environment variable:
  `NTP_SERVERS="10.0.0.13" bash k8s-installation.sh`.
- Check a node: `timedatectl timesync-status` (look for your server and a small offset).

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

