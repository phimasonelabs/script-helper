# cloudflared-multi-instance-setup

This repository contains a utility script to create multiple `cloudflared` systemd services on a single host using unique tokens.

## 🔧 Features

- Create multiple `cloudflared` services from a base service
- Automatically set unique tokens per service
- Automatically rename the binary and service
- Designed for advanced multi-tunnel configurations

## 🚀 Quick Usage (without cloning)

You can run the script directly from GitHub using:
https://github.com/14f3v/cloudflared-multi-instance-setup.git
```bash
bash <(curl -s https://raw.githubusercontent.com/phimasonelabs/script-helper/main/scripts/cloudflare/sprint.sh) <service-name> <cloudflare-token>
```

---

#### 🔧 **Optional Additions**
- 🧾 `.gitignore` (if you plan to expand)
- 🙌 `CONTRIBUTING.md` if you want contributions
- 🔖 GitHub topics/tags to improve searchability (`cloudflare`, `tunnel`, `systemd`, `self-hosted`, etc.)

---

Let me know if you'd like help adding those improvements or publishing it to a wider audience 👏
