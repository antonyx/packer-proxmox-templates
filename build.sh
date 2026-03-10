#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CREDENTIALS="$SCRIPT_DIR/credentials.pkrvars.hcl"

usage() {
  echo "Usage: $0 <template> [packer-build-args...]"
  echo ""
  echo "Templates:"
  for dir in "$SCRIPT_DIR"/*-amd64; do
    [ -d "$dir" ] && echo "  $(basename "$dir" | sed 's/-amd64$//')"
  done
  echo ""
  echo "Examples:"
  echo "  $0 debian-13"
  echo "  $0 ubuntu-24.04"
  echo "  $0 alpine-3"
  echo "  $0 talos"
  echo ""
  echo "Setup:"
  echo "  cp credentials.example.pkrvars.hcl credentials.pkrvars.hcl"
  echo "  # Edit credentials.pkrvars.hcl with your Proxmox connection details"
  exit 1
}

[ $# -lt 1 ] && usage

TEMPLATE="$1"
shift
TEMPLATE_DIR="$SCRIPT_DIR/${TEMPLATE}-amd64"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Error: template directory not found: $TEMPLATE_DIR"
  usage
fi

# Require credentials file
if [ ! -f "$CREDENTIALS" ]; then
  echo "Error: credentials file not found: $CREDENTIALS"
  echo ""
  echo "  cp credentials.example.pkrvars.hcl credentials.pkrvars.hcl"
  echo "  # Edit with your Proxmox connection details"
  exit 1
fi

# Auto-discover the pkrvars file (expect exactly one)
PKRVARS_FILES=$(find "$TEMPLATE_DIR" -maxdepth 1 -name '*.pkrvars.hcl' | sort)
PKRVARS_COUNT=$(echo "$PKRVARS_FILES" | grep -c .)
if [ "$PKRVARS_COUNT" -eq 0 ]; then
  echo "Error: no .pkrvars.hcl file found in $TEMPLATE_DIR"
  exit 1
elif [ "$PKRVARS_COUNT" -gt 1 ]; then
  echo "Error: multiple .pkrvars.hcl files found in $TEMPLATE_DIR:"
  echo "$PKRVARS_FILES"
  exit 1
fi
PKRVARS="$PKRVARS_FILES"

echo "==> Template:    $TEMPLATE"
echo "==> Directory:   $TEMPLATE_DIR"
echo "==> Var file:    $PKRVARS"
echo "==> Credentials: $CREDENTIALS"

# Run from inside the template directory so relative paths (http/, iso/, templates/) resolve correctly
cd "$TEMPLATE_DIR"

# Init plugins
echo "==> Running packer init..."
packer init .

# Build
echo "==> Running packer build..."
packer build \
  -var-file="$PKRVARS" \
  -var-file="$CREDENTIALS" \
  "$@" \
  .
