#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="dev-secret"
SCRIPT_DOWNLOAD_URL="https://raw.githubusercontent.com/sibest19/dev-secret/main/bin/dev-secret"
# Update this hash whenever bin/dev-secret changes: shasum -a 256 bin/dev-secret
EXPECTED_SHA256="cd6a75bea75189a8e7c8b447341ac5add8e039a6b971856cdad7432ff8cdb9c0"
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
command -v shasum >/dev/null 2>&1 || die "shasum not found."
command -v security >/dev/null 2>&1 || die "macOS security command not found."

mkdir -p "$INSTALL_DIR"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

say "Downloading $SCRIPT_DOWNLOAD_URL"
curl -fsSL "$SCRIPT_DOWNLOAD_URL" -o "$tmp"

actual_sha256="$(shasum -a 256 "$tmp" | awk '{print $1}')"
if [[ "$actual_sha256" != "$EXPECTED_SHA256" ]]; then
	die "Integrity check failed.
  expected: $EXPECTED_SHA256
  got:      $actual_sha256
The downloaded file does not match the expected checksum. Aborting."
fi

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
