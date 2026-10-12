// =============================================================================
// 2. APB slave response sequences
//
// The driver asks for ONE item per APB access, so a slave sequence is a never-ending
// loop. It is started automatically as the sequencer's default sequence (see base test),
// so there is always an answer ready when the DUT starts an access.
//
//   apb_slave_seq             : profile taken from apb_agent_cfg (min/max wait, err %)
//   apb_zero_wait_slave_seq   : always PREADY immediately, never an error
//   apb_slow_slave_seq        : 3..8 wait states
//   apb_error_slave_seq       : 30 % of accesses return PSLVERR
//   apb_stuck_slave_seq       : occasional very long stall (32..40 wait states)
// =============================================================================
class apb_slave_seq extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(apb_slave_seq)

  apb_agent_cfg cfg;

  function new(string name = "apb_slave_seq");
    super.new(name);
  endfunction

  task pre_body();
    if (!uvm_config_db#(apb_agent_cfg)::get(m_sequencer, "", "cfg", cfg))
      `uvm_fatal("SEQ", "apb_agent_cfg not found on the APB sequencer")
  endtask

  // response profile used for the next access -- override in derived sequences
  virtual function void shape(apb_seq_item t);
    t.min_wait = cfg.min_wait;
    t.max_wait = cfg.max_wait;
    t.err_pct  = cfg.err_pct;
  endfunction

  virtual task body();
    forever begin
      req = apb_seq_item::type_id::create("rsp_item");
      start_item(req);                   // returns when the driver has an access to answer
      shape(req);
      if (!req.randomize())
        `uvm_fatal("SEQ", "APB response randomization failed")
      finish_item(req);                  // returns when the access has been completed
      `uvm_info("APB_SEQ", req.convert2string(), UVM_HIGH)
    end
  endtask

endclass

class apb_zero_wait_slave_seq extends apb_slave_seq;
  `uvm_object_utils(apb_zero_wait_slave_seq)
  function new(string name = "apb_zero_wait_slave_seq");
    super.new(name);
  endfunction
  virtual function void shape(apb_seq_item t);
    t.min_wait = 0; t.max_wait = 0; t.err_pct = 0;
  endfunction
endclass

class apb_slow_slave_seq extends apb_slave_seq;
  `uvm_object_utils(apb_slow_slave_seq)
  function new(string name = "apb_slow_slave_seq");
    super.new(name);
  endfunction
  virtual function void shape(apb_seq_item t);
    t.min_wait = 3; t.max_wait = 8; t.err_pct = 0;
  endfunction
endclass

class apb_error_slave_seq extends apb_slave_seq;
  `uvm_object_utils(apb_error_slave_seq)
  function new(string name = "apb_error_slave_seq");
    super.new(name);
  endfunction
  virtual function void shape(apb_seq_item t);
    t.min_wait = 0; t.max_wait = 2; t.err_pct = 30;
  endfunction
endclass

class apb_stuck_slave_seq extends apb_slave_seq;
  `uvm_object_utils(apb_stuck_slave_seq)
  function new(string name = "apb_stuck_slave_seq");
    super.new(name);
  endfunction
  virtual function void shape(apb_seq_item t);
    // roughly one access in eight stalls for a long time
    if ($urandom_range(7) == 0) begin t.min_wait = 32; t.max_wait = 40; end
    else                        begin t.min_wait = 0;  t.max_wait = 1;  end
    t.err_pct = 0;
  endfunction
endclass
