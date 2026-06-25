# Script-helper


## [🧰 Script Helper for HA Kubernetes Cluster](scripts/k8s-bare-metal)
![CI](https://github.com/phimasonelabs/script-helper/actions/workflows/ci.yml/badge.svg)
![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)
![Shell Script](https://img.shields.io/badge/script-bash-blue)
![Platform](https://img.shields.io/badge/platform-bare--metal%20%7C%20on--prem-green)

> A collection of modular scripts and automations for various infrastructure needs.

## 📂 Available Modules

| Module | Description |
| :--- | :--- |
| **[K8s Bare Metal](scripts/k8s-bare-metal)** | Scripts to bootstrap HA Kubernetes clusters on bare-metal/VMs (Rancher, Calico, Longhorn). |
| **[Cloudflare](scripts/cloudflare)** | Automations for Cloudflare Worker & Pages deployment and management. |
| **[Claude Switch](scripts/claude-switch)** | Toggle the Claude Code CLI between Anthropic Cloud and Huawei MaaS (GLM) models. |

---

## 🛠 Installation

Some modules ship runnable CLI tools (any `scripts/<module>/bin/`). Install them into your bin directory with the bundled installer:

```bash
git clone https://github.com/phimasonelabs/script-helper.git
cd script-helper

./install.sh --list                   # list installable tools
./install.sh                          # install all tools into ~/.local/bin
./install.sh claude-switch            # install a single tool
./install.sh --bindir /usr/local/bin  # custom location
./install.sh --uninstall claude-switch

# install + configure a tool in one go (tool-specific --setup pass-through):
HUAWEI_MAAS_TOKEN=... ./install.sh claude-switch --setup --model glm-5.2
```

`make install` / `make list` / `make uninstall` wrap the same script. Use `--link` (dev mode) to symlink tools to the repo so `git pull` updates them in place.

---

## 🎯 Goal
This repository serves as a centralized "Swiss Army Knife" for DevOps and Platform Engineering tasks, providing production-ready scripts that can be curled or cloned directly into environments.

## 🤝 Community
If you found this helpful or you're facing similar infrastructure challenges, feel free to fork, star ⭐️, or contribute!
If you found this helpful or you're facing similar infrastructure challenges, feel free to fork, star ⭐️, or contribute!

Maintained by [Phimasonelabs](https://github.com/phimasonelabs)
