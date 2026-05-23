## Clock - 100MHz on Nexys 4
set_property PACKAGE_PIN E3 [get_ports clk_i]
set_property IOSTANDARD LVCMOS33 [get_ports clk_i]
create_clock -add -name sys_clk_pin -period 10.00 [get_ports clk_i]

## CPU Reset - BTNC (center button, active HIGH on Nexys4)
## neorv32 reset is active LOW so we invert in constraints or top module
set_property PACKAGE_PIN C12 [get_ports rstn_i]
set_property IOSTANDARD LVCMOS33 [get_ports rstn_i]

## UART TX (from FPGA to PC) - goes to USB-UART bridge
set_property PACKAGE_PIN D4 [get_ports uart0_txd_o]
set_property IOSTANDARD LVCMOS33 [get_ports uart0_txd_o]

## UART RX (from PC to FPGA)
set_property PACKAGE_PIN C4 [get_ports uart0_rxd_i]
set_property IOSTANDARD LVCMOS33 [get_ports uart0_rxd_i]

## LEDs - GPIO outputs (8 LEDs)
set_property PACKAGE_PIN T8 [get_ports {gpio_o[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[0]}]
set_property PACKAGE_PIN V9 [get_ports {gpio_o[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[1]}]
set_property PACKAGE_PIN R8 [get_ports {gpio_o[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[2]}]
set_property PACKAGE_PIN T6 [get_ports {gpio_o[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[3]}]
set_property PACKAGE_PIN T5 [get_ports {gpio_o[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[4]}]
set_property PACKAGE_PIN T4 [get_ports {gpio_o[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[5]}]
set_property PACKAGE_PIN U7 [get_ports {gpio_o[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[6]}]
set_property PACKAGE_PIN U6 [get_ports {gpio_o[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_o[7]}]


set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]