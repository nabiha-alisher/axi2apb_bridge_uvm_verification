// =============================================================================
// 1. apb_seq_item : "how to answer ONE APB access"
//
// The DUT is the APB master, so this agent is a SLAVE. A sequence item therefore
// describes the slave's *response profile* for one access (random, chosen by the
// sequence), and carries back what the driver saw on the bus (filled by the driver).
//
//   sequence --(waits, slverr, rdata override)--> driver --(addr, write, wdata, rdata)--> sequence
//
// (apb_item, in apb_item.sv, is the separate monitor-side record of a completed access.)
// =============================================================================
class apb_seq_item extends uvm_sequence_item;

  // ---------------------------------------------------------------- response profile (random)
  rand int unsigned        waits;               // wait states before PREADY
  rand bit                 slverr;              // answer with PSLVERR
  rand bit                 rdata_override_en;   // 1: return rdata_override instead of memory content
  rand bit [APB_DW-1:0]    rdata_override;

  // ---------------------------------------------------------------- constraint knobs (not random)
  int unsigned             min_wait = 0;
  int unsigned             max_wait = 0;
  int unsigned             err_pct  = 0;        // 0..100

  // ---------------------------------------------------------------- observed access (driver fills)
  bit [APB_AW-1:0]         addr;
  bit                      write;
  bit [APB_DW-1:0]         wdata;
  bit [APB_DW-1:0]         rdata;               // data actually returned on a read
  bit                      aborted;             // access disappeared (reset) before completion

  `uvm_object_utils(apb_seq_item)

  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  constraint c_waits    { waits inside {[min_wait : (max_wait < min_wait ? min_wait : max_wait)]}; }
  constraint c_err      { slverr dist {1'b1 := err_pct, 1'b0 := (100 - err_pct)}; }
  constraint c_override { soft rdata_override_en == 1'b0; }

  function string convert2string();
    return $sformatf("rsp{waits=%0d err=%0b ovr=%0b} access{%s addr=0x%08h wdata=0x%08h rdata=0x%08h%s}",
                     waits, slverr, rdata_override_en, write ? "WR" : "RD", addr, wdata, rdata,
                     aborted ? " ABORTED" : "");
  endfunction

endclass
