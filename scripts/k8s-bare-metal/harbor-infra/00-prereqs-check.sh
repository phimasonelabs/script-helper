#!/usr/bin/env bash
set -e

for cmd in kubectl helm openssl; do
  if ! command -v $cmd >/dev/null; then
    echo "❌ Missing dependency: $cmd"
    exit 1
  fi
done

echo "✅ All required tools are installed"