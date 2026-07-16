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
	lib/host.sh \
	lib/host-facts.sh \
	providers/os/ubuntu-24.04.sh \
	providers/runtime/crio.sh \
	commands/host.sh \
	scripts/guest/kdm-host-facts \
	scripts/lab/provision-host-facts.sh \
	tests/test_helper.sh \
	tests/helpers/fake-ssh \
	tests/helpers/lab-ssh \
	tests/integration/host-facts-lab.sh \
	tests/integration/ssh-lab.sh \
	tests/unit/config.sh \
	tests/unit/host-facts.sh \
	tests/unit/host-preflight.sh \
	tests/unit/host-plan.sh \
	tests/unit/inventory.sh \
	tests/unit/log.sh \
	tests/unit/safety.sh \
	tests/unit/ssh.sh \
	tests/smoke/cli.sh \
	tests/smoke/doctor.sh \
	tests/smoke/no-side-effects.sh

.PHONY: doctor lint smoke unit provision-host-facts integration-host-facts integration-ssh test

doctor:
	@./bin/kdm doctor

lint:
	@set -e; \
	for file in $(V2_SHELL_FILES); do \
		bash -n "$$file"; \
		printf 'PASS bash -n %s\n' "$$file"; \
	done; \
	if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x -P SCRIPTDIR bin/kdm lib/host-facts.sh scripts/guest/* scripts/lab/*.sh tests/helpers/* tests/integration/*.sh tests/unit/*.sh tests/smoke/*.sh; \
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

integration-ssh:
	@bash tests/integration/ssh-lab.sh

provision-host-facts:
	@bash scripts/lab/provision-host-facts.sh

integration-host-facts:
	@bash tests/integration/host-facts-lab.sh

test: lint unit smoke
