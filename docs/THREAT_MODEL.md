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

### DS-2: Very large secrets appear in process arguments

Command lines are visible to other users on the same machine through `ps`, so
secrets and keychain passwords are sent to `security -i` on **stdin**, hex-encoded,
and `run` hands values to the command through its environment (`export` + `exec`)
([#6](https://github.com/sibest19/dev-secret/issues/6)).

`security -i` splits lines longer than 4096 bytes. Values longer than about
1.9 KB (hex doubles their size) therefore fall back to
`security add-generic-password -w VALUE`, and `set` prints a warning: such a
value is visible in the process list for the moment it takes to store it.

Two traps of `security -i` are guarded against: a write naming a missing
keychain file silently goes to the login keychain, so writes require the file to
exist; and some failures only show on stderr, so every write is read back from
the target keychain and compared.

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


None known. Open bugs are tracked in [GitHub issues](https://github.com/sibest19/dev-secret/issues?q=is%3Aissue+is%3Aopen+label%3Abug).
