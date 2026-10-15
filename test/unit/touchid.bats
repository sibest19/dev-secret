#!/usr/bin/env bats
# Touch ID state reporting (#14). A fake swift simulates LocalAuthentication;
# security(1) is stubbed, so no keychain is touched.
# Helpers check the $output and $status of the `run` they make; ShellCheck
# cannot follow that across bats test functions.
# shellcheck disable=SC2030,SC2031

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

# The prompt says who is asking, for what, and which secrets (#26). Touch ID is
# cancelled here, so commands stop before they would reach the keychain.

# with_cancelled_touchid PS_CHAIN COMMAND...: see test/stubs/touchid/ps.
with_cancelled_touchid() {
	local chain="$1"
	shift
	enable_biometric
	mkdir -p "$HOME/Library/Keychains"
	touch "$HOME/Library/Keychains/dev-secrets.keychain-db"
	FAKE_PS_CHAIN="$chain" FAKE_TOUCHID_STATE=0 FAKE_TOUCHID_AUTH=1 run "$DEV_SECRET_BIN" "$@"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Touch ID authentication failed or was cancelled"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/security.calls" ]
}

# The reason passed to the dialog, also printed on stderr.
assert_reason() {
	[ "$(cat "$BATS_TEST_TMPDIR/touchid.prompts")" = "prompt: $1" ]
	[[ "$output" == *"Touch ID: $1"* ]]
	rm "$BATS_TEST_TMPDIR/touchid.prompts"
}

@test "the Touch ID prompt names the requester and the secret (#26)" {
	with_cancelled_touchid "/bin/zsh:claude" get GITHUB_TOKEN
	assert_reason "let claude read GITHUB_TOKEN with dev-secret"
}

@test "the Touch ID prompt for run names the command and every secret (#26)" {
	with_cancelled_touchid "/bin/zsh:claude" run GITHUB_TOKEN NPM_TOKEN AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY \
		-- npm publish --access public
	assert_reason 'let claude run "npm publish --access public" with GITHUB_TOKEN, NPM_TOKEN, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY from dev-secret'
}

@test "the Touch ID prompt puts a long command on one shortened line (#26)" {
	with_cancelled_touchid "make" run GITHUB_TOKEN -- sh -c "$(printf 'echo one\necho two\necho three and more words')"
	assert_reason 'let make run "sh -c echo one echo two echo three an..." with GITHUB_TOKEN from dev-secret'
}

@test "the Touch ID prompt says what set, delete, list and keychain do (#26)" {
	with_cancelled_touchid "-zsh:/Applications/Warp.app/Contents/MacOS/stable" delete GITHUB_TOKEN
	assert_reason "let Warp delete GITHUB_TOKEN from dev-secret"
	with_cancelled_touchid "-zsh:/Applications/Warp.app/Contents/MacOS/stable" list
	assert_reason "let Warp list the secret names in dev-secret"
	with_cancelled_touchid "-zsh:/Applications/Warp.app/Contents/MacOS/stable" keychain unlock
	assert_reason "let Warp unlock the dev-secrets keychain"
	with_cancelled_touchid "-zsh:/Applications/Warp.app/Contents/MacOS/stable" keychain status
	assert_reason "let Warp show the dev-secrets keychain status"

	printf 'placeholder-value' >"$BATS_TEST_TMPDIR/value"
	with_cancelled_touchid "-zsh:/Applications/Warp.app/Contents/MacOS/stable" set GITHUB_TOKEN --stdin <"$BATS_TEST_TMPDIR/value"
	[[ "$(cat "$BATS_TEST_TMPDIR/touchid.prompts")" != *placeholder-value* ]]
	[[ "$output" != *placeholder-value* ]]
	assert_reason "let Warp store GITHUB_TOKEN in dev-secret"
}

@test "the requester is the app, not its helper process (#26)" {
	with_cancelled_touchid "/bin/zsh:/Applications/Visual Studio Code.app/Contents/Frameworks/Code Helper (Plugin).app/Contents/MacOS/Code Helper (Plugin)" get GITHUB_TOKEN
	assert_reason "let Visual Studio Code read GITHUB_TOKEN with dev-secret"
}

@test "the Touch ID prompt leaves the requester out when there is none (#26)" {
	with_cancelled_touchid "/bin/zsh:-bash:sh" get GITHUB_TOKEN
	assert_reason "read GITHUB_TOKEN with dev-secret"

	with_cancelled_touchid "" get GITHUB_TOKEN
	assert_reason "read GITHUB_TOKEN with dev-secret"
}

@test "import-env asks for Touch ID after confirming, naming the secrets (#26)" {
	printf 'export GITHUB_TOKEN=placeholder\nexport NPM_TOKEN=placeholder\n' >"$HOME/.zshrc"
	cp "$HOME/.zshrc" "$BATS_TEST_TMPDIR/zshrc.before"
	enable_biometric
	mkdir -p "$HOME/Library/Keychains"
	touch "$HOME/Library/Keychains/dev-secrets.keychain-db"

	FAKE_PS_CHAIN="/bin/zsh:claude" FAKE_TOUCHID_AUTH=1 run "$DEV_SECRET_BIN" import-env "$HOME/.zshrc" <<<"n"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Aborted."* ]]
	assert_never_prompted

	with_cancelled_touchid "/bin/zsh:claude" import-env --yes "$HOME/.zshrc"
	assert_reason "let claude import GITHUB_TOKEN, NPM_TOKEN into dev-secret"
	cmp "$HOME/.zshrc" "$BATS_TEST_TMPDIR/zshrc.before"
}

@test "import-env does not ask for Touch ID when there is nothing to import (#26)" {
	enable_biometric
	mkdir -p "$HOME/Library/Keychains"
	touch "$HOME/Library/Keychains/dev-secrets.keychain-db"
	run "$DEV_SECRET_BIN" import-env
	[ "$status" -eq 0 ]
	[[ "$output" == *"No plaintext env secrets found."* ]]
	assert_never_prompted
}
