# shellcheck shell=bash
# bash completion for dev-secret.
# Secret names are deliberately not completed: listing them unlocks the
# keychain, and pressing <Tab> must never trigger a password or Touch ID prompt.

_dev_secret_reply() {
	local word
	while IFS= read -r word; do
		COMPREPLY+=("$word")
	done < <(compgen "$@")
}

_dev_secret() {
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local prev="${COMP_WORDS[COMP_CWORD - 1]}"
	local cmd="${COMP_WORDS[1]:-}"
	local i
	COMPREPLY=()

	if [[ $COMP_CWORD -eq 1 ]]; then
		_dev_secret_reply -W "init set get run list delete keychain doctor scan-env import-env help version" -- "$cur"
		return
	fi

	case "$cmd" in
	init)
		if [[ "$prev" == "--defaults" ]]; then
			_dev_secret_reply -f -- "$cur"
		else
			_dev_secret_reply -W "--defaults" -- "$cur"
		fi
		;;
	set)
		if [[ $COMP_CWORD -ge 3 ]]; then
			_dev_secret_reply -W "--stdin" -- "$cur"
		fi
		;;
	run)
		for ((i = 2; i < COMP_CWORD; i++)); do
			if [[ "${COMP_WORDS[i]}" == "--" ]]; then
				if [[ $((i + 1)) -eq $COMP_CWORD ]]; then
					_dev_secret_reply -c -- "$cur"
				else
					_dev_secret_reply -f -- "$cur"
				fi
				return
			fi
		done
		if [[ $COMP_CWORD -ge 3 ]]; then
			_dev_secret_reply -W "--" -- "$cur"
		fi
		;;
	keychain)
		if [[ $COMP_CWORD -eq 2 ]]; then
			_dev_secret_reply -W "biometric lock unlock status" -- "$cur"
		elif [[ $COMP_CWORD -eq 3 && "$prev" == "biometric" ]]; then
			_dev_secret_reply -W "enable disable status" -- "$cur"
		fi
		;;
	scan-env)
		_dev_secret_reply -f -- "$cur"
		;;
	import-env)
		if [[ "$cur" == -* ]]; then
			_dev_secret_reply -W "--yes" -- "$cur"
		else
			_dev_secret_reply -f -- "$cur"
		fi
		;;
	esac
}

complete -F _dev_secret dev-secret
