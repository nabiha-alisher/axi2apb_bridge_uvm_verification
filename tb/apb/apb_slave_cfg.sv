//-------------------------------------------------------------------------
// apb_slave_cfg : knobs for the APB slave agent
//-------------------------------------------------------------------------
class apb_slave_cfg extends uvm_object;

  uvm_active_passive_enum is_active = UVM_ACTIVE;

  // Default response behaviour, used when no sequence supplies an item
  int unsigned min_wait      = 0;            // PREADY wait states, lower bound
  int unsigned max_wait      = 3;            // PREADY wait states, upper bound
  int unsigned err_pct       = 0;            // 0..100 : % of transfers answered with PSLVERR=1
  bit [31:0]   default_rdata = 32'hDEAD_BEEF;// read data for addresses never written
  bit          store_on_error = 0;           // 1: write is stored in memory even if PSLVERR=1

  // Monitor
  bit          checks_en      = 1;           // protocol checks on/off
  bit          strict_apb     = 0;           // 1: also flag a missing APB setup phase
                                             //    (supplied bridge has none: PSEL=1 always,
                                             //     PENABLE rises together with PADDR)
  int unsigned pready_timeout = 256;         // wait states before "PREADY stuck" error

  `uvm_object_utils(apb_slave_cfg)

  function new(string name = "apb_slave_cfg");
    super.new(name);
  endfunction

endclass : apb_slave_cfg
