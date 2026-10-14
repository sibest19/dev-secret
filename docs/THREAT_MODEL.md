# Threat model

This document states what `dev-secret` protects, what it deliberately does not,
and the known weaknesses that have not been fixed yet. If you find a gap that
is not listed here, please report it as described in [SECURITY.md](../SECURITY.md).

## What it is

A Bash wrapper around macOS `security(1)`. Secrets live as generic-password items
in a dedicated keychain (`~/Library/Keychains/dev-secrets.keychain-db`), and are
handed to one child process as environment variables by `dev-secret run`.

No network access, no daemons, no runtime dependencies beyond macOS base tools.

## Assets

- Secret values (API tokens, passwords) stored in the dedicated keychain.
- The dedicated keychain's password.
- The user's shell rc files, which `import-env` rewrites.

## In scope: what it protects against

| Threat | Mitigation |
| --- | --- |
| Secrets sitting in plaintext in `~/.zshrc`, `.env`-style files, dotfile repos and backups | Values are stored encrypted in a keychain; `scan-env` / `import-env` help migrate them out |
| Secrets exported into every shell session and inherited by every process | `run` scopes secrets to a single child process |
| Disk theft or offline copy of the home directory | Keychain file is encrypted with its own password |
| Long-lived unlocked access | The dedicated keychain auto-locks after 1 hour (`set-keychain-settings -lut 3600`) |
| Shell injection via secret names | Names are restricted to `[A-Za-z_][A-Za-z0-9_]*` before any use |
| Data loss when cleaning rc files | `import-env` writes a `0600` backup of every file it changes |

## Out of scope

- **Malware running as your user.** While the dedicated keychain is unlocked, any
  process running as you can read its items, because they are created with
  `-A` (any application may read them without a prompt). Such a process could also
  modify `PATH` to substitute `security` or `swift`. A CLI built on `security(1)`
  cannot defend against a same-user attacker.
- **Root, or a compromised OS.**
- **The child process.** Whatever you pass a secret to with `run` can log, leak,
  or forward it, and so can its own children.

## Known weaknesses

These are tracked here until fixed. Each will get a CHANGELOG entry when
resolved.

### DS-1: Touch ID unlock is a convenience, not a security boundary

`keychain biometric enable` stores the dedicated keychain's password as an item in
the **login** keychain, created with `-A`. The login keychain is unlocked for the
whole login session, so any process running as you can read that password with
`security find-generic-password` and unlock the dedicated keychain without Touch ID.
The Touch ID check only gates `dev-secret`'s own code path.

A real fix needs a keychain item protected by `SecAccessControl` with a biometry
policy, which requires a native, code-signed helper rather than `security(1)`.

### DS-2: Secret values appear in process arguments

- `set` and `import-env` pass the value to `security add-generic-password -w VALUE`.
- `run` uses `env NAME=VALUE command`.

For the lifetime of those processes the value is visible in their argument list,
which `ps` can show to other users on the same machine. Planned fix:
`export` + `exec` for `run`; feed `security -i` over stdin for writes.

### DS-3: Touch ID prompt compiles Swift at runtime

`touchid_authenticate` pipes Swift source to the first `swift` found on `PATH` on
every unlock. That is slow, needs the Xcode Command Line Tools, and trusts `PATH`.
Planned fix: a small prebuilt helper, built by the Homebrew formula.

### DS-4: `get` prints secrets to the terminal

By design, but the value can end up in scrollback, terminal logs, or a pasted
screenshot. Prefer `run`.

### DS-5: `import-env` leaves plaintext backups

Backups are `0600` and the command tells you to delete them, but until you do, the
plaintext secrets still exist on disk.

## Known correctness bugs with security impact

- Values containing non-printable bytes (including a trailing newline, as in
  `echo "$TOKEN" | dev-secret set X --stdin`) are read back by `security -w` as
  **hex**, so `get`/`run` return the wrong value. Tracked by a skipped test in
  `test/integration/keychain.bats`.
- `keychain biometric enable` uses `add-generic-password -U -A`, which fails
  without a GUI prompt when the item already exists, so re-enrolling (for
  example after changing the keychain password) fails. The same issue in `set`
  was fixed; this one is still open.
