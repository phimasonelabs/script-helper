# 🧰 Script Helper

A collection of modular scripts for provisioning Kubernetes clusters on bare-metal or on-prem environments.

---

## 🚀 Quick Start

### ✅ Setup Kubernetes (Single Control Plane Node)

Provision a Kubernetes cluster with a **single control-plane node** — ideal for labs or lightweight deployments.

```bash
curl -fsSL https://raw.githubusercontent.com/phimasonelabs/script-helper/main/scripts/k8s-bare-metal/k8s-single-node-cluster-setup.sh | sudo bash -s -- --iprange 10.88.1.240-10.88.1.245 --hostname pms.example.local --ingressip 10.88.1.241
```

