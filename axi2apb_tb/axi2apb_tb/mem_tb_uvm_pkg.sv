//-------------------------------------------------------------------------
// mem_tb_uvm_pkg : single package for the whole AXI2APB UVM environment.
// This is the ONLY file (besides testbench.sv) that goes in build.f.
// Every class file below is found through +incdir, so do NOT list them
// separately in build.f.
//-------------------------------------------------------------------------
package mem_tb_uvm_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ================= AXI master agent  (tb/axi_agent) =================
  `include "axi_seq_item.sv"
  `include "driver.sv"
  `include "axi_sequencer.sv"
  `include "axi_agent.sv"
  `include "axi_sequence.sv"

  // ================= APB slave agent   (tb/apb_agent) =================
  `include "apb_seq_item.sv"
  `include "apb_slave_cfg.sv"
  `include "apb_sequencer.sv"
  `include "apb_slave_driver.sv"
  `include "apb_monitor.sv"
  `include "apb_slave_agent.sv"
  `include "apb_slave_sequences.sv"

  // ================= env + virtual sequencer (tb/env) =================
  `include "tb_virtual_sequencer.sv"
  `include "tb_virtual_sequences.sv"
  `include "axi2apb_coverage.sv"
  `include "axi_env.sv"

  // ================= tests             (tb/tests) =====================
  `include "axi_base_test.sv"
  `include "axi_wr_rd_test.sv"
  `include "axi_apb_tests.sv"

endpackage : mem_tb_uvm_pkg
