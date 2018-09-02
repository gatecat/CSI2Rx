SOURCES=$(wildcard phy/*.v)
LINT_TOP=word_combiner # temp

lint: $(SOURCES)
	verilator --top-module $(LINT_TOP) --lint-only $^

.PHONY: lint
