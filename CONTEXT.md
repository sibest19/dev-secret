# dev-secret

A command-line tool that keeps developer secrets in macOS keychains and hands them
to commands without exposing them. This glossary fixes the words contributors,
human or agent, use when talking about it.

## Language

### Keychains

**Real keychain**:
Any keychain under the user's actual home directory: the login keychain, the
dev-secret keychain, or any other.
_Avoid_: user keychain, production keychain

**Throwaway keychain**:
A keychain created in a temporary directory for a test or an experiment, and
deleted afterwards.
_Avoid_: test keychain, fake keychain

### Builds

**Working copy**:
The `dev-secret` script in a checkout of this repository, possibly modified and
not yet reviewed.
_Avoid_: dev build, local build

**Installed dev-secret**:
A released `dev-secret` the user installed and runs day to day.
_Avoid_: system dev-secret, production build
