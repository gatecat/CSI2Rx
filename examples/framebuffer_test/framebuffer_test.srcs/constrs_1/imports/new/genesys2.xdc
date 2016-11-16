set_property PACKAGE_PIN AA20 [get_ports {hdmi_clk[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_clk[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_clk[0]}]
set_property PACKAGE_PIN AC20 [get_ports {hdmi_d0[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_d0[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_d0[0]}]
set_property PACKAGE_PIN AA22 [get_ports {hdmi_d1[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_d1[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_d1[0]}]
set_property PACKAGE_PIN AB24 [get_ports {hdmi_d2[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_d2[0]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_d2[1]}]
set_property PACKAGE_PIN R19 [get_ports reset_n]
set_property IOSTANDARD LVCMOS33 [get_ports reset_n]
set_property PACKAGE_PIN AD12 [get_ports clock_p]
set_property IOSTANDARD DIFF_SSTL15 [get_ports clock_p]


create_clock -period 5.000 -waveform {0.000 2.500} [get_ports clock_p]
create_clock -period 5.000 -waveform {2.500 5.000} [get_ports clock_n]


set_output_delay -clock [get_clocks [get_clocks -of_objects [get_pins pll/inst/plle2_adv_inst/CLKOUT1] -filter {IS_GENERATED && MASTER_CLOCK == clock_n}]] 0.250 [get_ports {{hdmi_d0[0]} {hdmi_d0[1]} {hdmi_d1[0]} {hdmi_d1[1]} {hdmi_d2[0]} {hdmi_d2[1]}}]


set_output_delay -clock [get_clocks [get_clocks -of_objects [get_pins pll/inst/plle2_adv_inst/CLKOUT1] -filter {IS_GENERATED && MASTER_CLOCK == clock_n}]] -add_delay -clock_fall 0.250 [get_ports {{hdmi_d0[0]} {hdmi_d0[1]} {hdmi_d1[0]} {hdmi_d1[1]} {hdmi_d2[0]} {hdmi_d2[1]}}]

set_property PACKAGE_PIN P27 [get_ports zoom_mode]
set_property IOSTANDARD LVCMOS33 [get_ports zoom_mode]

set_property PACKAGE_PIN P26 [get_ports freeze]
set_property IOSTANDARD LVCMOS33 [get_ports freeze]
