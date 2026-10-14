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

The `dev-secret` script and the source tarball of each release have a signed
SLSA build provenance attestation, which shows that the release workflow built
them from this repository at the release tag. Verify a download with the
[GitHub CLI](https://cli.github.com/):

```sh
gh attestation verify dev-secret-X.Y.Z.tar.gz --repo sibest19/dev-secret \
  --signer-workflow sibest19/dev-secret/.github/workflows/release.yml
```

From v0.3.0 on, releases also attach the attestation as
`dev-secret-X.Y.Z.intoto.jsonl` (a Sigstore bundle), so you can verify without
querying GitHub's attestations API by adding
`--bundle dev-secret-X.Y.Z.intoto.jsonl`.

The installer is a release asset too, from v0.3.0 on. It installs the
`dev-secret` asset of its own release and refuses one whose SHA256 differs from
the hash pinned in it, so a change on `main` reaches installs only through a
new signed release. To check the installer before running it:

```sh
curl -fsSLO https://github.com/sibest19/dev-secret/releases/latest/download/install.sh
gh attestation verify install.sh --repo sibest19/dev-secret \
  --signer-workflow sibest19/dev-secret/.github/workflows/release.yml
bash install.sh
```
