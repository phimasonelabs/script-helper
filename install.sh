#!/usr/bin/env bash
# install.sh — install script-helper CLI tools into your bin directory.
#
# A "tool" is any directory under scripts/ that contains a bin/ subdirectory.
# Every executable in scripts/<tool>/bin/ is installed into the bin dir, and any
# symlinks declared in scripts/<tool>/links.txt are (re)created alongside it.
#
# Usage:
#   ./install.sh [options] [tool ...]
#
# Options:
#   --bindir DIR   install into DIR     (default: $XDG_BIN_HOME or ~/.local/bin)
#   --copy         copy tools into bindir   (default; survives repo move/delete)
#   --link         symlink tools to this repo (dev mode; updates on git pull)
#   --uninstall    remove the selected tools' files from bindir
#   --list         list installable tools and exit
#   -h, --help     show this help
#
# Examples:
#   ./install.sh                          # install all tools into ~/.local/bin
#   ./install.sh claude-switch            # install just one tool
#   ./install.sh --link                   # dev mode (symlink into the repo)
#   ./install.sh --bindir /usr/local/bin  # custom location
#   ./install.sh --uninstall claude-switch
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"
BINDIR="${BINDIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}"
MODE="copy"
ACTION="install"

_tty() { [ -t 1 ]; }
col()  { _tty && printf '\033[%sm' "$1" || true; }
info() { col 36; printf '%s\n' "$*"; col 0; }
ok()   { col 32; printf '%s\n' "$*"; col 0; }
warn() { col 33; printf '%s\n' "$*"; col 0; }
die()  { col 31; printf '%s\n' "$*" >&2; col 0; exit 1; }

usage() {
  cat <<'USAGE'
install.sh — install script-helper CLI tools into your bin directory.

Usage: ./install.sh [options] [tool ...]

  --bindir DIR   install into DIR     (default: $XDG_BIN_HOME or ~/.local/bin)
  --copy         copy into bindir     (default; survives repo move/delete)
  --link         symlink to this repo (dev mode; updates on git pull)
  --uninstall    remove the selected tools' files from bindir
  --list         list installable tools and exit
  -h, --help     show this help

Examples:
  ./install.sh                          install all tools into ~/.local/bin
  ./install.sh claude-switch            install just one tool
  ./install.sh --link                   dev mode (symlink into the repo)
  ./install.sh --bindir /usr/local/bin  custom location
  ./install.sh --uninstall claude-switch
USAGE
}

TOOLS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --bindir)   BINDIR="${2:?--bindir needs a directory}"; shift 2 ;;
    --bindir=*) BINDIR="${1#*=}"; shift ;;
    --copy)     MODE="copy"; shift ;;
    --link|--symlink) MODE="link"; shift ;;
    --uninstall|--remove) ACTION="uninstall"; shift ;;
    --list|-l)  ACTION="list"; shift ;;
    -h|--help)  usage; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do TOOLS+=("$1"); shift; done ;;
    -*) die "unknown option: $1 (try --help)" ;;
    *)  TOOLS+=("$1"); shift ;;
  esac
done

# All installable tools = scripts/*/ dirs that contain a bin/ subdir.
discover() {
  local d
  for d in "$SCRIPTS_DIR"/*/; do
    [ -d "${d}bin" ] || continue
    basename "$d"
  done
}

# Selected = explicit args, else everything discovered.
if [ "${#TOOLS[@]}" -gt 0 ]; then
  SELECTED="$(printf '%s\n' "${TOOLS[@]}")"
else
  SELECTED="$(discover)"
fi
[ -n "$SELECTED" ] || die "No installable tools found under $SCRIPTS_DIR"

# --- list ---------------------------------------------------------------------
if [ "$ACTION" = "list" ]; then
  info "Installable tools (bindir: $BINDIR):"
  for t in $(discover); do
    printf '  %s\n' "$t"
    for e in "$SCRIPTS_DIR/$t/bin/"*; do
      [ -f "$e" ] && printf '      bin : %s\n' "$(basename "$e")"
    done
    if [ -f "$SCRIPTS_DIR/$t/links.txt" ]; then
      while read -r l tgt _; do
        case "$l" in ''|\#*) continue ;; esac
        printf '      link: %s -> %s\n' "$l" "$tgt"
      done < "$SCRIPTS_DIR/$t/links.txt"
    fi
  done
  exit 0
fi

# --- install / uninstall ------------------------------------------------------
[ "$ACTION" = "install" ] && mkdir -p "$BINDIR"

for t in $SELECTED; do
  tdir="$SCRIPTS_DIR/$t"
  [ -d "$tdir/bin" ] || die "no such tool: '$t' (try: ./install.sh --list)"

  for e in "$tdir/bin/"*; do
    [ -f "$e" ] || continue
    name="$(basename "$e")"; dest="$BINDIR/$name"
    if [ "$ACTION" = "uninstall" ]; then
      rm -f "$dest" && info "removed  $dest"
    elif [ "$MODE" = "link" ]; then
      ln -sfn "$e" "$dest"; ok "linked   $name -> $dest"
    else
      cp "$e" "$dest"; chmod 755 "$dest"; ok "installed $name -> $dest"
    fi
  done

  if [ -f "$tdir/links.txt" ]; then
    while read -r l tgt _; do
      case "$l" in ''|\#*) continue ;; esac
      [ -n "${tgt:-}" ] || continue
      if [ "$ACTION" = "uninstall" ]; then
        rm -f "$BINDIR/$l" && info "removed  $BINDIR/$l"
      else
        ln -sfn "$tgt" "$BINDIR/$l"; ok "linked   $l -> $tgt"
      fi
    done < "$tdir/links.txt"
  fi
done

if [ "$ACTION" = "install" ]; then
  case ":$PATH:" in
    *":$BINDIR:"*) ok "Done. '$BINDIR' is on your PATH." ;;
    *) warn "Done — but '$BINDIR' is NOT on your PATH."
       warn "  Add this to your ~/.zshrc (or ~/.bashrc):"
       warn "    export PATH=\"$BINDIR:\$PATH\"" ;;
  esac
else
  ok "Uninstall complete."
fi
