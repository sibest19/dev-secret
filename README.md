# dev-secret

macOS Keychain-backed helper for local development secrets.

Stores secrets in the native macOS Keychain and injects them into commands only when needed — no plaintext tokens in shell config files.

## Quick start

```bash
dev-secret init
dev-secret set GITHUB_TOKEN
dev-secret run GITHUB_TOKEN -- gh auth status
```

## Commands

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

## Usage

### Store a secret

```bash
dev-secret set GITHUB_TOKEN                              # interactive prompt
gh auth token | dev-secret set GITHUB_TOKEN --stdin      # from stdin
```

### Run a command with secrets

```bash
dev-secret run GITHUB_TOKEN -- gh auth status
dev-secret run GITHUB_TOKEN SENTRY_AUTH_TOKEN -- ./scripts/release.sh
```

Secrets are passed only to the child process — not exported globally into your shell.

### Import from shell config

```bash
dev-secret scan-env          # preview what would be imported
dev-secret import-env        # import plaintext secrets, rewrite files, create backups
dev-secret import-env --yes  # skip confirmation
```

Skips dynamic assignments like `export TOKEN=$(gh auth token)` — import those manually with `--stdin`.

### Touch ID

```bash
dev-secret keychain biometric enable   # enroll Touch ID unlock
dev-secret keychain biometric disable  # remove enrollment
dev-secret keychain biometric status   # show Touch ID availability and enabled state
```

After enabling, any keychain unlock triggers an explicit Touch ID prompt via `LocalAuthentication`. If Touch ID succeeds, the password is retrieved silently from the login keychain and used to unlock. Requires `swift` (Xcode CLT).

`init` offers to enable biometric unlock automatically if Touch ID is available.

### Keychain

```bash
dev-secret keychain lock
dev-secret keychain unlock
dev-secret keychain status
```

## Defaults file

Stored at `~/.config/dev-secret/defaults`. One secret name per line.

```bash
dev-secret init --defaults defaults/myteam
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/sibest19/dev-secret/main/install.sh | bash
```

Or clone and link locally:

```bash
make install        # symlinks bin/dev-secret into ~/.local/bin
```

Make sure `~/.local/bin` is in your `PATH`.

## Requirements

- macOS
- `bash`, `security` (built-in on macOS)
- `swift` — optional, required for biometric unlock (`xcode-select --install`)

## Environment variables

| Variable                    | Default                                             |
| --------------------------- | --------------------------------------------------- |
| `DEV_SECRET_KEYCHAIN_NAME`  | `dev-secrets`                                       |
| `DEV_SECRET_KEYCHAIN_PATH`  | `~/Library/Keychains/dev-secrets.keychain-db`       |
| `DEV_SECRET_CONFIG_DIR`     | `~/.config/dev-secret`                              |
| `DEV_SECRET_DEFAULTS_FILE`  | `~/.config/dev-secret/defaults`                     |
| `DEV_SECRET_SERVICE_PREFIX` | `it.simoneandreani.dev-secret`                      |

## Uninstall

```bash
rm -f ~/.local/bin/dev-secret
rm -rf ~/.config/dev-secret
security delete-keychain "$HOME/Library/Keychains/dev-secrets.keychain-db"
security delete-generic-password -a keychain-password -s it.simoneandreani.dev-secret.keychain-unlock \
  ~/Library/Keychains/login.keychain-db 2>/dev/null || true
```

---

## Development

```bash
make install-tools  # installs shellcheck, shfmt, bats-core via brew
make check          # syntax check + lint + format diff
make fmt            # format in place
make lint           # shellcheck only
make test           # bats
```

### Local test keychain

```bash
export DEV_SECRET_KEYCHAIN_NAME="dev-secret-test"
export DEV_SECRET_KEYCHAIN_PATH="$HOME/Library/Keychains/dev-secret-test.keychain-db"
dev-secret init
```
