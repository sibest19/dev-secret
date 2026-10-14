# Contributing

Thanks for helping. `dev-secret` handles credentials, so the bar for changes is
"easy to review" first and "clever" never.

## Setup

```sh
brew install bats-core shellcheck shfmt gitleaks
make check
```

`make test-unit` never touches a real keychain. `make test-integration` creates
throwaway keychains under a temporary `HOME` and deletes them afterwards; it does
not modify your login keychain or your keychain search list.

## Ground rules

1. **Bash 3.2.** The script runs under macOS's `/bin/bash`. No `mapfile`,
   associative arrays, `${var,,}`, or `[[ -v ]]`. Expand possibly-empty arrays as
   `${arr[@]+"${arr[@]}"}`. `make lint` runs `scripts/check-bash32` to catch
   bash 4+ syntax that the tests don't exercise. Why not require bash 5: the
   script must work wherever `PATH` lacks Homebrew (cron, launchd, IDEs, agents),
   `/bin/bash` is SIP-protected while Homebrew's bash is user-writable, and
   "no runtime dependencies" is a feature.
2. **No new runtime dependencies.** Only tools that ship with macOS.
3. **Never print, log, or `set -x` a secret value**, including in tests and error
   messages. Use placeholder values in tests and issues.
4. **Validate input before touching the keychain.** Unit tests assert this with a
   stub `security` that records any call.
5. **Every behaviour change comes with a test.** A known bug that is not fixed yet
   gets a test marked with `skip "known bug: …"`.
6. **Security-relevant changes update [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md).**
7. `make check` must pass. Formatting is whatever `make fmt` produces.

## Tests

| Directory | What | Keychain |
| --- | --- | --- |
| `test/unit/` | argument parsing, validation, rc-file parsing, completion | stubbed `security` |
| `test/integration/` | real round-trips through `security(1)` | throwaway, per test |

Call internal functions from unit tests with `run call_fn <function> <args>`; it
sources `bin/dev-secret` in a fresh `/bin/bash` so the script's own shell options
apply.

## Releasing

1. Update `VERSION` in `bin/dev-secret` and move the `Unreleased` entries in
   `CHANGELOG.md` under the new version.
2. Commit, then create a signed tag: `git tag -s vX.Y.Z -m vX.Y.Z && git push --tags`.
3. The release workflow checks that the tag matches `VERSION`, runs the tests,
   creates the GitHub release, and prints the formula `url`/`sha256` in the job
   summary for the Homebrew tap.
