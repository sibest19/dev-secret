.PHONY: check test

check:
	bash -n bin/dev-secret install.sh
	command -v shellcheck >/dev/null && shellcheck bin/dev-secret install.sh || true
	command -v shfmt >/dev/null && shfmt -d bin/dev-secret install.sh || true

test:
	command -v bats >/dev/null && bats test || echo "bats not installed; skipping"