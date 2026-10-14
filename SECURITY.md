# Security policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Report privately through GitHub:
[**Report a vulnerability**](https://github.com/sibest19/dev-secret/security/advisories/new).

Include what you found, how to reproduce it, and the impact you expect. Never
include real secret values; a placeholder like `ghp_EXAMPLE` is enough.

You can expect an acknowledgement within 7 days. Once a fix is released, the
advisory is published with credit to you, unless you prefer to stay anonymous.

## Supported versions

Only the latest release receives security fixes.

## Scope

[docs/THREAT_MODEL.md](docs/THREAT_MODEL.md) describes what `dev-secret` is meant to
protect against and lists known weaknesses. Reports about issues already listed
there are still welcome if you have a concrete fix or a more serious impact than
documented.

## Verifying what you run

`dev-secret` is a single Bash script with no runtime dependencies besides macOS
base tools. You can read the whole thing at `bin/dev-secret` before installing it.
Releases are created only from signed tags on `main`.
