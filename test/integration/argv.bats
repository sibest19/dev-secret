#!/usr/bin/env bats
# Literal `$...` strings below are intentional: they expand in the child shell.
# shellcheck disable=SC2016
# Secrets and keychain passwords must never appear on a command line, where any
# local user can read them with ps (#6). The integration stubs record every
# argv passed to security(1) and env(1) in $BATS_TEST_TMPDIR/argv.log.

load '../test_helper'

setup() {
	[[ "$OSTYPE" == darwin* ]] || skip "requires macOS Keychain"
	isolate_home
	use_stubs integration
	export DEV_SECRET_TEST_KEYCHAIN_PASSWORD="test-$$-$RANDOM"
	KEYCHAIN="$HOME/Library/Keychains/dev-secrets.keychain-db"
	LOGIN="$HOME/Library/Keychains/login.keychain-db" # throwaway, under the temp HOME
	"$DEV_SECRET_BIN" init >/dev/null
}

teardown() {
	local k
	for k in "${KEYCHAIN:-}" "${LOGIN:-}" "${EXTRA_KEYCHAIN:-}"; do
		[[ -n "$k" && -f "$k" ]] && /usr/bin/security delete-keychain "$k" 2>/dev/null
	done
	true
}

refute_in_argv() {
	if grep -qF -- "$1" "$BATS_TEST_TMPDIR/argv.log"; then
		echo "found in argv: $1"
		grep -nF -- "$1" "$BATS_TEST_TMPDIR/argv.log"
		return 1
	fi
}

@test "set, import-env, get and run keep secret values out of argv (#6)" {
	printf 'value-from-set-1f3a' | "$DEV_SECRET_BIN" set FIRST_TOKEN --stdin
	printf 'export SECOND_TOKEN="value-from-rc-9c2e"\n' >"$HOME/.zshrc"
	"$DEV_SECRET_BIN" import-env --yes "$HOME/.zshrc" >/dev/null
	printf 'value-updated-77d0' | "$DEV_SECRET_BIN" set FIRST_TOKEN --stdin

	run "$DEV_SECRET_BIN" get SECOND_TOKEN
	[ "$output" = "value-from-rc-9c2e" ]
	run "$DEV_SECRET_BIN" run FIRST_TOKEN SECOND_TOKEN -- /bin/sh -c 'printf "%s %s" "$FIRST_TOKEN" "$SECOND_TOKEN"'
	[ "$output" = "value-updated-77d0 value-from-rc-9c2e" ]

	refute_in_argv value-from-set-1f3a
	refute_in_argv value-from-rc-9c2e
	refute_in_argv value-updated-77d0
	grep -qx -- '-i' "$BATS_TEST_TMPDIR/argv.log"
}

@test "a value just under the stdin limit stays out of argv" {
	value="$(head -c 1800 /dev/zero | tr '\0' 'k')"
	run "$DEV_SECRET_BIN" set BIG_TOKEN --stdin <<<"$value"
	[ "$status" -eq 0 ]
	[[ "$output" != *"Warning"* ]]
	run "$DEV_SECRET_BIN" get BIG_TOKEN
	[ "$output" = "$value" ]
	refute_in_argv "$value"
}

@test "a value too long for stdin falls back to argv with a warning and still round-trips" {
	value="$(head -c 3000 /dev/zero | tr '\0' 'L')"
	run "$DEV_SECRET_BIN" set HUGE_KEY --stdin <<<"$value"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Warning: HUGE_KEY is too long to send on stdin"* ]]
	run "$DEV_SECRET_BIN" get HUGE_KEY
	[ "$output" = "$value" ]
}

@test "keychain_unlock handles quotes and backslashes and keeps the password out of argv (#6)" {
	EXTRA_KEYCHAIN="$HOME/Library/Keychains/extra.keychain-db"
	password='p w"d\x-2b81'
	/usr/bin/security create-keychain -p "$password" "$EXTRA_KEYCHAIN"
	/usr/bin/security lock-keychain "$EXTRA_KEYCHAIN"

	run call_fn keychain_unlock "$EXTRA_KEYCHAIN" 'wrong'
	[ "$status" -ne 0 ]
	run call_fn keychain_unlock "$EXTRA_KEYCHAIN" "$password"
	[ "$status" -eq 0 ]
	refute_in_argv 'p w"d'
}

@test "re-enrolling the Touch ID credential updates it without a GUI prompt (#4)" {
	/usr/bin/security create-keychain -p login-test "$LOGIN"

	run call_fn biometric_store 'first-password-41c7'
	[ "$status" -eq 0 ]
	run call_fn biometric_store 'second-password-0e95'
	[ "$status" -eq 0 ]
	run call_fn keychain_read "$LOGIN" keychain-password it.simoneandreani.dev-secret.keychain-unlock
	[ "$output" = "second-password-0e95" ]
	refute_in_argv first-password-41c7
	refute_in_argv second-password-0e95
}

@test "Touch ID unlock passes the keychain password on stdin (#6)" {
	/usr/bin/security create-keychain -p login-test "$LOGIN"
	printf 'tok' | "$DEV_SECRET_BIN" set GITHUB_TOKEN --stdin
	call_fn biometric_store "$DEV_SECRET_TEST_KEYCHAIN_PASSWORD"
	touch "$HOME/.config/dev-secret/.biometric-enabled"

	# Touch ID itself is out of reach in tests: a fake swift reports success.
	mkdir -p "$BATS_TEST_TMPDIR/touchid"
	printf '#!/bin/bash\nexit 0\n' >"$BATS_TEST_TMPDIR/touchid/swift"
	chmod +x "$BATS_TEST_TMPDIR/touchid/swift"
	/usr/bin/security lock-keychain "$KEYCHAIN"
	: >"$BATS_TEST_TMPDIR/argv.log"

	PATH="$BATS_TEST_TMPDIR/touchid:$PATH" run "$DEV_SECRET_BIN" get GITHUB_TOKEN
	[ "$status" -eq 0 ]
	[ "$output" = "tok" ]
	refute_in_argv "$DEV_SECRET_TEST_KEYCHAIN_PASSWORD"
	run grep -c '^unlock-keychain' "$BATS_TEST_TMPDIR/argv.log"
	[ "$output" = "0" ]
}
