SOURCES=$(wildcard phy/*.v csi/*.v link/*.v)
LINT_TOP=csi_rx_ice40 # temp
SYN_TOP=csi_rx_ice40

lint: $(SOURCES)
	verilator --top-module $(LINT_TOP) --lint-only $^ /usr/local/share/yosys/ice40/cells_sim.v

syn: $(SOURCES)
	yosys -p "synth_ice40 -top ${SYN_TOP} -blif top.blif" $^

.PHONY: lint syn
