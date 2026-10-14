#!/usr/bin/env bats
# install.sh: what it downloads and when it refuses to install.
# curl and security(1) are stubbed; nothing touches the network or a keychain.

load '../test_helper'

setup() {
	isolate_home
	use_stubs unit
	use_stubs installer
	export DEV_SECRET_INSTALL_DIR="$BATS_TEST_TMPDIR/bin"
}

@test "install.sh downloads the pinned release asset and installs it (#8)" {
	version="$(sed -n 's/^VERSION="\(.*\)"$/\1/p' "$DEV_SECRET_BIN")"
	run bash "$REPO_ROOT/install.sh"
	[ "$status" -eq 0 ]
	installer_output="$output"
	run cat "$BATS_TEST_TMPDIR/curl.calls"
	[ "${#lines[@]}" -eq 1 ]
	[[ "$output" == *" https://github.com/sibest19/dev-secret/releases/download/v$version/dev-secret "* ]]
	[[ "$installer_output" == *"Installed dev-secret $version to $DEV_SECRET_INSTALL_DIR/dev-secret"* ]]
	[ -x "$DEV_SECRET_INSTALL_DIR/dev-secret" ]
	cmp "$DEV_SECRET_BIN" "$DEV_SECRET_INSTALL_DIR/dev-secret"
}

@test "install.sh refuses a download that does not match the pinned hash" {
	export CURL_STUB_FILE="$BATS_TEST_TMPDIR/tampered"
	{
		cat "$DEV_SECRET_BIN"
		echo "# tampered"
	} >"$CURL_STUB_FILE"
	run bash "$REPO_ROOT/install.sh"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Integrity check failed."* ]]
	[ ! -e "$DEV_SECRET_INSTALL_DIR/dev-secret" ]
}
