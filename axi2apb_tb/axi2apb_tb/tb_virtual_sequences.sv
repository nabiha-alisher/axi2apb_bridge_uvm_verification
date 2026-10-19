//-------------------------------------------------------------------------
// Virtual sequences : coordinate the AXI master agent and the APB slave
// agent.  Pattern used everywhere:
//   1. start an APB responder in the background (fork/join_none)
//   2. run the AXI sequences
//   3. check results, then kill the responder
//-------------------------------------------------------------------------
class tb_base_vseq extends uvm_sequence;

  `uvm_object_utils(tb_base_vseq)
  `uvm_declare_p_sequencer(tb_virtual_sequencer)

  function new(string name = "tb_base_vseq");
    super.new(name);
  endfunction

  // Start an APB response sequence in the background.
  task start_apb_responder(apb_slave_base_seq s);
    if (p_sequencer.apb_sqr == null) begin
      `uvm_warning(get_type_name(), "APB sequencer is null (passive agent?) - no responder started")
      return;
    end
    fork
      s.start(p_sequencer.apb_sqr);
    join_none
  endtask

  function void check_okay(string what, bit [1:0] resp);
    if (resp !== 2'b00)
      `uvm_warning(get_type_name(),
        $sformatf("%s = %0b (not OKAY). Supplied RTL is expected to always return OKAY", what, resp))
    else
      `uvm_info(get_type_name(), $sformatf("%s = OKAY", what), UVM_LOW)
  endfunction

endclass : tb_base_vseq


//-------------------------------------------------------------------------
// 1) Basic write then read-back, random PREADY wait states (0..3)
//-------------------------------------------------------------------------
class vseq_axi_wr_rd extends tb_base_vseq;

  `uvm_object_utils(vseq_axi_wr_rd)

  function new(string name = "vseq_axi_wr_rd");
    super.new(name);
  endfunction

  virtual task body();
    direct_write_seq        wr_seq = direct_write_seq::type_id::create("wr_seq");
    direct_read_seq         rd_seq = direct_read_seq::type_id::create("rd_seq");
    apb_slave_rand_wait_seq apb_seq = apb_slave_rand_wait_seq::type_id::create("apb_seq");

    apb_seq.min_wait = 0;
    apb_seq.max_wait = 3;
    start_apb_responder(apb_seq);

    wr_seq.start(p_sequencer.axi_sqr);
    check_okay("BRESP", wr_seq.req.bresp);

    rd_seq.start(p_sequencer.axi_sqr);
    check_okay("RRESP", rd_seq.req.rresp);

    if (rd_seq.req.rdata !== wr_seq.req.wdata)
      `uvm_error(get_type_name(),
        $sformatf("Read-back mismatch: wrote 0x%08h, read 0x%08h",
                  wr_seq.req.wdata, rd_seq.req.rdata))
    else
      `uvm_info(get_type_name(),
        $sformatf("Read-back OK: 0x%08h", rd_seq.req.rdata), UVM_LOW)

    apb_seq.kill();
  endtask

endclass : vseq_axi_wr_rd


//-------------------------------------------------------------------------
// 2) Long PREADY wait states (8) : write must sit in WAIT_W_PREADY and
//    only then produce BVALID; same for read
//-------------------------------------------------------------------------
class vseq_apb_wait_states extends tb_base_vseq;

  `uvm_object_utils(vseq_apb_wait_states)

  int unsigned waits = 8;

  function new(string name = "vseq_apb_wait_states");
    super.new(name);
  endfunction

  virtual task body();
    direct_write_seq        wr_seq = direct_write_seq::type_id::create("wr_seq");
    direct_read_seq         rd_seq = direct_read_seq::type_id::create("rd_seq");
    apb_slave_rand_wait_seq apb_seq = apb_slave_rand_wait_seq::type_id::create("apb_seq");

    apb_seq.min_wait = waits;
    apb_seq.max_wait = waits;
    start_apb_responder(apb_seq);

    wr_seq.start(p_sequencer.axi_sqr);
    rd_seq.start(p_sequencer.axi_sqr);

    if (rd_seq.req.rdata !== wr_seq.req.wdata)
      `uvm_error(get_type_name(),
        $sformatf("Read-back mismatch with %0d wait states: wrote 0x%08h, read 0x%08h",
                  waits, wr_seq.req.wdata, rd_seq.req.rdata))

    apb_seq.kill();
  endtask

endclass : vseq_apb_wait_states


