// =============================================================================
// axi2apb_tb_pkg : UVM environment package for axi2apb_wrap
//
// Compile-time knob:  +define+AXI_DATA_WIDTH=32   (axi2apb       : 32 -> 32)
//                     +define+AXI_DATA_WIDTH=64   (axi2apb_64_32 : 64 -> 32)
// =============================================================================
`ifndef AXI_DATA_WIDTH
  `define AXI_DATA_WIDTH 32
`endif

package axi2apb_tb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ---------------------------------------------------------------- constants
  localparam int AXI_AW       = 32;
  localparam int AXI_DW       = `AXI_DATA_WIDTH;
  localparam int AXI_IDW      = 6;
  localparam int AXI_UW       = 6;
  localparam int APB_AW       = 32;
  localparam int APB_DW       = 32;
  localparam int AXI_SW       = AXI_DW / 8;          // strobe width / bytes per beat
  localparam int AXI_MAX_SIZE = $clog2(AXI_SW);      // AxSIZE of a full-width beat

  typedef virtual AXI_BUS #(.AXI_ADDR_WIDTH(AXI_AW), .AXI_DATA_WIDTH(AXI_DW),
                            .AXI_ID_WIDTH(AXI_IDW),  .AXI_USER_WIDTH(AXI_UW)) axi_vif_t;
  typedef virtual APB_BUS #(.APB_ADDR_WIDTH(APB_AW), .APB_DATA_WIDTH(APB_DW)) apb_vif_t;

  // analysis imp suffixes shared by scoreboard and coverage
  `uvm_analysis_imp_decl(_axi_req)
  `uvm_analysis_imp_decl(_axi_done)
  `uvm_analysis_imp_decl(_apb)

  // ------------------------------------------------------------------- AXI agent
  `include "axi/axi_item.sv"
  `include "axi/axi_cfg.sv"
  `include "axi/axi_driver.sv"
  `include "axi/axi_monitor.sv"
  `include "axi/axi_agent.sv"

  // ------------------------------------------------------------------- APB agent
  `include "apb/apb_item.sv"          // monitor-side record of a completed access
  `include "apb/apb_seq_item.sv"      // 1. response profile for one access
  `include "apb/apb_cfg.sv"
  `include "apb/apb_sequence.sv"      // 2. slave response sequences
  `include "apb/apb_sequencer.sv"     // 3. sequencer
  `include "apb/apb_driver.sv"        // 4. driver
  `include "apb/apb_monitor.sv"
  `include "apb/apb_agent.sv"

  // ------------------------------------------------------------------- env
  `include "env/env_cfg.sv"
  `include "env/scoreboard.sv"
  `include "env/coverage.sv"
  `include "env/env.sv"

  // ------------------------------------------------------------------- tests
  `include "seq/axi_sequences.sv"
  `include "tests/tests.sv"

endpackage
