# Kubernetes Cluster Setup (Modular + HA Ready)

This repository provides modular scripts for setting up a **Highly Available (HA)** Kubernetes cluster on **bare-metal** or **VMs** using `kubeadm`, `Flannel`, `Longhorn`, `Rancher`, `MetalLB`, and `Ingress-NGINX`.

---

## 🧭 Getting Started

### Prerequisites

- 3 or more Linux nodes (Ubuntu recommended)
- Passwordless `sudo` access on all nodes
- Helm installed
- Container runtime (containerd or Docker)
- External Load Balancer IP (e.g. `10.0.0.100`) for control plane HA
- DNS entry or `/etc/hosts` entry for Rancher hostname

---

## 🛠 Script Overview

| Script File | Purpose |
|-------------|---------|
| `00-bootstrap-control-plane.sh` | Initializes the first Kubernetes control-plane node |
| `01-join-control-plane.sh`      | Used on additional control-plane nodes |
| `02-install-network.sh`         | Installs Flannel CNI |
| `03-install-storage-longhorn.sh`| Deploys Longhorn for persistent storage |
| `04-install-metrics-server.sh`  | Deploys Metrics Server with TLS skip |
| `05-install-cert-manager.sh`    | Installs cert-manager |
| `06-install-metallb.sh`         | Installs and configures MetalLB |
| `07-install-postgresql.sh`      | Installs PostgreSQL backend for Rancher |
| `08-install-rancher.sh`         | Deploys Rancher using Helm |
| `09-install-ingress-nginx.sh`   | Installs Ingress-NGINX with `hostNetwork: true` |

---

## 🚀 How to Use

### Step 1: Initialize First Control Plane
```bash
sudo ./00-bootstrap-control-plane.sh
```

> This script generates `join-worker.sh` and `join-control-plane.sh` for you.

### Step 2: Join Other Nodes
- Run `join-control-plane.sh` on other control plane nodes.
- Run `join-worker.sh` on all worker nodes.

### Step 3: Run Component Installers
```bash
sudo ./02-install-network.sh
sudo ./03-install-storage-longhorn.sh
...
sudo ./09-install-ingress-nginx.sh
```

---

## 🌐 Rancher Access

After successful setup, Rancher will be accessible at:

```
https://<your-rancher-hostname>
```

Make sure DNS or `/etc/hosts` points to the IP you used in MetalLB + Ingress.

---

## 🧼 Cleanup

To reset your Kubernetes node:

```bash
kubeadm reset -f
rm -rf ~/.kube
```

---

## 📄 License

MIT — Feel free to modify and use!
