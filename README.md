# dev-secret

[![CI](https://github.com/sibest19/dev-secret/actions/workflows/ci.yml/badge.svg)](https://github.com/sibest19/dev-secret/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/sibest19/dev-secret/badge)](https://scorecard.dev/viewer/?uri=github.com/sibest19/dev-secret)

Keep developer secrets out of your dotfiles. `dev-secret` stores tokens and
passwords in a dedicated macOS keychain and hands them to **one command at a
time** as environment variables.

```console
$ dev-secret set GITHUB_TOKEN
Enter value for GITHUB_TOKEN:
Confirm value for GITHUB_TOKEN:
Stored GITHUB_TOKEN.

$ dev-secret run GITHUB_TOKEN -- gh auth status
```

- **No plaintext at rest.** Secrets live in an encrypted keychain, not in `~/.zshrc`.
- **Scoped exposure.** `run` gives secrets to a single process, not to every shell.
- **Easy migration.** `scan-env` finds plaintext secrets in your rc files and
  `import-env` moves them into the keychain.
- **Auditable.** One Bash script, no dependencies beyond macOS's `security(1)`.

## Requirements

- macOS (uses the built-in `/bin/bash` and `security`)
- `swift`, only for Touch ID unlock: `xcode-select --install`

## Install

With the installer, which verifies the script's SHA256 before installing it into
`~/.local/bin`:

```sh
curl -fsSL https://raw.githubusercontent.com/sibest19/dev-secret/main/install.sh | bash
```

From source, which also installs the man page and shell completions:

```sh
git clone https://github.com/sibest19/dev-secret.git
cd dev-secret
make install                 # into ~/.local; or: make install PREFIX=/usr/local
```

Homebrew is planned. Make sure `~/.local/bin` is in your `PATH`.

## Usage

```
dev-secret init [--defaults FILE]
dev-secret set NAME [--stdin]
dev-secret get NAME
dev-secret run NAME [NAME ...] -- command [args...]
dev-secret list
dev-secret delete NAME
dev-secret keychain biometric enable|disable|status
dev-secret keychain lock|unlock|status
dev-secret doctor
dev-secret scan-env [FILE ...]
dev-secret import-env [--yes] [FILE ...]
```

See `man dev-secret` for details.

### Store a secret

```sh
dev-secret set GITHUB_TOKEN                               # interactive prompt
gh auth token | dev-secret set GITHUB_TOKEN --stdin          # from stdin
```

With `--stdin`, trailing newlines are dropped, so `echo "$TOKEN" | dev-secret set …` is fine.
Any other byte is stored and returned exactly, including tabs, newlines inside the
value and non-ASCII text.

### Run a command with secrets

```sh
dev-secret run GITHUB_TOKEN -- gh auth status
dev-secret run GITHUB_TOKEN SENTRY_AUTH_TOKEN -- ./scripts/release.sh
```

Secrets are passed only to the child process, not exported into your shell. For
tools you use often, wrap them in a shell function:

```zsh
ghw() { dev-secret run GITHUB_TOKEN -- gh "$@"; }
```

### Import from shell config

```sh
dev-secret scan-env          # preview what would be imported; never prints values
dev-secret import-env        # import plaintext secrets, rewrite files, create backups
dev-secret import-env --yes  # skip confirmation
```

Dynamic assignments like `export TOKEN=$(gh auth token)` are skipped; import those
manually with `--stdin`.

### Keychain and Touch ID

```sh
dev-secret keychain lock                # lock now instead of waiting for the 1h timeout
dev-secret keychain unlock
dev-secret keychain status

dev-secret keychain biometric enable    # enroll Touch ID unlock
dev-secret keychain biometric disable
dev-secret keychain biometric status
```

With Touch ID enabled, unlocking shows a `LocalAuthentication` prompt; on success
the keychain password is read from the login keychain and used to unlock. `init`
offers enrollment when Touch ID is available. Touch ID is a convenience, not a
security boundary; see [Security](#security).

If macOS locks Touch ID after too many failed attempts, `dev-secret` says so and
asks for the keychain password instead. Enter your Mac password once (for
example, lock and unlock the screen) to re-enable Touch ID; `dev-secret doctor`
shows the current state.

## Defaults file

`~/.config/dev-secret/defaults` lists one secret name per line. Install a team
list with:

```sh
dev-secret init --defaults defaults/homeruntech
```

## Environment variables

| Variable                    | Default                                       |
| --------------------------- | --------------------------------------------- |
| `DEV_SECRET_KEYCHAIN_NAME`  | `dev-secrets`                                 |
| `DEV_SECRET_KEYCHAIN_PATH`  | `~/Library/Keychains/dev-secrets.keychain-db` |
| `DEV_SECRET_CONFIG_DIR`     | `~/.config/dev-secret`                        |
| `DEV_SECRET_DEFAULTS_FILE`  | `~/.config/dev-secret/defaults`               |
| `DEV_SECRET_SERVICE_PREFIX` | `it.simoneandreani.dev-secret`                |

## Uninstall

```sh
make uninstall    # if installed from source; otherwise: rm -f ~/.local/bin/dev-secret
rm -rf ~/.config/dev-secret
security delete-keychain "$HOME/Library/Keychains/dev-secrets.keychain-db"
security delete-generic-password -a keychain-password -s it.simoneandreani.dev-secret.keychain-unlock \
  ~/Library/Keychains/login.keychain-db 2>/dev/null || true
```

`delete-keychain` permanently deletes every stored secret.

## Security

Read [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md) before relying on this tool. In
short: it protects secrets at rest and limits which processes see them; it does
**not** protect against malware running as your user, and Touch ID unlock is a
convenience rather than a security boundary.

Report vulnerabilities privately; see [SECURITY.md](SECURITY.md).

## Development

```sh
make install-tools  # bats-core, shellcheck, shfmt, gitleaks, zizmor via Homebrew
make check          # lint + bash 3.2 check + format check + installer hash + all tests
make link           # symlink bin/dev-secret into ~/.local/bin while developing
make help           # list targets
```

Tests never touch your real keychain: integration tests create throwaway
keychains under a temporary `HOME`. After changing `bin/dev-secret`, run
`make update-hash` so `install.sh` pins the new version. See
[CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
