vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xpm
vlib modelsim_lib/msim/xil_defaultlib
vlib modelsim_lib/msim/blk_mem_gen_v8_4_12

vmap xpm modelsim_lib/msim/xpm
vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib
vmap blk_mem_gen_v8_4_12 modelsim_lib/msim/blk_mem_gen_v8_4_12

vlog -work xpm  -incr -mfcu  -sv "+incdir+../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+../../../Final Project 2.gen/sources_1/ip/clk_wiz_0" \
"C:/AMDDesignTools/2025.2/Vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"C:/AMDDesignTools/2025.2/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm  -93  \
"C:/AMDDesignTools/2025.2/Vivado/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work xil_defaultlib  -incr -mfcu  "+incdir+../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+../../../Final Project 2.gen/sources_1/ip/clk_wiz_0" \
"../../../Final Project 2.gen/sources_1/ip/vio_0/sim/vio_0.v" \

vlog -work blk_mem_gen_v8_4_12  -incr -mfcu  "+incdir+../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+../../../Final Project 2.gen/sources_1/ip/clk_wiz_0" \
"../../ipstatic/simulation/blk_mem_gen_v8_4.v" \

vlog -work xil_defaultlib  -incr -mfcu  "+incdir+../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+../../../Final Project 2.gen/sources_1/ip/clk_wiz_0" \
"../../../Final Project 2.gen/sources_1/ip/blk_mem_gen_0/sim/blk_mem_gen_0.v" \
"../../../Final Project 2.gen/sources_1/ip/clk_wiz_0/clk_wiz_0_clk_wiz.v" \
"../../../Final Project 2.gen/sources_1/ip/clk_wiz_0/clk_wiz_0.v" \
"../../../Final Project 2.srcs/sources_1/imports/ov7670_with_vga/ov7670/OV7670_configuration.v" \
"../../../Final Project 2.srcs/sources_1/imports/ov7670_with_vga/ov7670/OV7670_configuration_rom.v" \
"../../../Final Project 2.srcs/sources_1/imports/ov7670_with_vga/ov7670/SCCB_configuration.v" \
"../../../Final Project 2.srcs/sources_1/imports/ov7670_with_vga/ov7670/camera_configuration.v" \
"../../../Final Project 2.srcs/sources_1/imports/ov7670_with_vga/ov7670/camera_read.v" \
"../../../Final Project 2.srcs/sources_1/imports/vga/h_sync.v" \
"../../../Final Project 2.srcs/sources_1/imports/ov7670_with_vga/ov7670/top_camera.v" \
"../../../Final Project 2.srcs/sources_1/imports/vga/v_sync.v" \
"../../../Final Project 2.srcs/sources_1/imports/vga/vga.v" \
"../../../Final Project 2.srcs/sources_1/imports/ov7670_with_vga/top_controller.v" \

vlog -work xil_defaultlib \
"glbl.v"

