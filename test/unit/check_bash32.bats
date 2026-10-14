#!/usr/bin/env bats
# Literal bash 4+ snippets below are intentional test data.
# shellcheck disable=SC2016
# scripts/check-bash32 must flag each bash 4+ construct it claims to,
# without flagging comments or bash 3.2 idioms the codebase relies on.

load '../test_helper'

CHECK="$REPO_ROOT/scripts/check-bash32"

check_snippet() {
	printf '%s\n' "$1" >"$BATS_TEST_TMPDIR/snippet.sh"
	run "$CHECK" "$BATS_TEST_TMPDIR/snippet.sh"
}

@test "flags each bash 4+ construct" {
	while IFS= read -r snippet; do
		check_snippet "$snippet"
		if [ "$status" -ne 1 ]; then
			echo "not flagged: $snippet"
			return 1
		fi
	done <<'EOF'
mapfile -t lines < file
readarray -t lines < file
coproc cat
declare -A map
local -n ref=other
typeset -l lower
if [[ -v HOME ]]; then :; fi
echo "${name,,}"
echo "${name^^}"
echo "${arr[0]^}"
echo "${value@Q}"
echo "${arr[-1]}"
cmd &>> log
cmd |& tee log
a) echo a ;&
b) echo b ;;&
echo "$EPOCHSECONDS"
shopt -s globstar
wait -n
read -r -i default -p "x" reply
printf '%(%Y)T' -1
echo {1..10..2}
EOF
}

@test "accepts bash 3.2 idioms used in the codebase" {
	while IFS= read -r snippet; do
		check_snippet "$snippet"
		if [ "$status" -ne 0 ]; then
			echo "false positive: $snippet"
			echo "$output"
			return 1
		fi
	done <<'EOF'
local current=()
local -a names
declare -r CONST=1
security list -s "$K" ${current[@]+"${current[@]}"}
for i in "${!patterns[@]}"; do :; done
read -r -s -p "Enter value for $name: " value1 || true
[[ -n "$a" && "$b" != "$c" ]] && current+=("$line")
value="${value%% #*}"
line="${line#"${line%%[![:space:]]*}"}"
cmd >/dev/null 2>&1 || die "x"
printf '%s' "$v"
echo {1..10}
EOF
}

@test "ignores whole-line comments" {
	check_snippet '	# mapfile would be nicer, but bash 3.2'
	[ "$status" -eq 0 ]
}

@test "reports file, line and reason" {
	printf 'ok=1\nmapfile -t x\n' >"$BATS_TEST_TMPDIR/snippet.sh"
	run "$CHECK" "$BATS_TEST_TMPDIR/snippet.sh"
	[ "$status" -eq 1 ]
	[[ "${lines[0]}" == "$BATS_TEST_TMPDIR/snippet.sh:2:mapfile -t x" ]]
	[[ "${lines[1]}" == *"need bash 4"* ]]
}
