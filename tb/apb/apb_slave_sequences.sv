//-------------------------------------------------------------------------
// APB slave response sequences.
// Each item is the RESPONSE to the NEXT APB transfer the bridge starts.
// num_responses = 0  -> run forever (start with fork/join_none, kill later)
//-------------------------------------------------------------------------
class apb_slave_base_seq extends uvm_sequence #(apb_seq_item);

  `uvm_object_utils(apb_slave_base_seq)

  int unsigned num_responses = 0;      // 0 = forever

  function new(string name = "apb_slave_base_seq");
    super.new(name);
  endfunction

  // overridden by derived sequences
  virtual function bit randomize_item(apb_seq_item it);
    return it.randomize();
  endfunction

  virtual task body();
    int unsigned n = 0;
    while (num_responses == 0 || n < num_responses) begin
      req = apb_seq_item::type_id::create("req");
      start_item(req);
      if (!randomize_item(req))
        `uvm_error(get_type_name(), "Randomization failed")
      finish_item(req);
      n++;
    end
  endtask

endclass : apb_slave_base_seq


// Random wait states in [min_wait : max_wait], no errors
class apb_slave_rand_wait_seq extends apb_slave_base_seq;

  `uvm_object_utils(apb_slave_rand_wait_seq)

  int unsigned min_wait = 0;
  int unsigned max_wait = 3;

  function new(string name = "apb_slave_rand_wait_seq");
    super.new(name);
  endfunction

  virtual function bit randomize_item(apb_seq_item it);
    int unsigned lo = min_wait;
    int unsigned hi = max_wait;
    return it.randomize() with { wait_cycles inside {[lo:hi]}; pslverr == 1'b0; };
  endfunction

endclass : apb_slave_rand_wait_seq


// Every response carries PSLVERR=1  (checklist: "PSLVERR is ignored by the FSM")
class apb_slave_slverr_seq extends apb_slave_base_seq;

  `uvm_object_utils(apb_slave_slverr_seq)

  function new(string name = "apb_slave_slverr_seq");
    super.new(name);
  endfunction

  virtual function bit randomize_item(apb_seq_item it);
    return it.randomize() with { pslverr == 1'b1; wait_cycles inside {[0:2]}; };
  endfunction

endclass : apb_slave_slverr_seq


// Reads return a fixed PRDATA, ignoring the memory model
// (checklist: "PRDATA sampled into RDATA_Q when PREADY goes high")
class apb_slave_rdata_seq extends apb_slave_base_seq;

  `uvm_object_utils(apb_slave_rdata_seq)

  bit [31:0] fixed_rdata = 32'hCAFE_F00D;

  function new(string name = "apb_slave_rdata_seq");
    super.new(name);
  endfunction

  virtual function bit randomize_item(apb_seq_item it);
    bit [31:0] rd = fixed_rdata;
    return it.randomize() with { override_prdata == 1'b1; prdata == rd;
                                 pslverr == 1'b0; wait_cycles inside {[0:3]}; };
  endfunction

endclass : apb_slave_rdata_seq
