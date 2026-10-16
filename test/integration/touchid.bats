#!/usr/bin/env bats
# Unlocking with Touch ID enabled, against a throwaway keychain. A fake swift
# simulates LocalAuthentication; the security wrapper supplies the keychain
# password whenever dev-secret falls back to asking for it.

load '../test_helper'

bats_require_minimum_version 1.5.0

setup() {
	[[ "$OSTYPE" == darwin* ]] || skip "requires macOS Keychain"
	isolate_home
	use_stubs integration
	use_stubs touchid
	export DEV_SECRET_TEST_KEYCHAIN_PASSWORD="test-$$-$RANDOM"
	KEYCHAIN="$HOME/Library/Keychains/dev-secrets.keychain-db"
	LOGIN="$HOME/Library/Keychains/login.keychain-db" # throwaway, under the temp HOME
	"$DEV_SECRET_BIN" init >/dev/null
	/usr/bin/security create-keychain -p login-test "$LOGIN"
	printf 'tok' | "$DEV_SECRET_BIN" set GITHUB_TOKEN --stdin
	call_fn biometric_store "$DEV_SECRET_TEST_KEYCHAIN_PASSWORD"
	touch "$HOME/.config/dev-secret/.biometric-enabled"
	/usr/bin/security lock-keychain "$KEYCHAIN"
	: >"$BATS_TEST_TMPDIR/argv.log" # only record calls made by the test itself
}

teardown() {
	local k
	for k in "${KEYCHAIN:-}" "${LOGIN:-}"; do
		[[ -n "$k" && -f "$k" ]] && /usr/bin/security delete-keychain "$k" 2>/dev/null
	done
	true
}

@test "Touch ID success unlocks without asking for the keychain password" {
	FAKE_TOUCHID_STATE=0 FAKE_TOUCHID_AUTH=0 run --separate-stderr "$DEV_SECRET_BIN" get GITHUB_TOKEN
	[ "$status" -eq 0 ]
	[ "$output" = "tok" ]
	[[ "$stderr" == "Touch ID: "*"read GITHUB_TOKEN with dev-secret" ]]
	[ "$(wc -l <"$BATS_TEST_TMPDIR/touchid.prompts")" -eq 1 ]
	run grep -c '^unlock-keychain' "$BATS_TEST_TMPDIR/argv.log"
	[ "$output" = "0" ]
}

@test "a Touch ID lockout falls back to the keychain password and says why (#14)" {
	FAKE_TOUCHID_STATE=3 run "$DEV_SECRET_BIN" get GITHUB_TOKEN
	[ "$status" -eq 0 ]
	[[ "$output" == *"Touch ID locked after too many failed attempts"* ]]
	[[ "$output" == *"Falling back to the keychain password."* ]]
	[[ "$output" == *"tok" ]]
	[ ! -e "$BATS_TEST_TMPDIR/touchid.prompts" ]
	grep -q '^unlock-keychain' "$BATS_TEST_TMPDIR/argv.log"
}

@test "a cancelled Touch ID prompt stops instead of falling back" {
	FAKE_TOUCHID_STATE=0 FAKE_TOUCHID_AUTH=1 run "$DEV_SECRET_BIN" get GITHUB_TOKEN
	[ "$status" -eq 1 ]
	[[ "$output" == *"Touch ID authentication failed or was cancelled"* ]]
	[[ "$output" != *"tok"* ]]
}

@test "import-env unlocks with Touch ID after confirming, naming the secrets (#26)" {
	printf 'export NPM_TOKEN=npm-placeholder\n' >"$HOME/.zshrc"
	FAKE_PS_CHAIN="/bin/zsh:claude" FAKE_TOUCHID_STATE=0 FAKE_TOUCHID_AUTH=0 \
		run "$DEV_SECRET_BIN" import-env --yes "$HOME/.zshrc"
	[ "$status" -eq 0 ]
	[ "$(cat "$BATS_TEST_TMPDIR/touchid.prompts")" = "prompt: let claude import NPM_TOKEN into dev-secret" ]
	[ "$(call_fn get_secret NPM_TOKEN)" = "npm-placeholder" ]
}
