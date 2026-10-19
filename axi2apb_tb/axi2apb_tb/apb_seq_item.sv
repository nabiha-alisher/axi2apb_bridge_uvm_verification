//-------------------------------------------------------------------------
// apb_seq_item
//
// One item = one APB transfer, seen from the SLAVE side.
//  - "response" fields (rand) tell the slave driver HOW to answer:
//        wait_cycles, pslverr, prdata / override_prdata
//  - "request" fields are filled in by the slave driver / monitor with
//    what the bridge actually did on the bus (paddr, pwrite, pwdata).
//-------------------------------------------------------------------------
class apb_seq_item extends uvm_sequence_item;

  // ---- request side (observed on the bus, NOT randomized) ----
  bit [31:0] paddr;
  bit [31:0] pwdata;
  bit        pwrite;

  // ---- response side (controls the slave) ----
  rand int unsigned wait_cycles;     // wait states = access cycles (PENABLE=1) with PREADY=0
                                     // 0 = PREADY already high in the FIRST PENABLE cycle
  rand bit          pslverr;         // value driven on PSLVERR with PREADY
  rand bit [31:0]   prdata;          // used only when override_prdata == 1
  rand bit          override_prdata; // 0: read data comes from slave memory model

  // ---- filled by the monitor ----
  int unsigned      observed_waits;

  `uvm_object_utils(apb_seq_item)

  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  // soft: sequences / cfg can narrow or override these freely
  constraint c_wait { soft wait_cycles inside {[0:8]}; }
  constraint c_err  { soft pslverr == 1'b0; }
  constraint c_ovr  { soft override_prdata == 1'b0; }

  virtual function string convert2string();
    return $sformatf("%s addr=0x%08h wdata=0x%08h rdata=0x%08h pslverr=%0b waits=%0d (cfg wait=%0d)",
                     pwrite ? "WRITE" : "READ ", paddr, pwdata, prdata,
                     pslverr, observed_waits, wait_cycles);
  endfunction

endclass : apb_seq_item
