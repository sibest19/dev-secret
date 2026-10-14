#!/usr/bin/env bats
# Touch ID state reporting (#14). A fake swift simulates LocalAuthentication;
# security(1) is stubbed, so no keychain is touched.

load '../test_helper'

setup() {
	isolate_home
	use_stubs unit
	use_stubs touchid
	mkdir -p "$HOME/.config/dev-secret"
}

enable_biometric() {
	touch "$HOME/.config/dev-secret/.biometric-enabled"
}

assert_never_prompted() {
	[ ! -e "$BATS_TEST_TMPDIR/touchid.prompts" ]
}

@test "touchid_authenticate check reports each state without prompting" {
	FAKE_TOUCHID_STATE=0 run call_fn touchid_authenticate check
	[ "$status" -eq 0 ]
	FAKE_TOUCHID_STATE=2 run call_fn touchid_authenticate check
	[ "$status" -eq 2 ]
	FAKE_TOUCHID_STATE=3 run call_fn touchid_authenticate check
	[ "$status" -eq 3 ]
	assert_never_prompted
}

@test "touchid_problem explains lockout, missing biometrics and missing swift" {
	run call_fn touchid_problem 3
	[[ "$output" == *"locked after too many failed attempts"* ]]
	[[ "$output" == *"enter your Mac password once"* ]]
	run call_fn touchid_problem 2
	[[ "$output" == *"not available"* ]]
	run call_fn touchid_problem 4
	[[ "$output" == *"xcode-select --install"* ]]
}

@test "doctor reports Touch ID as available when it is usable" {
	FAKE_TOUCHID_STATE=0 run "$DEV_SECRET_BIN" doctor
	[[ "$output" == *"OK Touch ID available"* ]]
	assert_never_prompted
}

@test "doctor warns about a lockout when Touch ID unlock is enabled (#14)" {
	enable_biometric
	FAKE_TOUCHID_STATE=3 run "$DEV_SECRET_BIN" doctor
	[[ "$output" == *"WARN Touch ID locked after too many failed attempts"* ]]
	[[ "$output" != *"OK Touch ID available"* ]]
	assert_never_prompted
}

@test "doctor only informs about Touch ID when unlock is not enabled" {
	FAKE_TOUCHID_STATE=2 run "$DEV_SECRET_BIN" doctor
	[[ "$output" == *"INFO Touch ID not available"* ]]
}

@test "biometric status shows the reason Touch ID cannot be used (#14)" {
	enable_biometric
	FAKE_TOUCHID_STATE=3 run "$DEV_SECRET_BIN" keychain biometric status
	[ "$status" -eq 0 ]
	[[ "$output" == *"Touch ID: locked after too many failed attempts"* ]]
	[[ "$output" == *"Enabled:   yes"* ]]
	assert_never_prompted
}
