// compile order: interfaces, RTL (nested `includes removed), TB package, checkers, top
+incdir+../tb
../rtl/apb_bus.sv
../rtl/axi_bus.sv
../rtl/fifo.sv
../rtl/axi_single_slice.sv
../rtl/axi_aw_buffer.sv
../rtl/axi_ar_buffer.sv
../rtl/axi_w_buffer.sv
../rtl/axi_b_buffer.sv
../rtl/axi_r_buffer.sv
../rtl/axi2apb.sv
../rtl/axi2apb_64_32.sv
../rtl/axi2apb_wrap.sv
../tb/axi2apb_tb_pkg.sv
../tb/top/protocol_checkers.sv
../tb/top/tb_top.sv
