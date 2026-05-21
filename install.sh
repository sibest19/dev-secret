#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="dev-secret"
SCRIPT_DOWNLOAD_URL="${DEV_SECRET_INSTALL_URL:-https://raw.githubusercontent.com/sibest19/dev-secret/main/bin/dev-secret}"
INSTALL_DIR="${DEV_SECRET_INSTALL_DIR:-$HOME/.local/bin}"
TARGET="$INSTALL_DIR/$SCRIPT_NAME"

say() { printf '%s\n' "$*"; }
die() {
	printf 'Error: %s\n' "$*" >&2
	exit 1
}

[[ "${OSTYPE:-}" == darwin* ]] || die "$SCRIPT_NAME requires macOS."
command -v curl >/dev/null 2>&1 || die "curl not found."
command -v bash >/dev/null 2>&1 || die "bash not found."
command -v security >/dev/null 2>&1 || die "macOS security command not found."

mkdir -p "$INSTALL_DIR"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

say "Downloading $SCRIPT_DOWNLOAD_URL"
curl -fsSL "$SCRIPT_DOWNLOAD_URL" -o "$tmp"
bash -n "$tmp"
chmod +x "$tmp"
mv "$tmp" "$TARGET"
trap - EXIT

say "Installed $SCRIPT_NAME to $TARGET"

case ":$PATH:" in
*":$INSTALL_DIR:"*) ;;
*)
	say "Note: $INSTALL_DIR is not in PATH. Add this to your shell config:"
	say "  export PATH=\"$INSTALL_DIR:\$PATH\""
	;;
esac

"$TARGET" doctor || true
say "Run: $SCRIPT_NAME init"
