# dev-secret

Small macOS Keychain-backed helper for local development secrets.

`dev-secret` stores secrets in the native macOS Keychain and injects them into commands only when needed.

Instead of keeping tokens in `~/.zshrc`, `~/.zprofile`, `.env`, or other plaintext shell files, you store them once in Keychain and run commands with explicit secret access.

## Why

Avoid this:

```bash
export GITHUB_TOKEN=...
export SENTRY_AUTH_TOKEN=...
export NODE_AUTH_TOKEN=$(gh auth token)
````

Prefer this:

```bash
dev-secret run GITHUB_TOKEN -- gh auth status
dev-secret run NODE_AUTH_TOKEN -- npm publish
dev-secret run GITHUB_TOKEN SENTRY_AUTH_TOKEN -- ./scripts/release.sh
```

The secret is available only to the child process started by `dev-secret run`.

## Requirements

* macOS
* Bash
* macOS `security` command
* Optional for development:

  * `shellcheck`
  * `shfmt`
  * `bats`

## Install locally for development

From the repo root:

```bash
chmod +x bin/dev-secret

mkdir -p ~/.local/bin
ln -sf "$PWD/bin/dev-secret" ~/.local/bin/dev-secret
```

Make sure `~/.local/bin` is in your `PATH`:

```bash
echo $PATH | tr ':' '\n' | grep -qx "$HOME/.local/bin" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Verify:

```bash
which dev-secret
dev-secret doctor
```

## Install from repo

```bash
SCRIPT_DOWNLOAD_URL="https://raw.githubusercontent.com/sibest19/dev-secret/main/bin/dev-secret"
```

Then:

```bash
curl -fsSL https://raw.githubusercontent.com/sibest19/dev-secret/main/install.sh -o /tmp/dev-secret-install.sh
bash /tmp/dev-secret-install.sh
```

The installer writes to:

```text
~/.local/bin/dev-secret
```

It does not require `sudo`.

## Initialize

```bash
dev-secret init
```

Or initialize with a defaults file:

```bash
dev-secret init --defaults defaults/homeruntech
```

By default, `dev-secret` uses a dedicated keychain:

```text
~/Library/Keychains/dev-secrets.keychain-db
```

You can override this:

```bash
export DEV_SECRET_KEYCHAIN_NAME="my-dev-secrets"
export DEV_SECRET_KEYCHAIN_PATH="$HOME/Library/Keychains/my-dev-secrets.keychain-db"
```

## Commands

```bash
dev-secret init [--defaults FILE]
dev-secret set NAME [--stdin]
dev-secret get NAME
dev-secret run NAME [NAME ...] -- command [args...]
dev-secret list
dev-secret delete NAME
dev-secret doctor
dev-secret scan-env [FILE ...]
dev-secret import-env [--yes] [FILE ...]
dev-secret help
dev-secret version
```

## Store a secret

Interactive prompt:

```bash
dev-secret set GITHUB_TOKEN
```

From stdin:

```bash
gh auth token | dev-secret set GITHUB_TOKEN --stdin
```

Another example:

```bash
printf '%s' "$SENTRY_AUTH_TOKEN" | dev-secret set SENTRY_AUTH_TOKEN --stdin
```

## Read a secret

```bash
dev-secret get GITHUB_TOKEN
```

Use this carefully. It prints the secret to stdout.

Prefer `dev-secret run` for normal usage.

## Run a command with one secret

```bash
dev-secret run GITHUB_TOKEN -- gh auth status
```

```bash
dev-secret run NODE_AUTH_TOKEN -- npm publish
```

## Run a command with multiple secrets

```bash
dev-secret run GITHUB_TOKEN SENTRY_AUTH_TOKEN -- ./scripts/release.sh
```

```bash
dev-secret run NODE_AUTH_TOKEN CLAUDE_CODE_GITHUB_TOKEN CRODENO_GITHUB_TOKEN -- ./scripts/dev-task.sh
```

Internally this behaves like:

```bash
env GITHUB_TOKEN=value SENTRY_AUTH_TOKEN=value ./scripts/release.sh
```

The secrets are passed only to the child process.

They are not exported globally into your shell.

## List secrets

```bash
dev-secret list
```

This prints only secret names, not values.

## Delete a secret

```bash
dev-secret delete GITHUB_TOKEN
```

Alias:

```bash
dev-secret rm GITHUB_TOKEN
```

## Check setup

```bash
dev-secret doctor
```

This checks:

* macOS
* `security` command availability
* config directory
* keychain existence

## Defaults file

Defaults are stored in:

```text
~/.config/dev-secret/defaults
```

Format:

```text
GITHUB_TOKEN
SENTRY_AUTH_TOKEN
DRONE_TOKEN
REDASH_TOKEN
```

One secret name per line.

You can provide a repo-managed defaults file:

```bash
dev-secret init --defaults defaults/prontopro
```

## Scan shell files for plaintext secrets

```bash
dev-secret scan-env
```

By default, this scans:

```text
~/.zshrc
~/.zprofile
~/.zshenv
~/.profile
~/.bash_profile
~/.bashrc
```

You can scan specific files:

```bash
dev-secret scan-env ~/.zshrc ~/.zprofile
```

Example output:

```text
/Users/simo/.zshrc:42:GITHUB_TOKEN:plaintext
/Users/simo/.zshrc:43:NODE_AUTH_TOKEN:dynamic command substitution detected; skipped by import-env
```

