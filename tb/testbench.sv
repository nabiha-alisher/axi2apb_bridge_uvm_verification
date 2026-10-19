import uvm_pkg::*;
`include "uvm_macros.svh"
import axi2apb_tb_uvm_pkg::*;

module tbench_top;

  //---------------------------------------
  // clock and reset
  //---------------------------------------
  bit clk;
  bit rst_n;

  always #5 clk = ~clk;

  // FIX: rst_n is ACTIVE-LOW.  The old code did "reset=1; #5 reset=0;" which
  // released reset for 5 ns and then HELD THE DUT IN RESET FOREVER.
  initial begin
    rst_n = 1'b0;                 // assert reset
    repeat (5) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;                 // release reset
  end

  //---------------------------------------
  // interfaces
  //---------------------------------------
  AXI_BUS axi_slave (
    .clk   (clk),
    .rst_n (rst_n)
  );

  APB_BUS apb_master (
    .clk   (clk),
    .rst_n (rst_n)
  );

  //---------------------------------------
  // DUT
  //---------------------------------------
  axi2apb_wrap dut (
    .clk_i      (clk),
    .rst_ni     (rst_n),
    .test_en_i  (1'b0),
    .axi_slave  (axi_slave),
    .apb_master (apb_master)
  );

  //---------------------------------------
  // hand the virtual interfaces to UVM
  //---------------------------------------
  initial begin
    uvm_config_db#(virtual AXI_BUS.Master)::set(uvm_root::get(), "*", "vif",         axi_slave);
    uvm_config_db#(virtual APB_BUS.Slave )::set(uvm_root::get(), "*", "apb_slv_vif", apb_master);
    uvm_config_db#(virtual APB_BUS.Monitor)::set(uvm_root::get(), "*", "apb_mon_vif", apb_master);

    $vcdplusfile("waveform.vpd");
    $vcdpluson;
  end

  initial begin
    run_test();
  end

endmodule
