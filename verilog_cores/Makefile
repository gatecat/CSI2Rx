SOURCES=$(wildcard phy/*.v)
LINT_TOP=dphy_rx_byte_align # temp

lint: $(SOURCES)
	verilator --top-module $(LINT_TOP) --lint-only $^

.PHONY: lint
