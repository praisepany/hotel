vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xpm
vlib modelsim_lib/msim/blk_mem_gen_v8_4_12
vlib modelsim_lib/msim/xil_defaultlib

vmap xpm modelsim_lib/msim/xpm
vmap blk_mem_gen_v8_4_12 modelsim_lib/msim/blk_mem_gen_v8_4_12
vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib

vlog -work xpm  -incr -mfcu  -sv "+incdir+../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+../../../Final Project.gen/sources_1/ip/clk_viz" \
"C:/AMDDesignTools/2025.2/Vivado/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"C:/AMDDesignTools/2025.2/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm  -93  \
"C:/AMDDesignTools/2025.2/Vivado/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work blk_mem_gen_v8_4_12  -incr -mfcu  "+incdir+../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+../../../Final Project.gen/sources_1/ip/clk_viz" \
"../../ipstatic/simulation/blk_mem_gen_v8_4.v" \

vlog -work xil_defaultlib  -incr -mfcu  "+incdir+../../../../../../../AMDDesignTools/2025.2/Vivado/data/rsb/busdef" "+incdir+../../../Final Project.gen/sources_1/ip/clk_viz" \
"../../../Final Project.gen/sources_1/ip/blk_mem_gen_0/sim/blk_mem_gen_0.v" \
"../../../Final Project.gen/sources_1/ip/clk_viz/clk_viz_clk_wiz.v" \
"../../../Final Project.gen/sources_1/ip/clk_viz/clk_viz.v" \
"../../../Final Project.srcs/sources_1/new/image_processor.v" \
"../../../Final Project.srcs/sources_1/new/ov7670_capture.v" \
"../../../Final Project.srcs/sources_1/new/ov7670_init.v" \
"../../../Final Project.srcs/sources_1/new/sccb_controller.v" \
"../../../Final Project.srcs/sources_1/new/vga_controller.v" \
"../../../Final Project.srcs/sources_1/new/top_system.v" \

vlog -work xil_defaultlib \
"glbl.v"

