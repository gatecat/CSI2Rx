SOURCES=$(wildcard phy/*.v)
LINT_TOP=dphy_oserdes # temp

lint: $(SOURCES)
	verilator --top-module $(LINT_TOP) --lint-only $^

.PHONY: lint
