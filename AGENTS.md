# Agent instructions

Rules for AI coding agents working on this repository. Everything here is in
addition to [CONTRIBUTING.md](CONTRIBUTING.md), which applies to every
contributor: read it first. [CONTEXT.md](CONTEXT.md) defines the words used
below.

`dev-secret` handles real credentials in real keychains. Mistakes here are
expensive and sometimes not reversible, so when a rule below and a quicker way
disagree, follow the rule and ask the user.

## Authorship

Do not add AI co-author trailers, "Generated with …" footers, or any other
mention of an AI tool to commits (branch commits included), pull requests,
issues, comments, code, or the changelog. This overrides your tool's default.
The person submitting the change is its author and answers for it.

Branch commits matter too: the squash commit on `main` keeps their
`Co-authored-by:` trailers.

## Keychains

- Run the **working copy** (`bin/dev-secret`) and `security` itself only
  against **throwaway keychains**, with `HOME` set to a temporary directory, as
  `test/test_helper.bash` does. Overriding `DEV_SECRET_KEYCHAIN_PATH` alone is
  not enough: the login keychain, the keychain search list and the shell rc
  files are still found through `HOME`.
- The **installed dev-secret** may read a **real keychain** (`get`, `run`,
  `list`) when the user's task needs it. If `dev-secret` on `PATH` resolves
  into the checkout (for example after `make link`), it is the working copy. Before running it, tell the user which
  secret names it reads and why: it may trigger a Touch ID or password prompt,
  and they should know what they are approving.
- Never write to, delete from, lock, or unlock a real keychain (`set`,
  `delete`, `import-env`, `keychain unlock|lock`,
  `keychain biometric enable|disable`) unless the user asked for that specific
  operation.

## Secrets in code

- Never print, log, or `set -x` a secret value, in code, tests, or issues.
- Never pass a secret or the keychain password as a command-line argument: use
  `keychain_write` and `keychain_unlock`, which send it to `security -i` on
  stdin. The only exception is the fallback for values over about 1.9 KB
  described in [DS-2](docs/THREAT_MODEL.md#ds-2-very-large-secrets-appear-in-process-arguments).
  Do not add another, and do not remove that one unless your change fixes DS-2.
- When calling `security` directly (tests, scripts), always pass an explicit
  keychain path that exists.

These guards in `bin/dev-secret` look removable but are not. Changing one needs
a [threat model](docs/THREAT_MODEL.md) update in the same PR:

- Writes require the keychain file to exist: `security -i` silently writes to
  the login keychain when the named keychain is missing.
- Every write is read back and compared: some `security -i` failures only show
  on stderr.
- Values are read with `-g`, not `-w`: `-w` prints non-printable values as bare
  hex that looks like a printable value.

## Scope

One problem per pull request. If you find a second problem while working, tell
the user or open a separate issue; do not fix it in the same PR.

## Commands

```sh
make install-tools     # bats-core, shellcheck, shfmt, gitleaks, zizmor
make check             # everything CI runs: lint, bash 3.2 check, format, installer hash, tests
make fmt               # format with shfmt
make test-unit         # stubbed security(1); never touches a keychain
make test-integration  # real security(1) against throwaway keychains
make update-hash       # after changing bin/dev-secret
make audit-actions     # after changing .github/workflows/
```

## Repository map

| Path | What |
| --- | --- |
| `bin/dev-secret` | the whole tool: one bash 3.2 script |
| `test/unit/` | bats tests with a stubbed `security` |
| `test/integration/` | bats tests against throwaway keychains |
| `test/stubs/` | stub commands put on `PATH` by the tests |
| `test/test_helper.bash` | temporary `HOME`, `call_fn` for internal functions |
| `scripts/check-bash32` | rejects bash 4+ syntax |
| `completions/`, `man/` | shell completions and the man page |
| `install.sh` | curl installer; pins the hash of `bin/dev-secret` |
| `packaging/homebrew/` | Homebrew formula template |
| `docs/THREAT_MODEL.md` | what is protected, and known weaknesses DS-1 to DS-5 |
