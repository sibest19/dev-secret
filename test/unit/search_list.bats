#!/usr/bin/env bats
# add_keychain_to_search_list rewrites the user's keychain search list, so a
# parsing bug corrupts global state. A fake security(1) replays real output.

load '../test_helper'

setup() {
	isolate_home
	KEYCHAIN="$HOME/Library/Keychains/dev-secrets.keychain-db"
	mkdir -p "$BATS_TEST_TMPDIR/bin"
	cat >"$BATS_TEST_TMPDIR/bin/security" <<'EOF'
#!/bin/bash
if [[ "$1 $2 $3" == "list-keychains -d user" && $# -eq 3 ]]; then
	cat "$BATS_TEST_TMPDIR/current-list"
	exit 0
fi
shift 4 # list-keychains -d user -s
printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/new-list"
EOF
	chmod +x "$BATS_TEST_TMPDIR/bin/security"
	export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "puts our keychain first and keeps existing entries verbatim" {
	cat >"$BATS_TEST_TMPDIR/current-list" <<EOF
    "$HOME/Library/Keychains/login.keychain-db"
    "/Library/Keychains/System.keychain"
EOF
	run call_fn add_keychain_to_search_list
	[ "$status" -eq 0 ]
	run cat "$BATS_TEST_TMPDIR/new-list"
	[ "${lines[0]}" = "$KEYCHAIN" ]
	[ "${lines[1]}" = "$HOME/Library/Keychains/login.keychain-db" ]
	[ "${lines[2]}" = "/Library/Keychains/System.keychain" ]
	[ "${#lines[@]}" -eq 3 ]
}

@test "does not duplicate our keychain when it is already listed" {
	cat >"$BATS_TEST_TMPDIR/current-list" <<EOF
    "$KEYCHAIN"
    "$HOME/Library/Keychains/login.keychain-db"
EOF
	run call_fn add_keychain_to_search_list
	run cat "$BATS_TEST_TMPDIR/new-list"
	[ "${lines[0]}" = "$KEYCHAIN" ]
	[ "${lines[1]}" = "$HOME/Library/Keychains/login.keychain-db" ]
	[ "${#lines[@]}" -eq 2 ]
}

@test "works when the current search list is empty (bash 3.2 + set -u)" {
	: >"$BATS_TEST_TMPDIR/current-list"
	run call_fn add_keychain_to_search_list
	[ "$status" -eq 0 ]
	run cat "$BATS_TEST_TMPDIR/new-list"
	[ "$output" = "$KEYCHAIN" ]
}
