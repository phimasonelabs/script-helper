# claude-switch

Toggle the **Claude Code** CLI between **Anthropic Cloud** and **Huawei MaaS (GLM)** — with one script and two friendly commands.

Huawei ModelArts Studio (MaaS) exposes a native **Anthropic-compatible** endpoint, so no proxy or router is needed: `claude-huawei` just points Claude Code at MaaS with the right model, and `claude-cloud` runs your normal Anthropic session.

## 🔧 Features

- `claude-cloud` — Claude Code on Anthropic (your claude.ai login/subscription)
- `claude-huawei` — Claude Code on Huawei MaaS GLM (default model `glm-5.2`)
- Per-process env isolation — switching never leaks into your shell, and cloud mode force-clears overrides
- Preflight reachability check that refuses to launch a broken session
- One-place config in `~/.huawei-maas`; per-run overrides via `CLAUDE_HUAWEI_*` env vars
- Secret stays in `~/.huawei-maas` (chmod 600) — never on a command line

## 📦 Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and on your `PATH` (`claude --version`)
- `curl` and `python3` (for the preflight/`models` helpers)
- A Huawei Cloud **MaaS** API key

## 🚀 Install

From the repo root (installs `claude-switch` + the `claude-cloud` / `claude-huawei` symlinks into your bin dir):

```bash
./install.sh claude-switch
# or:  make install TOOL=claude-switch
# custom location:  ./install.sh claude-switch --bindir /usr/local/bin
```

## 🔑 Set up your API key

The key lives in `~/.huawei-maas` (chmod 600, never committed). Pick one:

**Automated (recommended)** — `claude-switch setup` writes the file for you:

```bash
# interactive: prompts for the key (hidden input)
claude-switch setup --model glm-5.2

# non-interactive: key from an env var (keeps it out of shell history & `ps`)
HUAWEI_MAAS_TOKEN='UUIy55...' claude-switch setup --model glm-5.2 --verify

# or from a file / stdin
claude-switch setup --token-file ./my-key.txt --model glm-5.2
printf '%s' "$KEY" | claude-switch setup --token-stdin
```

**One command — install *and* configure** (installer `--setup` pass-through):

```bash
HUAWEI_MAAS_TOKEN='UUIy55...' ./install.sh claude-switch --setup --model glm-5.2
```

**Manual** — copy the template and edit it:

```bash
cp scripts/claude-switch/huawei-maas.example ~/.huawei-maas
chmod 600 ~/.huawei-maas
# put your MaaS API key on the first non-comment line
```

> ⚠️ `--token '<KEY>'` works too, but the key then appears in your shell history and `ps`.
> Prefer the interactive prompt, `$HUAWEI_MAAS_TOKEN`, `--token-file`, or `--token-stdin`.
> `setup` merges into an existing file, so `claude-switch setup --model glm-5.1` keeps your key.

## 🧭 Usage

| Command | Backend |
| :--- | :--- |
| `claude-cloud [claude args…]` | Anthropic Claude (your login/subscription) |
| `claude-huawei [claude args…]` | Huawei MaaS GLM (default `glm-5.2`) |
| `claude-switch cloud \| huawei [args…]` | Same as above (aliases: `glm`, `maas`) |
| `claude-switch setup [opts]` | Create/update `~/.huawei-maas` (automates API-key handling) |
| `claude-switch check` | Probe endpoint + model, **no** Claude launch |
| `claude-switch models` | List models your key can see (catalog) |
| `claude-switch help` | Usage |

Any arguments after the command pass straight through to `claude` (`-p`, `-c`, `--resume`, …):

```bash
claude-huawei                                # interactive GLM session
claude-cloud  --resume                       # back to Anthropic
claude-huawei -p "refactor this function"    # headless one-shot
claude-switch check                          # "✓ reachable" before relying on it
```

## 🎚 Choosing the model

- **Persistent default** — a `model=` line in `~/.huawei-maas` (e.g. `model=glm-5.2`).
- **One-off override** — `CLAUDE_HUAWEI_MODEL=glm-5.1 claude-huawei` (doesn't change the default).

## ⚙️ Config & environment

| Setting | Default | Override |
| :--- | :--- | :--- |
| Key file | `~/.huawei-maas` | `CLAUDE_HUAWEI_KEYFILE` |
| Model | `glm-5.2` | `CLAUDE_HUAWEI_MODEL` |
| Region | `ap-southeast-1` | `CLAUDE_HUAWEI_REGION` |
| Base URL | `https://api-<region>.modelarts-maas.com/anthropic` | `CLAUDE_HUAWEI_BASE_URL` |
| Preflight | on | `CLAUDE_HUAWEI_NO_CHECK=1` to skip |

The key file accepts a bare key line plus optional `model=` / `region=` / `base_url=` lines.

## 📝 Notes

- A model can be **listed** (`claude-switch models`) yet not **callable** — Huawei MaaS gates inference per model. If a model returns **HTTP 403 `ModelArts.81004` "no access"**, subscribe/activate that model's real-time inference service in the MaaS console (region `ap-southeast-1`), then re-run `claude-switch check`.
- In Huawei mode you'll see a benign notice that **claude.ai connectors are disabled** — expected, because the API token takes precedence over your claude.ai login while using a third-party endpoint.
- Each command launches a **new** `claude` process; you switch backends by starting a fresh session.

## ❌ Uninstall

```bash
./install.sh --uninstall claude-switch
# or:  make uninstall TOOL=claude-switch
```
(Leaves your `~/.huawei-maas` untouched.)
