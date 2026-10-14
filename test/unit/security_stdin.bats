#!/usr/bin/env bats
# Helpers that send secrets to `security -i` on stdin instead of argv (#6).
# security(1) is stubbed; these tests never touch a keychain.

load '../test_helper'

setup() {
	isolate_home
	use_stubs unit
}

@test "security_i_quote escapes backslashes and double quotes" {
	run call_fn security_i_quote 'a"b\c d'
	[ "$output" = '"a\"b\\c d"' ]
}

@test "security_stdin_fits accepts a normal command line" {
	run call_fn security_stdin_fits 'add-generic-password -a "X" -X 6162 "/tmp/k.keychain-db"'
	[ "$status" -eq 0 ]
}

@test "security_stdin_fits rejects lines with a newline or carriage return" {
	run call_fn security_stdin_fits $'unlock-keychain -p "a\nb" "/tmp/k"'
	[ "$status" -ne 0 ]
	run call_fn security_stdin_fits $'unlock-keychain -p "a\rb" "/tmp/k"'
	[ "$status" -ne 0 ]
}

@test "security_stdin_fits counts bytes, not characters" {
	# 1999 'é' are 3998 bytes (fits); 2000 are 4000 bytes (does not).
	fits="$(printf 'é%.0s' $(seq 1999))"
	run call_fn security_stdin_fits "$fits"
	[ "$status" -eq 0 ]
	run call_fn security_stdin_fits "${fits}é"
	[ "$status" -ne 0 ]
}

@test "keychain_write refuses a missing keychain before calling security" {
	# `security -i` would silently write to the login keychain instead.
	run call_fn keychain_write "$HOME/missing.keychain-db" ACCOUNT service value
	[ "$status" -ne 0 ]
	[[ "$output" == *"Keychain not found"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/security.calls" ]
}

@test "keychain_unlock refuses a missing keychain before calling security" {
	run call_fn keychain_unlock "$HOME/missing.keychain-db" password
	[ "$status" -ne 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/security.calls" ]
}
