#!/usr/bin/env bash
set -e

echo "🔍 Checking prerequisites for CI/CD infrastructure..."

REQUIRED_CMDS=(kubectl helm openssl)

for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v $cmd >/dev/null 2>&1; then
    echo "❌ Missing dependency: $cmd"
    exit 1
  fi
done

kubectl cluster-info >/dev/null 2>&1 || {
  echo "❌ kubectl not connected to cluster"
  exit 1
}

echo "✅ All prerequisites satisfied"