//-------------------------------------------------------------------------
// 3) PSLVERR injection : document whether BRESP / RRESP follow PSLVERR.
//    Supplied RTL ignores PSLVERR -> expect OKAY, but VERIFY it.
//-------------------------------------------------------------------------
class vseq_apb_slverr extends tb_base_vseq;

  `uvm_object_utils(vseq_apb_slverr)

  function new(string name = "vseq_apb_slverr");
    super.new(name);
  endfunction

  virtual task body();
    direct_write_seq       wr_seq = direct_write_seq::type_id::create("wr_seq");
    direct_read_seq        rd_seq = direct_read_seq::type_id::create("rd_seq");
    apb_slave_slverr_seq   apb_seq = apb_slave_slverr_seq::type_id::create("apb_seq");

    start_apb_responder(apb_seq);

    wr_seq.start(p_sequencer.axi_sqr);
    `uvm_info(get_type_name(),
      $sformatf("OBSERVED with PSLVERR=1 on write: BRESP=%0b", wr_seq.req.bresp), UVM_LOW)
    check_okay("BRESP (PSLVERR injected)", wr_seq.req.bresp);

    rd_seq.start(p_sequencer.axi_sqr);
    `uvm_info(get_type_name(),
      $sformatf("OBSERVED with PSLVERR=1 on read: RRESP=%0b", rd_seq.req.rresp), UVM_LOW)
    check_okay("RRESP (PSLVERR injected)", rd_seq.req.rresp);

    apb_seq.kill();
  endtask

endclass : vseq_apb_slverr


//-------------------------------------------------------------------------
// 4) Directed PRDATA : read data must come from PRDATA, not from AXI side
//-------------------------------------------------------------------------
class vseq_apb_rdata extends tb_base_vseq;

  `uvm_object_utils(vseq_apb_rdata)

  function new(string name = "vseq_apb_rdata");
    super.new(name);
  endfunction

  virtual task body();
    direct_read_seq      rd_seq  = direct_read_seq::type_id::create("rd_seq");
    apb_slave_rdata_seq  apb_seq = apb_slave_rdata_seq::type_id::create("apb_seq");

    apb_seq.fixed_rdata = 32'hCAFE_F00D;
    start_apb_responder(apb_seq);

    rd_seq.start(p_sequencer.axi_sqr);

    if (rd_seq.req.rdata !== apb_seq.fixed_rdata)
      `uvm_error(get_type_name(),
        $sformatf("RDATA 0x%08h != PRDATA 0x%08h", rd_seq.req.rdata, apb_seq.fixed_rdata))
    else
      `uvm_info(get_type_name(), "RDATA matches injected PRDATA", UVM_LOW)

    apb_seq.kill();
  endtask

endclass : vseq_apb_rdata


//-------------------------------------------------------------------------
// 5) Whole AXI sequence set under a random-wait APB responder.
//    Reset-behaviour and PSLVERR items are separate (they need reset
//    control / apb_slave_slverr_seq - see vseq_apb_slverr).
//-------------------------------------------------------------------------
class vseq_axi_plan extends tb_base_vseq;

  `uvm_object_utils(vseq_axi_plan)

  function new(string name = "vseq_axi_plan");
    super.new(name);
  endfunction

  virtual task body();
    apb_slave_rand_wait_seq apb_seq = apb_slave_rand_wait_seq::type_id::create("apb_seq");
    uvm_sequence_base       seqs[$];

    apb_seq.min_wait = 0;
    apb_seq.max_wait = 9;          // spans every wait-state coverage bin
    start_apb_responder(apb_seq);

    seqs.push_back(axi_wr_rd_back_seq::type_id::create("wr_rd_back"));
    seqs.push_back(axi_aw_w_order_seq::type_id::create("aw_w_order"));
    seqs.push_back(axi_wstrb_seq::type_id::create("wstrb"));
    seqs.push_back(axi_bready_seq::type_id::create("bready"));
    seqs.push_back(axi_rready_seq::type_id::create("rready"));
    seqs.push_back(axi_id_user_seq::type_id::create("id_user"));
    seqs.push_back(axi_back_to_back_seq::type_id::create("b2b"));
    seqs.push_back(axi_rand_mem_seq::type_id::create("rand_mem"));
    seqs.push_back(axi_boundary_seq::type_id::create("boundary"));
    seqs.push_back(axi_rd_wr_same_time_seq::type_id::create("rd_wr_same_time"));
    seqs.push_back(axi_unsupported_probe_seq::type_id::create("unsupported"));

    foreach (seqs[i]) begin
      `uvm_info(get_type_name(), $sformatf("---- running %s ----", seqs[i].get_name()), UVM_LOW)
      seqs[i].start(p_sequencer.axi_sqr);
    end

    apb_seq.kill();
  endtask

endclass : vseq_axi_plan
