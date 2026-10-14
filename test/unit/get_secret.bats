#!/usr/bin/env bats
# get_secret parses `security find-generic-password -g` output, which prints a
# printable value in quotes and anything else as 0x-prefixed hex (#1).
# A fake security(1) replays both forms; no keychain is touched.

load '../test_helper'

setup() {
	isolate_home
	mkdir -p "$BATS_TEST_TMPDIR/bin"
	cat >"$BATS_TEST_TMPDIR/bin/security" <<'EOF'
#!/bin/bash
# Mimic `security find-generic-password -g`: password line and attributes on stderr.
[[ -f "$BATS_TEST_TMPDIR/password-line" ]] || {
	echo "security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain." >&2
	exit 44
}
cat "$BATS_TEST_TMPDIR/password-line" >&2
printf 'keychain: "/tmp/x.keychain-db"\nclass: "genp"\nattributes:\n    "acct"<blob>="X"\n' >&2
EOF
	chmod +x "$BATS_TEST_TMPDIR/bin/security"
	export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

password_line() {
	printf '%s\n' "$1" >"$BATS_TEST_TMPDIR/password-line"
}

# Byte-exact output of get_secret, hex-encoded so trailing newlines survive.
get_secret_hex() {
	call_fn get_secret GITHUB_TOKEN | xxd -p | tr -d '\n'
}

@test "reads a printable value from the quoted form" {
	password_line 'password: "ghp_123"'
	run call_fn get_secret GITHUB_TOKEN
	[ "$status" -eq 0 ]
	[ "$output" = "ghp_123" ]
}

@test "keeps quotes inside a printable value" {
	password_line 'password: "a"b" c""'
	run call_fn get_secret GITHUB_TOKEN
	[ "$output" = 'a"b" c"' ]
}

@test "decodes the 0x form byte for byte, including a trailing newline" {
	password_line 'password: 0x6E6C0A6D69640A  "nl\012mid\012"'
	run get_secret_hex
	[ "$output" = "6e6c0a6d69640a" ]
}

@test "decodes UTF-8 from the 0x form" {
	password_line 'password: 0x636166C3A9  "caf\303\251"'
	run call_fn get_secret GITHUB_TOKEN
	[ "$output" = "café" ]
}

@test "does not mistake a printable value that looks like hex for the 0x form" {
	password_line 'password: "0x6162"'
	run call_fn get_secret GITHUB_TOKEN
	[ "$output" = "0x6162" ]
}

@test "fails when the item does not exist" {
	run call_fn get_secret GITHUB_TOKEN
	[ "$status" -ne 0 ]
	[ -z "$output" ]
}

@test "fails on unrecognized output instead of guessing" {
	password_line 'password: <unexpected>'
	run call_fn get_secret GITHUB_TOKEN
	[ "$status" -ne 0 ]
}
