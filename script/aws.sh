#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/aws-cli"
BIN_DIR="$HOME/.local/bin"

echo "[+] Detecting system..."

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

if [[ "$OS" != "linux" ]]; then
    echo "[-] This script supports Linux only."
    exit 1
fi

case "$ARCH" in
    x86_64)
        AWS_ARCH="x86_64"
        ;;
    aarch64|arm64)
        AWS_ARCH="aarch64"
        ;;
    *)
        echo "[-] Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "[+] Architecture: $AWS_ARCH"

mkdir -p "$BIN_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

AWS_ZIP="$TMP_DIR/awscliv2.zip"

echo "[+] Downloading AWS CLI v2..."

curl -fL \
    "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" \
    -o "$AWS_ZIP"

echo "[+] Extracting AWS CLI..."

unzip -q "$AWS_ZIP" -d "$TMP_DIR"

echo "[+] Installing AWS CLI into:"
echo "    $INSTALL_DIR"

# Remove previous installation if it exists
rm -rf "$INSTALL_DIR"

"$TMP_DIR/aws/install" \
    --install-dir "$INSTALL_DIR" \
    --bin-dir "$BIN_DIR" \
    --update

echo "[+] Configuring PATH..."

SHELL_NAME="$(basename "${SHELL:-}")"

case "$SHELL_NAME" in
    bash)
        SHELL_CONFIG="$HOME/.bashrc"
        ;;
    zsh)
        SHELL_CONFIG="$HOME/.zshrc"
        ;;
    *)
        SHELL_CONFIG="$HOME/.profile"
        ;;
esac

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

if ! grep -Fxq "$PATH_LINE" "$SHELL_CONFIG" 2>/dev/null; then
    echo "$PATH_LINE" >> "$SHELL_CONFIG"
fi

export PATH="$HOME/.local/bin:$PATH"

echo
echo "========================================"
echo " AWS CLI installation successful!"
echo "========================================"
echo

aws --version
