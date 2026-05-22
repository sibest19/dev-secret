.PHONY: install install-tools check check-hash update-hash lint fmt fmt-check test

SCRIPT_FILES := bin/dev-secret install.sh

install:
	chmod +x bin/dev-secret
	mkdir -p ~/.local/bin
	ln -sf "$(PWD)/bin/dev-secret" ~/.local/bin/dev-secret

install-tools:
	brew install shellcheck shfmt bats-core

update-hash:
	@hash=$$(shasum -a 256 bin/dev-secret | awk '{print $$1}'); \
	sed -i '' "s/^EXPECTED_SHA256=.*/EXPECTED_SHA256=\"$$hash\"/" install.sh; \
	printf 'Updated EXPECTED_SHA256 → %s\n' "$$hash"

check-hash:
	@expected=$$(grep '^EXPECTED_SHA256=' install.sh | sed 's/EXPECTED_SHA256="//;s/"//'); \
	actual=$$(shasum -a 256 bin/dev-secret | awk '{print $$1}'); \
	if [ "$$expected" != "$$actual" ]; then \
		printf 'Hash mismatch in install.sh\n  pinned:  %s\n  actual:  %s\n  Fix: make update-hash\n' "$$expected" "$$actual" >&2; \
		exit 1; \
	fi; \
	printf 'Hash OK: %s\n' "$$actual"

check: fmt-check lint check-hash
	bash -n $(SCRIPT_FILES)

lint:
	shellcheck $(SCRIPT_FILES)

fmt:
	shfmt -w $(SCRIPT_FILES)

fmt-check:
	shfmt -d $(SCRIPT_FILES)

test:
	bats test
