# shellcheck shell=bash
# Shared setup for all bats tests. Load with: load '../test_helper'

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
DEV_SECRET_BIN="$REPO_ROOT/bin/dev-secret"
export REPO_ROOT DEV_SECRET_BIN

# Point HOME at a per-test temp dir so nothing reads or writes the developer's
# real dotfiles, config dir or keychains, and drop any DEV_SECRET_* overrides.
isolate_home() {
	export HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$HOME"
	unset DEV_SECRET_KEYCHAIN_NAME DEV_SECRET_KEYCHAIN_PATH DEV_SECRET_CONFIG_DIR \
		DEV_SECRET_DEFAULTS_FILE DEV_SECRET_SERVICE_PREFIX
}

# Put a directory of test doubles from test/stubs/ first on PATH.
use_stubs() {
	export PATH="$REPO_ROOT/test/stubs/$1:$PATH"
}

# Call an internal function of bin/dev-secret in a fresh /bin/bash, so it runs
# under the script's own `set -euo pipefail` and IFS rather than bats' settings.
#   run call_fn valid_secret_name GITHUB_TOKEN
call_fn() {
	/bin/bash -c 'source "$1"; shift; "$@"' bash "$DEV_SECRET_BIN" "$@"
}
