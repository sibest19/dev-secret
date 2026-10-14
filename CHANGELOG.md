# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-10-14

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
- Secret values and the keychain password no longer appear in process arguments,
  where `ps` shows them to other local users: they are sent to `security -i` on
  stdin, and `run` passes values through the environment. Values over about
  1.9 KB still use an argument, with a warning ([#6](https://github.com/sibest19/dev-secret/issues/6)).
- `keychain biometric enable` failed when re-enrolling an existing Touch ID
  credential ([#4](https://github.com/sibest19/dev-secret/issues/4)).
- `set --stdin` stored trailing newlines, and `get`/`run` returned any value
  containing a newline, tab or non-ASCII character as hex. Trailing
  newlines are now dropped on input, and values are read back byte-exact,
  including ones stored by earlier versions ([#1](https://github.com/sibest19/dev-secret/issues/1)).
- `init` corrupted the user keychain search list: indented `security list-keychains`
  output was parsed wrongly, so every run added mangled paths and duplicated the
  dedicated keychain.
- `init` aborted with "unbound variable" on bash 3.2 when the search list was empty.
- `set` failed (or showed a GUI authorization prompt) when overwriting an existing
  secret.

## [0.1.0]

Initial version (`c2f59b8`), installed from `main` with `install.sh`; never tagged.

[Unreleased]: https://github.com/sibest19/dev-secret/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/sibest19/dev-secret/releases/tag/v0.2.0
[0.1.0]: https://github.com/sibest19/dev-secret/tree/c2f59b8
