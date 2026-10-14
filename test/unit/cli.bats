#!/usr/bin/env bats
# Command-line surface: dispatch, usage and argument validation.
# security(1) is stubbed; every test here must leave it uncalled.

load '../test_helper'

setup() {
	isolate_home
	use_stubs unit
}

assert_keychain_untouched() {
	[ ! -e "$BATS_TEST_TMPDIR/security.calls" ]
}

@test "version prints the VERSION declared in the script" {
	expected="$(sed -n 's/^VERSION="\(.*\)"$/\1/p' "$DEV_SECRET_BIN")"
	run "$DEV_SECRET_BIN" version
	[ "$status" -eq 0 ]
	[ "$output" = "$expected" ]
	run "$DEV_SECRET_BIN" --version
	[ "$output" = "$expected" ]
}

@test "no arguments shows usage and succeeds" {
	run "$DEV_SECRET_BIN"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage:"* ]]
}

@test "unknown command shows usage and fails" {
	run "$DEV_SECRET_BIN" frobnicate
	[ "$status" -eq 1 ]
	[[ "$output" == *"Usage:"* ]]
	assert_keychain_untouched
}

@test "set rejects names that are not ENV_VAR style" {
	for bad in 1TOKEN FOO-BAR 'FOO BAR' 'X;rm' ''; do
		run "$DEV_SECRET_BIN" set "$bad"
		[ "$status" -eq 1 ]
		[[ "$output" == *"Invalid secret name"* || "$output" == *"Missing secret name"* ]]
	done
	assert_keychain_untouched
}

@test "get and delete validate the name before touching the keychain" {
	run "$DEV_SECRET_BIN" get 'BAD-NAME'
	[ "$status" -eq 1 ]
	[[ "$output" == *"Invalid secret name"* ]]
	run "$DEV_SECRET_BIN" delete 'BAD-NAME'
	[ "$status" -eq 1 ]
	assert_keychain_untouched
}

@test "set rejects unknown options" {
	run "$DEV_SECRET_BIN" set GITHUB_TOKEN --nope
	[ "$status" -eq 1 ]
	[[ "$output" == *"Unknown set option"* ]]
	assert_keychain_untouched
}

@test "run requires at least one secret name" {
	run "$DEV_SECRET_BIN" run -- /usr/bin/true
	[ "$status" -eq 1 ]
	[[ "$output" == *"At least one secret name is required"* ]]
	assert_keychain_untouched
}

@test "run requires a command after --" {
	run "$DEV_SECRET_BIN" run GITHUB_TOKEN --
	[ "$status" -eq 1 ]
	[[ "$output" == *"Command missing after --"* ]]
	assert_keychain_untouched
}

@test "run validates every secret name" {
	run "$DEV_SECRET_BIN" run GITHUB_TOKEN 'BAD-NAME' -- /usr/bin/true
	[ "$status" -eq 1 ]
	[[ "$output" == *"Invalid secret name 'BAD-NAME'"* ]]
	assert_keychain_untouched
}

@test "keychain rejects unknown subcommands" {
	run "$DEV_SECRET_BIN" keychain explode
	[ "$status" -eq 1 ]
	[[ "$output" == *"Unknown keychain subcommand"* ]]
	run "$DEV_SECRET_BIN" keychain biometric explode
	[ "$status" -eq 1 ]
	[[ "$output" == *"Unknown biometric subcommand"* ]]
	assert_keychain_untouched
}

@test "biometric status reports disabled when not enrolled" {
	use_stubs touchid # never depend on the machine's real Touch ID state
	FAKE_TOUCHID_STATE=2 run "$DEV_SECRET_BIN" keychain biometric status
	[ "$status" -eq 0 ]
	[[ "$output" == *"Touch ID: not available"* ]]
	[[ "$output" == *"Enabled:   no"* ]]
}
