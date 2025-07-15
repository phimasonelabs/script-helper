#!/bin/bash

# Arguments
SERVICE_NAME="$1"
NEW_TOKEN="$2"

# Paths
SRC_SERVICE="/etc/systemd/system/cloudflared.service"
DEST_SERVICE="/etc/systemd/system/${SERVICE_NAME}.service"

SRC_BINARY="/usr/local/bin/cloudflared"
DEST_BINARY="/usr/local/bin/${SERVICE_NAME}"

# Old token pattern (original token to be replaced - adjust if needed)
TOKEN_REGEX='--token [a-zA-Z0-9._-]*'

# Validate input
if [[ -z "$SERVICE_NAME" || -z "$NEW_TOKEN" ]]; then
  echo "Usage: $0 <new-service-name> <new-token>"
  exit 1
fi

# Check original service file exists
if [[ ! -f "$SRC_SERVICE" ]]; then
  echo "❌ Original service file $SRC_SERVICE not found."
  exit 1
fi

# Copy the service file
cp "$SRC_SERVICE" "$DEST_SERVICE"
echo "✅ Copied service to $DEST_SERVICE"

# Replace token with new one
sed -i "s/${TOKEN_REGEX}/--token ${NEW_TOKEN}/g" "$DEST_SERVICE"
echo "🔄 Replaced token in service file"

# Copy the binary
cp "$SRC_BINARY" "$DEST_BINARY"
chmod +x "$DEST_BINARY"
echo "✅ Copied binary to $DEST_BINARY"

# Reload systemd
systemctl daemon-reload
echo "🔁 Reloaded systemd"

# Done
echo "🎉 New service $SERVICE_NAME is ready. Use:"
echo "  sudo systemctl enable $SERVICE_NAME"
sudo systemctl enable $SERVICE_NAME
echo "  sudo systemctl start $SERVICE_NAME"
sudo systemctl start $SERVICE_NAME
