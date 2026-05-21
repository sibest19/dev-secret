.PHONY: install install-tools check lint fmt fmt-check test

SCRIPT_FILES := bin/dev-secret install.sh

install:
	chmod +x bin/dev-secret
	mkdir -p ~/.local/bin
	ln -sf "$(PWD)/bin/dev-secret" ~/.local/bin/dev-secret

install-tools:
	brew install shellcheck shfmt bats-core

check: fmt-check lint
	bash -n $(SCRIPT_FILES)

lint:
	shellcheck $(SCRIPT_FILES)

fmt:
	shfmt -w $(SCRIPT_FILES)

fmt-check:
	shfmt -d $(SCRIPT_FILES)

test:
	bats test
