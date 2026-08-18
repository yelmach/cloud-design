#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
RELEASES_URL="https://releases.hashicorp.com/terraform/"

echo "[+] Detecting system..."

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

if [[ "$OS" != "linux" ]]; then
    echo "[-] This script currently supports Linux only."
    exit 1
fi

case "$ARCH" in
    x86_64)
        TF_ARCH="amd64"
        ;;
    aarch64|arm64)
        TF_ARCH="arm64"
        ;;
    armv7l)
        TF_ARCH="arm"
        ;;
    s390x)
        TF_ARCH="s390x"
        ;;
    *)
        echo "[-] Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "[+] Architecture: $TF_ARCH"

echo "[+] Detecting latest Terraform version..."

LATEST_VERSION="$(
    curl -fsSL "$RELEASES_URL" |
    grep -oE 'terraform/[0-9]+\.[0-9]+\.[0-9]+/' |
    sed 's#terraform/##;s#/$##' |
    sort -V |
    tail -n 1
)"

if [[ -z "$LATEST_VERSION" ]]; then
    echo "[-] Could not determine the latest Terraform version."
    exit 1
fi

echo "[+] Latest Terraform version: $LATEST_VERSION"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ZIP_FILE="$TMP_DIR/terraform.zip"

DOWNLOAD_URL="https://releases.hashicorp.com/terraform/${LATEST_VERSION}/terraform_${LATEST_VERSION}_linux_${TF_ARCH}.zip"

echo "[+] Downloading Terraform..."
echo "    $DOWNLOAD_URL"

curl -fL "$DOWNLOAD_URL" -o "$ZIP_FILE"

echo "[+] Creating installation directory..."
mkdir -p "$INSTALL_DIR"

echo "[+] Extracting Terraform..."
unzip -o "$ZIP_FILE" -d "$TMP_DIR"

echo "[+] Installing Terraform..."
mv "$TMP_DIR/terraform" "$INSTALL_DIR/terraform"
chmod +x "$INSTALL_DIR/terraform"

echo "[+] Configuring PATH..."

SHELL_CONFIG=""

case "$(basename "${SHELL:-}")" in
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
echo " Terraform installation successful!"
echo "========================================"
echo
terraform version