`scan-env` does not print secret values.

## Import plaintext env secrets

```bash
dev-secret import-env
```

This:

1. scans shell config files;
2. imports plaintext values into Keychain;
3. creates a backup file;
4. removes the plaintext value from the original file.

Example:

```bash
export GITHUB_TOKEN="abc123"
```

Becomes:

```bash
# dev-secret imported GITHUB_TOKEN and removed plaintext value
```

A backup is created next to the original file:

```text
~/.zshrc.bak.dev-secret.20260521-143012
```

To skip confirmation:

```bash
dev-secret import-env --yes
```

To import from specific files:

```bash
dev-secret import-env ~/.zshrc ~/.zprofile
```

## Dynamic shell assignments

`import-env` intentionally skips dynamic assignments like:

```bash
export NODE_AUTH_TOKEN=$(gh auth token)
export CLAUDE_CODE_GITHUB_TOKEN=$(gh auth token)
export CRODENO_GITHUB_TOKEN=$(gh auth token)
```

These are not plaintext values. They are command substitutions.

Import them manually:

```bash
gh auth token | dev-secret set NODE_AUTH_TOKEN --stdin
gh auth token | dev-secret set CLAUDE_CODE_GITHUB_TOKEN --stdin
gh auth token | dev-secret set CRODENO_GITHUB_TOKEN --stdin
```

Then remove these lines from your shell config:

```bash
export NODE_AUTH_TOKEN=$(gh auth token)
export CLAUDE_CODE_GITHUB_TOKEN=$(gh auth token)
export CRODENO_GITHUB_TOKEN=$(gh auth token)
```

Reload your shell:

```bash
source ~/.zshrc
```

Confirm they are no longer globally exported:

```bash
env | grep -E '^(NODE_AUTH_TOKEN|CLAUDE_CODE_GITHUB_TOKEN|CRODENO_GITHUB_TOKEN)=' || echo "not loaded globally"
```

Then use them only when needed:

```bash
dev-secret run NODE_AUTH_TOKEN -- npm publish
dev-secret run CLAUDE_CODE_GITHUB_TOKEN -- claude
dev-secret run CRODENO_GITHUB_TOKEN -- crodeno check-for-updates
```

## Development

Run checks:

```bash
make check
```

Run tests:

```bash
make test
```

Recommended checks:

```bash
bash -n bin/dev-secret install.sh
shellcheck bin/dev-secret install.sh
shfmt -d bin/dev-secret install.sh
bats test
```

## Local test keychain

For development, avoid touching your real keychain:

```bash
export DEV_SECRET_KEYCHAIN_NAME="dev-secret-local-test"
export DEV_SECRET_KEYCHAIN_PATH="$HOME/Library/Keychains/dev-secret-local-test.keychain-db"

dev-secret init
```

Then test normally:

```bash
dev-secret set TEST_TOKEN
dev-secret run TEST_TOKEN -- sh -c 'test -n "$TEST_TOKEN" && echo ok'
```

## Security notes

`dev-secret` is for local developer-machine secrets.

It is not a replacement for:

* 1Password
* Vault
* AWS Secrets Manager
* Doppler
* CI/CD secret stores
* production secret management

Main rules:

* do not store secrets in plaintext shell files;
* do not auto-export secrets globally in `~/.zshrc`;
* prefer `dev-secret run` over `dev-secret get`;
* rotate tokens that were previously stored in plaintext;
* avoid printing secrets to the terminal;
* avoid copying secrets to clipboard unless absolutely needed.

## Environment variables

| Variable                    | Default                                       | Description             |
| --------------------------- | --------------------------------------------- | ----------------------- |
| `DEV_SECRET_KEYCHAIN_NAME`  | `dev-secrets`                                 | Dedicated keychain name |
| `DEV_SECRET_KEYCHAIN_PATH`  | `~/Library/Keychains/dev-secrets.keychain-db` | Full keychain path      |
| `DEV_SECRET_CONFIG_DIR`     | `~/.config/dev-secret`                        | Config directory        |
| `DEV_SECRET_DEFAULTS_FILE`  | `~/.config/dev-secret/defaults`               | Defaults file           |
| `DEV_SECRET_SERVICE_PREFIX` | `com.prontopro.dev-secret`                    | Keychain service prefix |

## Examples

GitHub:

```bash
gh auth token | dev-secret set GITHUB_TOKEN --stdin
dev-secret run GITHUB_TOKEN -- gh auth status
```

NPM:

```bash
gh auth token | dev-secret set NODE_AUTH_TOKEN --stdin
dev-secret run NODE_AUTH_TOKEN -- npm whoami
```

Sentry:

```bash
dev-secret set SENTRY_AUTH_TOKEN
dev-secret run SENTRY_AUTH_TOKEN -- sentry-cli releases list
```

Release script with multiple secrets:

```bash
dev-secret run GITHUB_TOKEN SENTRY_AUTH_TOKEN NODE_AUTH_TOKEN -- ./scripts/release.sh
```

## Uninstall

Remove the binary:

```bash
rm -f ~/.local/bin/dev-secret
```

Remove config:

```bash
rm -rf ~/.config/dev-secret
```

Delete the dedicated keychain manually from Keychain Access, or with:

```bash
security delete-keychain "$HOME/Library/Keychains/dev-secrets.keychain-db"
```

Be careful: deleting the keychain deletes all secrets stored in it.
