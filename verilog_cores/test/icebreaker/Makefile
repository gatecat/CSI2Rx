SOURCES = $(wildcard ../../csi/*.v ../../phy/*.v ../../link/*.v ../../misc/*.v uart.v top.v)
PROJ=camera
PIN_DEF=icecam.pcf
DEVICE=up5k

all: $(PROJ).rpt $(PROJ).bin

%.json: $(SOURCES)
	yosys -ql yosys.log -p 'synth_ice40 -top top -json $@' $(SOURCES)

%.asc: %.json $(PIN_DEF)
	nextpnr-ice40 --up5k --pcf $(PIN_DEF) --json $< --asc $@ --freq 40

%.bin: %.asc
	icepack $< $@

%.rpt: %.asc
	icetime -d $(DEVICE) -mtr $@ $<

prog: $(PROJ).bin
	iceprog $<

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo iceprog $<

clean:
	rm -f $(PROJ).blif $(PROJ).asc $(PROJ).rpt $(PROJ).bin

.SECONDARY:
.PHONY: all prog clean
