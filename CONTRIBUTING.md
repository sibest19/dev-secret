# Contributing

Thanks for helping. `dev-secret` handles credentials, so the bar for changes is
"easy to review" first and "clever" never.

## Setup

```sh
make install-tools  # bats-core, shellcheck, shfmt, gitleaks, zizmor via Homebrew
make check
```

Using an AI coding agent? Point it at [AGENTS.md](AGENTS.md). You are the author of
what you submit, whatever tools you used.

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
   Never pass one as a command-line argument either: use `keychain_write` and
   `keychain_unlock`, which send it to `security -i` on stdin.
4. **Validate input before touching the keychain.** Unit tests assert this with a
   stub `security` that records any call.
5. **Every behaviour change comes with a test.** A known bug that is not fixed yet
   gets a test marked with `skip "known bug: …"`.
6. **Security-relevant changes update [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md).**
7. `make check` must pass. Formatting is whatever `make fmt` produces.
8. After changing `bin/dev-secret`, run `make update-hash` so `install.sh` pins
   the new version. After changing `.github/workflows/`, run `make audit-actions`.

## Issues and pull requests

- **Start from an issue.** One problem per issue, one issue per pull request,
  and the PR body says `Fixes #N`. If you find a second problem along the way,
  open another issue rather than widening the PR. Release PRs, Dependabot
  updates and typo-level docs fixes need no issue.
- **The PR title becomes the commit.** `main` only accepts squash merges, so the
  title is the commit subject on `main`: imperative, sentence case, no prefix
  like `feat:` (for example, "Report why Touch ID cannot be used, consistently").
- **Merging needs** the `Lint` and `Test` checks passing on a branch that is up
  to date with `main`, and every review thread resolved. Signing your branch
  commits is welcome but not required; the squash commit on `main` is signed.
- **CHANGELOG.** Every user-visible change gets an entry under `Unreleased`,
  written from the user's side: what used to happen and what happens now. Link
  the issue. Changes to internals, tests or CI need no entry.

## Tests

| Directory | What | Keychain |
| --- | --- | --- |
| `test/unit/` | argument parsing, validation, rc-file parsing, completion | stubbed `security` |
| `test/integration/` | real round-trips through `security(1)` | throwaway, per test |

Call internal functions from unit tests with `run call_fn <function> <args>`; it
sources `bin/dev-secret` in a fresh `/bin/bash` so the script's own shell options
apply.

## Releasing

1. Update `VERSION` in `bin/dev-secret`, run `make update-hash` so the
   installer pins the new release, and move the `Unreleased` entries in
   `CHANGELOG.md` under the new version.
2. Commit, then create a signed tag: `git tag -s vX.Y.Z -m vX.Y.Z && git push --tags`.
3. The release workflow checks that the tag matches `VERSION`, runs the tests,
   creates the GitHub release, and prints the formula `url`/`sha256` in the job
   summary for the Homebrew tap.
