SOURCES=$(wildcard phy/*.v csi/*.v)
LINT_TOP=csi_rx_packet_handler # temp

lint: $(SOURCES)
	verilator --top-module $(LINT_TOP) --lint-only $^

.PHONY: lint
