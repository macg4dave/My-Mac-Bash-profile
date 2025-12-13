.PHONY: lint test

SHELLCHECK ?= shellcheck

# Keep flags conservative to avoid noisy style churn.
SHELLCHECK_FLAGS ?= --shell=bash

LINT_FILES := \
	.bash_profile \
	profile.d/*.sh \
	tests/*.sh \
	scripts/*.sh

lint:
	@$(SHELLCHECK) $(SHELLCHECK_FLAGS) $(LINT_FILES)

test:
	@bash tests/smoke.sh
