#!/usr/bin/env bats
# scan-env / import-env parsing. These read the user's shell rc files, and
# import-env rewrites them, so the parsing rules are worth pinning down.

load '../test_helper'

setup() {
	isolate_home
	use_stubs unit
	RC="$BATS_TEST_TMPDIR/zshrc"
}

@test "scan_file reports plaintext and dynamic secret assignments with line numbers" {
	cat >"$RC" <<'EOF'
export PATH="$HOME/bin:$PATH"
export GITHUB_TOKEN=ghp_plain
SENTRY_AUTH_TOKEN="quoted"
export NPM_TOKEN=$(gh auth token)
export LEGACY_PASSWORD=`cat ~/.pw`
# export COMMENTED_TOKEN=nope
EDITOR=vim
EOF
	run call_fn scan_file "$RC"
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "$RC:2:GITHUB_TOKEN:plaintext" ]
	[ "${lines[1]}" = "$RC:3:SENTRY_AUTH_TOKEN:plaintext" ]
	[ "${lines[2]}" = "$RC:4:NPM_TOKEN:dynamic" ]
	[ "${lines[3]}" = "$RC:5:LEGACY_PASSWORD:dynamic" ]
	[ "${#lines[@]}" -eq 4 ]
}

@test "scan_file matches any name containing TOKEN, SECRET, PASSWORD, PASS or KEY" {
	cat >"$RC" <<'EOF'
API_KEY=a
CLIENT_SECRET=b
DB_PASS=c
SSH_KEY_PATH=d
HOME_DIR=e
EOF
	run call_fn scan_file "$RC"
	[[ "$output" == *":API_KEY:"* ]]
	[[ "$output" == *":CLIENT_SECRET:"* ]]
	[[ "$output" == *":DB_PASS:"* ]]
	[[ "$output" == *":SSH_KEY_PATH:"* ]]
	[[ "$output" != *"HOME_DIR"* ]]
}

@test "scan_file ignores a missing file" {
	run call_fn scan_file "$BATS_TEST_TMPDIR/does-not-exist"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "scan_file handles a last line without trailing newline" {
	printf 'export GITHUB_TOKEN=abc' >"$RC"
	run call_fn scan_file "$RC"
	[ "$output" = "$RC:1:GITHUB_TOKEN:plaintext" ]
}

@test "scan-env never prints secret values" {
	printf 'export GITHUB_TOKEN=ghp_supersecretvalue\n' >"$RC"
	run "$DEV_SECRET_BIN" scan-env "$RC"
	[ "$status" -eq 0 ]
	[[ "$output" == *"GITHUB_TOKEN:plaintext"* ]]
	[[ "$output" != *"ghp_supersecretvalue"* ]]
}

@test "scan-env reports when nothing is found" {
	printf 'export EDITOR=vim\n' >"$RC"
	run "$DEV_SECRET_BIN" scan-env "$RC"
	[ "$status" -eq 0 ]
	[ "$output" = "No plaintext env secrets found." ]
}

@test "scan-env defaults to rc files in HOME" {
	printf 'export GITHUB_TOKEN=x\n' >"$HOME/.zshrc"
	run "$DEV_SECRET_BIN" scan-env
	[ "$output" = "$HOME/.zshrc:1:GITHUB_TOKEN:plaintext" ]
}

@test "extract_assignment_value unwraps quotes" {
	run call_fn extract_assignment_value 'export GITHUB_TOKEN="ghp abc"'
	[ "$output" = "ghp abc" ]
	run call_fn extract_assignment_value "GITHUB_TOKEN='ghp abc'"
	[ "$output" = "ghp abc" ]
}

@test "extract_assignment_value keeps '=' inside the value" {
	run call_fn extract_assignment_value 'export B64_KEY=YWJj=='
	[ "$output" = "YWJj==" ]
}

@test "extract_assignment_value strips inline comments only from unquoted values" {
	run call_fn extract_assignment_value 'GITHUB_TOKEN=abc # personal'
	[ "$output" = "abc" ]
	run call_fn extract_assignment_value 'GITHUB_TOKEN="abc # not a comment"'
	[ "$output" = "abc # not a comment" ]
}

@test "extract_assignment_value strips a CRLF line ending" {
	run call_fn extract_assignment_value $'GITHUB_TOKEN=abc\r'
	[ "$output" = "abc" ]
}

# expect_value LINE VALUE — extract_assignment_value turns LINE into exactly VALUE.
expect_value() {
	local got
	got="$(call_fn extract_assignment_value "$1")"
	if [ "$got" != "$2" ]; then
		printf 'line:     %q\nexpected: %q\ngot:      %q\n' "$1" "$2" "$got"
		return 1
	fi
}

@test "extract_assignment_value drops all whitespace before an inline comment (#2)" {
	expect_value 'GITHUB_TOKEN=abc  # two spaces' 'abc'
	expect_value $'GITHUB_TOKEN=abc\t# tab' 'abc'
	expect_value $'GITHUB_TOKEN=abc \t # mixed' 'abc'
}

@test "extract_assignment_value drops trailing whitespace without a comment (#2)" {
	expect_value 'GITHUB_TOKEN=abc   ' 'abc'
	expect_value $'GITHUB_TOKEN=abc\t\r' 'abc'
}

@test "extract_assignment_value unwraps quoted values followed by a comment (#2)" {
	expect_value 'GITHUB_TOKEN="abc" # note' 'abc'
	expect_value "GITHUB_TOKEN='abc'  # note" 'abc'
	expect_value 'GITHUB_TOKEN="abc" # "quoted" note' 'abc'
	expect_value 'GITHUB_TOKEN="abc"   ' 'abc'
}

@test "extract_assignment_value keeps '#' that does not start a comment" {
	expect_value 'GITHUB_TOKEN=abc#def' 'abc#def'
	expect_value 'GITHUB_TOKEN="abc # not a comment"' 'abc # not a comment'
	expect_value "GITHUB_TOKEN='abc # not a comment' # but this is" 'abc # not a comment'
}

@test "extract_assignment_value keeps whitespace inside quotes" {
	expect_value 'GITHUB_TOKEN="  padded  "' '  padded  '
	expect_value 'GITHUB_TOKEN=" padded " # note' ' padded '
}
