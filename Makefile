.PHONY: test test-bats test-pytest test-stage-structure bench-replay bench-judge-prompt bench-judge-stats clean help

help:
	@echo "Targets:"
	@echo "  test                  run unit tests (bats + pytest + stage structure)"
	@echo "  test-bats             bash unit tests only (scripts/*)"
	@echo "  test-pytest           markdown invariant tests only (SKILL.md + stages/*)"
	@echo "  test-stage-structure  bash structure tests for each stage file"
	@echo "  bench-replay      validate every historical sprint under \$$SPRINT_HOME against schema"
	@echo "  bench-judge-prompt  emit batch judge prompt for a Claude Code subagent"
	@echo "  bench-judge-stats   compute per-dimension mean/stdev from subagent scores"
	@echo "  clean             remove generated reports"

# Unit tests must pass all three layers.
test: test-bats test-pytest test-stage-structure

test-stage-structure:
	@for s in brainstorm design plan execute review insight; do \
		echo "── stages/$$s.md ──"; \
		bash tests/unit/test-$$s-structure.sh || exit 1; \
	done

test-bats:
	@command -v bats >/dev/null 2>&1 || { \
		echo "bats-core not installed. Install: brew install bats-core"; exit 1; }
	bats tests/unit/test_sprint_ctl.bats tests/unit/test_anchor_check.bats

test-pytest:
	@command -v python3 >/dev/null 2>&1 || { echo "python3 required"; exit 1; }
	@python3 -c "import pytest, markdown_it" 2>/dev/null || { \
		echo "pytest / markdown-it-py missing. Install: pip3 install --system pytest markdown-it-py"; exit 1; }
	python3 -m pytest tests/unit/ -q --ignore=tests/unit/test_sprint_ctl.bats --ignore=tests/unit/test_anchor_check.bats

bench-replay:
	cd tests/bench && python3 -m runner replay

bench-judge-prompt:
	cd tests/bench && python3 -m judge batch $(if $(LIMIT),--limit $(LIMIT),)

bench-judge-stats:
	cd tests/bench && python3 -m judge stats $(if $(UPDATE),--update-baseline,)

clean:
	rm -rf tests/bench/reports tests/unit/.pytest_cache
