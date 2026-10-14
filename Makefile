PREFIX  ?= $(HOME)/.local
BINDIR  ?= $(PREFIX)/bin
MANDIR  ?= $(PREFIX)/share/man/man1
BASHCOMPDIR ?= $(PREFIX)/etc/bash_completion.d
ZSHCOMPDIR  ?= $(PREFIX)/share/zsh/site-functions

SHELL_SOURCES := bin/dev-secret install.sh completions/dev-secret.bash test/test_helper.bash \
	scripts/check-bash32 $(wildcard test/stubs/*/*)
# Files that run under macOS bash 3.2: the script, the curl installer, test
# stubs, and bash completion (sourced into the user's bash, often /bin/bash).
BASH32_SOURCES := bin/dev-secret install.sh completions/dev-secret.bash $(wildcard test/stubs/*/*)
BATS_SOURCES  := $(wildcard test/unit/*.bats test/integration/*.bats)

.PHONY: help check lint fmt fmt-check test test-unit test-integration check-hash update-hash \
	secrets-scan audit-actions version install-tools install link uninstall

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check: lint fmt-check check-hash test ## Everything CI runs

lint: ## ShellCheck plus the bash 3.2 compatibility check
	shellcheck $(SHELL_SOURCES) $(BATS_SOURCES)
	scripts/check-bash32 $(BASH32_SOURCES)

fmt: ## Format sources in place with shfmt
	shfmt -w $(SHELL_SOURCES) $(BATS_SOURCES)

fmt-check: ## Fail if sources are not shfmt-formatted
	shfmt -d $(SHELL_SOURCES) $(BATS_SOURCES)

test: test-unit test-integration ## Run all tests

test-unit: ## Fast tests; never touch a real keychain
	bats test/unit

test-integration: ## Tests against a throwaway keychain (macOS only)
	bats test/integration

check-hash: ## Fail if install.sh does not pin the current bin/dev-secret version and hash
	@expected=$$(grep '^EXPECTED_SHA256=' install.sh | sed 's/EXPECTED_SHA256="//;s/"//'); \
	actual=$$(shasum -a 256 bin/dev-secret | awk '{print $$1}'); \
	pinned_version=$$(sed -n 's/^VERSION="\(.*\)"$$/\1/p' install.sh); \
	version=$$($(MAKE) -s version); \
	if [ "$$expected" != "$$actual" ] || [ "$$pinned_version" != "$$version" ]; then \
		printf 'install.sh does not pin bin/dev-secret\n  pinned:  %s %s\n  actual:  %s %s\n  Fix: make update-hash\n' \
			"$$pinned_version" "$$expected" "$$version" "$$actual" >&2; \
		exit 1; \
	fi; \
	printf 'Hash OK: %s %s\n' "$$version" "$$actual"

update-hash: ## Pin the current bin/dev-secret version and hash in install.sh
	@hash=$$(shasum -a 256 bin/dev-secret | awk '{print $$1}'); \
	version=$$($(MAKE) -s version); \
	sed -i '' -e "s/^EXPECTED_SHA256=.*/EXPECTED_SHA256=\"$$hash\"/" \
		-e "s/^VERSION=.*/VERSION=\"$$version\"/" install.sh; \
	printf 'Updated install.sh → %s %s\n' "$$version" "$$hash"

secrets-scan: ## Scan git history for committed secrets
	gitleaks git --redact --no-banner

audit-actions: ## Audit GitHub Actions workflows with zizmor
	zizmor --no-progress --persona=auditor .github/workflows/

version: ## Print the version declared in bin/dev-secret
	@sed -n 's/^VERSION="\(.*\)"$$/\1/p' bin/dev-secret

install-tools: ## Install development tools with Homebrew
	brew install bats-core shellcheck shfmt gitleaks zizmor

install: ## Copy script, man page and completions into $(PREFIX) (default ~/.local)
	install -d $(DESTDIR)$(BINDIR) $(DESTDIR)$(MANDIR) $(DESTDIR)$(BASHCOMPDIR) $(DESTDIR)$(ZSHCOMPDIR)
	install -m 755 bin/dev-secret $(DESTDIR)$(BINDIR)/dev-secret
	install -m 644 man/dev-secret.1 $(DESTDIR)$(MANDIR)/dev-secret.1
	install -m 644 completions/dev-secret.bash $(DESTDIR)$(BASHCOMPDIR)/dev-secret
	install -m 644 completions/_dev-secret $(DESTDIR)$(ZSHCOMPDIR)/_dev-secret

link: ## Symlink bin/dev-secret into $(BINDIR), for development
	install -d $(BINDIR)
	ln -sf "$(CURDIR)/bin/dev-secret" $(BINDIR)/dev-secret

uninstall: ## Remove files installed by `make install` or `make link`
	rm -f $(DESTDIR)$(BINDIR)/dev-secret $(DESTDIR)$(MANDIR)/dev-secret.1 \
		$(DESTDIR)$(BASHCOMPDIR)/dev-secret $(DESTDIR)$(ZSHCOMPDIR)/_dev-secret
