-makelib xcelium_lib/xil_defaultlib -sv \
  "/var/local/xilinx-local/Vivado/2019.1/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \
-endlib
-makelib xcelium_lib/xpm \
  "/var/local/xilinx-local/Vivado/2019.1/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib xcelium_lib/blk_mem_gen_v8_4_3 \
  "../../../ipstatic/simulation/blk_mem_gen_v8_4.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../../final_project.srcs/sources_1/ip/p1_at_rest_blue/sim/p1_at_rest_blue.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  glbl.v
-endlib

