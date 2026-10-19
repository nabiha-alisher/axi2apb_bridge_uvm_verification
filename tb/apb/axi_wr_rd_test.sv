//-------------------------------------------------------------------------
// axi_wr_rd_test : base for the bridge tests.  Runs one virtual sequence.
// Derived tests override get_vseq() (and optionally configure apb_cfg).
//-------------------------------------------------------------------------
class axi_wr_rd_test extends axi_model_base_test;

  `uvm_component_utils(axi_wr_rd_test)

  apb_slave_cfg apb_cfg;

  function new(string name = "axi_wr_rd_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb_cfg = apb_slave_cfg::type_id::create("apb_cfg");
    configure_apb(apb_cfg);
    uvm_config_db#(apb_slave_cfg)::set(this, "env.apb_agnt", "apb_cfg", apb_cfg);
  endfunction : build_phase

  // hook for derived tests
  virtual function void configure_apb(apb_slave_cfg c);
  endfunction

  // hook for derived tests
  virtual function uvm_sequence_base get_vseq();
    vseq_axi_wr_rd s = vseq_axi_wr_rd::type_id::create("vseq");
    return s;
  endfunction

  task run_phase(uvm_phase phase);
    uvm_sequence_base vseq;

    phase.raise_objection(this);
    vseq = get_vseq();
    vseq.start(env.vsqr);
    phase.phase_done.set_drain_time(this, 50);   // must be set BEFORE the drop
    phase.drop_objection(this);
  endtask : run_phase

endclass : axi_wr_rd_test
