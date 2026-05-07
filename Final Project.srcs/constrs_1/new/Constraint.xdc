## 1. System Clock (100MHz)
set_property PACKAGE_PIN W5 [get_ports clk_100mhz]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100mhz]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk_100mhz]

## 2. Camera Data Bus (D0-D7)
set_property PACKAGE_PIN P17 [get_ports {d[0]}]
set_property PACKAGE_PIN N17 [get_ports {d[1]}]
set_property PACKAGE_PIN M19 [get_ports {d[2]}]
set_property PACKAGE_PIN M18 [get_ports {d[3]}]
set_property PACKAGE_PIN L17 [get_ports {d[4]}]
set_property PACKAGE_PIN K17 [get_ports {d[5]}]
set_property PACKAGE_PIN C16 [get_ports {d[6]}]
set_property PACKAGE_PIN B16 [get_ports {d[7]}]

## 3. Camera Control Signals
set_property PACKAGE_PIN B15 [get_ports vsync_cam]
set_property PACKAGE_PIN A16 [get_ports pclk]
set_property PACKAGE_PIN C15 [get_ports xclk]
set_property PACKAGE_PIN R18 [get_ports pwdn]
set_property PACKAGE_PIN P18 [get_ports rst]

## 4. SCCB (I2C-like) - SDA & SCL
set_property PACKAGE_PIN A14 [get_ports scl]
set_property PACKAGE_PIN A15 [get_ports sda]
set_property PULLTYPE PULLUP [get_ports sda]
set_property PULLTYPE PULLUP [get_ports scl]

## 5. VGA Output (พินมาตรฐาน Basys 3 ไม่ซ้ำซ้อน)
set_property PACKAGE_PIN G19 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN H19 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN J19 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN N19 [get_ports {vga_r[3]}]
set_property PACKAGE_PIN J17 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN H17 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN G17 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN D17 [get_ports {vga_g[3]}]
set_property PACKAGE_PIN N18 [get_ports {vga_b[0]}]
set_property PACKAGE_PIN L18 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN K18 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN J18 [get_ports {vga_b[3]}]
set_property PACKAGE_PIN P19 [get_ports hsync]      <-- แก้เป็น P19
set_property PACKAGE_PIN R19 [get_ports vsync_vga]  <-- แก้เป็น R19

## 6. Buttons & Switches
set_property PACKAGE_PIN U18 [get_ports btnC]
set_property PACKAGE_PIN V17 [get_ports {sw[0]}]
set_property PACKAGE_PIN V16 [get_ports {sw[1]}]
set_property PACKAGE_PIN U16 [get_ports {led[0]}]

## 7. IO Standards
set_property IOSTANDARD LVCMOS33 [get_ports {d[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports vsync_cam]
set_property IOSTANDARD LVCMOS33 [get_ports vsync_vga]
set_property IOSTANDARD LVCMOS33 [get_ports href]
set_property IOSTANDARD LVCMOS33 [get_ports pclk]
set_property IOSTANDARD LVCMOS33 [get_ports xclk]
set_property IOSTANDARD LVCMOS33 [get_ports pwdn]
set_property IOSTANDARD LVCMOS33 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports scl]
set_property IOSTANDARD LVCMOS33 [get_ports sda]
set_property IOSTANDARD LVCMOS33 [get_ports hsync]
set_property IOSTANDARD LVCMOS33 [get_ports btnC]

## 8. Clock Constraints
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets pclk_IBUF]

set_property PACKAGE_PIN A17 [get_ports href]
set_property PACKAGE_PIN P19 [get_ports hsync]
set_property PACKAGE_PIN R19 [get_ports vsync_vga]
