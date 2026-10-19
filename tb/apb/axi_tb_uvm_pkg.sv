package mem_tb_uvm_pkg;

import uvm_pkg::*;
`include "uvm_macros.svh"

// ---------------- AXI master agent ----------------
`include "axi_seq_item.sv"
`include "driver.sv"
`include "axi_sequencer.sv"
`include "axi_agent.sv"

// ---------------- APB slave agent -----------------
`include "apb_seq_item.sv"
`include "apb_slave_cfg.sv"
`include "apb_sequencer.sv"
`include "apb_slave_driver.sv"
`include "apb_monitor.sv"
`include "apb_slave_agent.sv"

// ---------------- sequences -----------------------
`include "axi_sequence.sv"
`include "apb_slave_sequences.sv"

// ---------------- virtual sequencer / sequences ---
`include "tb_virtual_sequencer.sv"
`include "tb_virtual_sequences.sv"

// ---------------- env + tests ---------------------
`include "axi_env.sv"
`include "axi_base_test.sv"
`include "axi_wr_rd_test.sv"
`include "axi_apb_tests.sv"

endpackage
