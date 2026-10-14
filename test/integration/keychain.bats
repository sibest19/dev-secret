#!/usr/bin/env bats
# Literal `$...` strings below are intentional test data.
# shellcheck disable=SC2016
# End-to-end tests against a real, throwaway keychain created under a temp HOME.
# test/stubs/integration/security wraps the real security(1) to supply the test
# keychain password and to keep the developer's keychain search list untouched.

load '../test_helper'

setup() {
	[[ "$OSTYPE" == darwin* ]] || skip "requires macOS Keychain"
	isolate_home
	use_stubs integration
	export DEV_SECRET_TEST_KEYCHAIN_PASSWORD="test-$$-$RANDOM"
	KEYCHAIN="$HOME/Library/Keychains/dev-secrets.keychain-db"
	"$DEV_SECRET_BIN" init >/dev/null
}

teardown() {
	[[ -n "${KEYCHAIN:-}" ]] && /usr/bin/security delete-keychain "$KEYCHAIN" 2>/dev/null || true
}

@test "init creates the keychain and a private config dir" {
	[ -f "$KEYCHAIN" ]
	[ "$(stat -f %Lp "$HOME/.config/dev-secret")" = "700" ]
	[ "$(stat -f %Lp "$HOME/.config/dev-secret/defaults")" = "600" ]
}

@test "init is idempotent" {
	run "$DEV_SECRET_BIN" init
	[ "$status" -eq 0 ]
	[[ "$output" == *"Keychain exists"* ]]
}

@test "set --stdin then get round-trips the value" {
	printf 'ghp_123' | "$DEV_SECRET_BIN" set GITHUB_TOKEN --stdin
	run "$DEV_SECRET_BIN" get GITHUB_TOKEN
	[ "$status" -eq 0 ]
	[ "$output" = "ghp_123" ]
}

@test "values with spaces, quotes and shell metacharacters round-trip" {
	value='p@ss w0rd "q" '\''s'\'' $HOME `id` ;|&'
	printf '%s' "$value" | "$DEV_SECRET_BIN" set WEIRD_PASSWORD --stdin
	run "$DEV_SECRET_BIN" get WEIRD_PASSWORD
	[ "$output" = "$value" ]
}

@test "values with a trailing newline round-trip" {
	skip "known bug: security(1) -w prints values with non-printable bytes as hex, so 'echo x | set --stdin' reads back as 780a"
	echo 'ghp_123' | "$DEV_SECRET_BIN" set GITHUB_TOKEN --stdin
	run "$DEV_SECRET_BIN" get GITHUB_TOKEN
	[ "$output" = "ghp_123" ]
}

@test "set overwrites an existing value" {
	printf 'old' | "$DEV_SECRET_BIN" set GITHUB_TOKEN --stdin
	printf 'new' | "$DEV_SECRET_BIN" set GITHUB_TOKEN --stdin
	run "$DEV_SECRET_BIN" get GITHUB_TOKEN
	[ "$output" = "new" ]
}

@test "run exposes secrets only to the child command" {
	printf 'aaa' | "$DEV_SECRET_BIN" set FIRST_TOKEN --stdin
	printf 'bbb' | "$DEV_SECRET_BIN" set SECOND_TOKEN --stdin
	run "$DEV_SECRET_BIN" run FIRST_TOKEN SECOND_TOKEN -- /bin/sh -c 'printf "%s %s" "$FIRST_TOKEN" "$SECOND_TOKEN"'
	[ "$status" -eq 0 ]
	[ "$output" = "aaa bbb" ]
	[ -z "${FIRST_TOKEN:-}" ]
}

@test "run propagates the child's exit status" {
	printf 'aaa' | "$DEV_SECRET_BIN" set FIRST_TOKEN --stdin
	run "$DEV_SECRET_BIN" run FIRST_TOKEN -- /bin/sh -c 'exit 7'
	[ "$status" -eq 7 ]
}

@test "run fails without running the command when a secret is missing" {
	run "$DEV_SECRET_BIN" run MISSING_TOKEN -- /usr/bin/touch "$BATS_TEST_TMPDIR/ran"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Secret not found: MISSING_TOKEN"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/ran" ]
}

@test "list shows names but never values" {
	printf 'value-one' | "$DEV_SECRET_BIN" set B_TOKEN --stdin
	printf 'value-two' | "$DEV_SECRET_BIN" set A_TOKEN --stdin
	run "$DEV_SECRET_BIN" list
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "A_TOKEN" ]
	[ "${lines[1]}" = "B_TOKEN" ]
	[[ "$output" != *"value-"* ]]
}

@test "delete removes the secret" {
	printf 'x' | "$DEV_SECRET_BIN" set GITHUB_TOKEN --stdin
	run "$DEV_SECRET_BIN" delete GITHUB_TOKEN
	[ "$status" -eq 0 ]
	run "$DEV_SECRET_BIN" get GITHUB_TOKEN
	[ "$status" -eq 1 ]
	[[ "$output" == *"Secret not found"* ]]
}

@test "get reports a missing secret" {
	run "$DEV_SECRET_BIN" get NOPE_TOKEN
	[ "$status" -eq 1 ]
	[[ "$output" == *"Secret not found: NOPE_TOKEN"* ]]
}

@test "import-env moves plaintext secrets into the keychain and leaves a private backup" {
	cat >"$HOME/.zshrc" <<'EOF'
export PATH="$HOME/bin:$PATH"
export GITHUB_TOKEN="ghp_from_rc"
export NPM_TOKEN=$(gh auth token)
EOF
	run "$DEV_SECRET_BIN" import-env --yes "$HOME/.zshrc"
	[ "$status" -eq 0 ]

	run "$DEV_SECRET_BIN" get GITHUB_TOKEN
	[ "$output" = "ghp_from_rc" ]

	run cat "$HOME/.zshrc"
	[[ "$output" != *"ghp_from_rc"* ]]
	[[ "$output" == *"# dev-secret imported GITHUB_TOKEN"* ]]
	[[ "$output" == *'export NPM_TOKEN=$(gh auth token)'* ]]
	[[ "$output" == *'export PATH="$HOME/bin:$PATH"'* ]]

	backup="$(ls "$HOME"/.zshrc.bak.dev-secret.*)"
	[ "$(stat -f %Lp "$backup")" = "600" ]
	grep -q ghp_from_rc "$backup"
}

@test "import-env without --yes aborts on a negative answer and changes nothing" {
	printf 'export GITHUB_TOKEN=keepme\n' >"$HOME/.zshrc"
	run "$DEV_SECRET_BIN" import-env "$HOME/.zshrc" <<<"n"
	[ "$status" -eq 1 ]
	grep -q keepme "$HOME/.zshrc"
	run "$DEV_SECRET_BIN" get GITHUB_TOKEN
	[ "$status" -eq 1 ]
}
