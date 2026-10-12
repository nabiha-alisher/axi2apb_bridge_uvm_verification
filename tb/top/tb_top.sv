// =============================================================================
// tb_top : clock/reset, DUT, interfaces, checkers, UVM start
// =============================================================================
`timescale 1ns/1ps

`ifndef AXI_DATA_WIDTH
  `define AXI_DATA_WIDTH 32
`endif

module tb_top;

  import uvm_pkg::*;
  import axi2apb_tb_pkg::*;
  `include "uvm_macros.svh"

  logic clk   = 1'b0;
  logic rst_n = 1'b0;

  always #5 clk = ~clk;                         // 100 MHz

  // ---------------------------------------------------------------- interfaces
  AXI_BUS #(.AXI_ADDR_WIDTH(32), .AXI_DATA_WIDTH(`AXI_DATA_WIDTH),
            .AXI_ID_WIDTH(6),    .AXI_USER_WIDTH(6)) axi_if (.clk(clk), .rst_n(rst_n));
  APB_BUS #(.APB_ADDR_WIDTH(32), .APB_DATA_WIDTH(32)) apb_if (.clk(clk), .rst_n(rst_n));

  // ---------------------------------------------------------------- DUT
  axi2apb_wrap #(
    .AXI_ADDR_WIDTH ( 32               ),
    .AXI_DATA_WIDTH ( `AXI_DATA_WIDTH  ),
    .AXI_USER_WIDTH ( 6                ),
    .AXI_ID_WIDTH   ( 6                ),
    .APB_ADDR_WIDTH ( 32               ),
    .APB_DATA_WIDTH ( 32               )
  ) dut (
    .clk_i      ( clk    ),
    .rst_ni     ( rst_n  ),
    .test_en_i  ( 1'b0   ),
    .axi_slave  ( axi_if ),
    .apb_master ( apb_if )
  );

  // ---------------------------------------------------------------- protocol checkers
  axi_protocol_checker                  u_axi_chk (.clk(clk), .rst_n(rst_n), .axi(axi_if));
  apb_protocol_checker #(.STRICT_SETUP(1'b0)) u_apb_chk (.clk(clk), .rst_n(rst_n), .apb(apb_if));

  // ---------------------------------------------------------------- reset
  // initial reset, plus on-demand reset: tests trigger the global uvm_event "tb_apply_reset"
  initial begin
    uvm_event req;
    req   = uvm_event_pool::get_global_pool().get("tb_apply_reset");
    rst_n = 1'b0;
    repeat (8) @(posedge clk);
    @(negedge clk) rst_n = 1'b1;
    forever begin
      req.wait_trigger();
      @(negedge clk) rst_n = 1'b0;
      repeat (4) @(posedge clk);
      @(negedge clk) rst_n = 1'b1;
    end
  end

  // ---------------------------------------------------------------- UVM
  initial begin
    uvm_config_db#(axi_vif_t)::set(null, "uvm_test_top", "axi_vif", axi_if);
    uvm_config_db#(apb_vif_t)::set(null, "uvm_test_top", "apb_vif", apb_if);
    run_test();
  end

  // ---------------------------------------------------------------- waves (+WAVES)
  initial begin
    if ($test$plusargs("WAVES")) begin
      $dumpfile("waves.vcd");
      $dumpvars(0, tb_top);
    end
  end

endmodule
