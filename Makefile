SHELL := /bin/bash

V2_SHELL_FILES := \
	bin/kdm \
	lib/core.sh \
	lib/log.sh \
	lib/config.sh \
	lib/inventory.sh \
	lib/validation.sh \
	lib/ssh.sh \
	lib/safety.sh \
	tests/test_helper.sh \
	tests/helpers/fake-ssh \
	tests/unit/config.sh \
	tests/unit/inventory.sh \
	tests/unit/log.sh \
	tests/unit/safety.sh \
	tests/unit/ssh.sh \
	tests/smoke/cli.sh \
	tests/smoke/doctor.sh \
	tests/smoke/no-side-effects.sh

.PHONY: doctor lint smoke unit test

doctor:
	@./bin/kdm doctor

lint:
	@set -e; \
	for file in $(V2_SHELL_FILES); do \
		bash -n "$$file"; \
		printf 'PASS bash -n %s\n' "$$file"; \
	done; \
	if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x -P SCRIPTDIR bin/kdm tests/unit/*.sh tests/smoke/*.sh; \
	else \
		printf 'SKIP shellcheck (not installed)\n'; \
	fi; \
	if command -v actionlint >/dev/null 2>&1; then \
		actionlint .github/workflows/*.yml; \
	else \
		printf 'SKIP actionlint (not installed)\n'; \
	fi

smoke:
	@set -e; \
	for test_file in tests/smoke/*.sh; do \
		bash "$$test_file"; \
	done

unit:
	@set -e; \
	for test_file in tests/unit/*.sh; do \
		bash "$$test_file"; \
	done

test: lint unit smoke
