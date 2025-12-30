#!/usr/bin/env bash
set -euo pipefail

DOMAIN="$1"
OUTDIR="./harbor-cert"

if [[ -z "${DOMAIN:-}" ]]; then
  echo "Usage: $0 <harbor-domain>"
  echo "Example: $0 mjcr.vte.mjblao.local"
  exit 1
fi

echo "🔍 Checking required tools..."
for bin in openssl; do
  if ! command -v $bin >/dev/null; then
    echo "⚠️  Missing $bin"
    read -p "Install missing dependencies? [Y/n]: " yn
    [[ "$yn" =~ ^[Nn]$ ]] && exit 1
    sudo apt update && sudo apt install -y openssl
    break
  fi
done

mkdir -p "$OUTDIR"

echo "🔐 Generating Harbor Root CA"
openssl genrsa -out "$OUTDIR/ca.key" 4096
openssl req -x509 -new -nodes \
  -key "$OUTDIR/ca.key" \
  -sha256 -days 3650 \
  -out "$OUTDIR/ca.crt" \
  -subj "/C=LA/ST=Vientiane/O=MJBL/CN=Harbor-Root-CA"

cat > "$OUTDIR/openssl.cnf" <<EOF
[req]
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
CN = $DOMAIN

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$(echo "$DOMAIN" | cut -d. -f2-)
EOF

openssl genrsa -out "$OUTDIR/tls.key" 4096
openssl req -new -key "$OUTDIR/tls.key" \
  -out "$OUTDIR/tls.csr" \
  -config "$OUTDIR/openssl.cnf"

openssl x509 -req \
  -in "$OUTDIR/tls.csr" \
  -CA "$OUTDIR/ca.crt" \
  -CAkey "$OUTDIR/ca.key" \
  -CAcreateserial \
  -out "$OUTDIR/tls.crt" \
  -days 3650 \
  -sha256 \
  -extensions req_ext \
  -extfile "$OUTDIR/openssl.cnf"

echo "✅ Harbor CA + TLS generated for $DOMAIN"