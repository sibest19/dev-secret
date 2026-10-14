# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Repository scaffolding: bats test suites (unit and integration), ShellCheck and
  shfmt checks, CI and release workflows, man page, bash and zsh completions,
  Homebrew formula template.
- `scripts/check-bash32`, run by `make lint`, rejects bash 4+ syntax.
- `SECURITY.md` and `docs/THREAT_MODEL.md`, documenting known weaknesses DS-1 to DS-5.

### Changed

- The script now runs under `/bin/bash` (macOS's bash 3.2) instead of whichever
  `bash` comes first on `PATH`.

### Fixed

- `import-env` stored whitespace before an inline comment, a whole comment after a
  tab, and the quote characters of a quoted value followed by a comment or
  trailing spaces as part of the secret ([#2](https://github.com/sibest19/dev-secret/issues/2)).
- `init` corrupted the user keychain search list: indented `security list-keychains`
  output was parsed wrongly, so every run added mangled paths and duplicated the
  dedicated keychain.
- `init` aborted with "unbound variable" on bash 3.2 when the search list was empty.
- `set` failed (or showed a GUI authorization prompt) when overwriting an existing
  secret.

## [0.1.0]

Initial version, distributed as a standalone script before this repository existed.

[Unreleased]: https://github.com/sibest19/dev-secret/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sibest19/dev-secret/releases/tag/v0.1.0
