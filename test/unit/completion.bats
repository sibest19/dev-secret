#!/usr/bin/env bats
# bash completion: offers commands and options, never touches the keychain.

load '../test_helper'

setup() {
	isolate_home
	use_stubs unit
	# shellcheck source=../../completions/dev-secret.bash
	source "$REPO_ROOT/completions/dev-secret.bash"
}

# complete_words WORD... — completions for the last word of the command line.
complete_words() {
	COMP_WORDS=("$@")
	COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
	_dev_secret
	printf '%s\n' ${COMPREPLY[@]+"${COMPREPLY[@]}"}
}

@test "completes subcommands" {
	run complete_words dev-secret ke
	[ "$output" = "keychain" ]
	run complete_words dev-secret ''
	[[ "$output" == *"import-env"* ]]
	[[ "$output" == *"run"* ]]
}

@test "completes keychain and biometric subcommands" {
	run complete_words dev-secret keychain ''
	[ "$output" = "$(printf 'biometric\nlock\nunlock\nstatus')" ]
	run complete_words dev-secret keychain biometric en
	[ "$output" = "enable" ]
}

@test "offers --stdin after the secret name for set" {
	run complete_words dev-secret set GITHUB_TOKEN --
	[ "$output" = "--stdin" ]
}

@test "completes commands after -- in run" {
	run complete_words dev-secret run GITHUB_TOKEN -- printen
	[[ "$output" == *"printenv"* ]]
}

@test "never queries the keychain" {
	complete_words dev-secret get '' >/dev/null
	complete_words dev-secret run '' >/dev/null
	[ ! -e "$BATS_TEST_TMPDIR/security.calls" ]
}
