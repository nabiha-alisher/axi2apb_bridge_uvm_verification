class axi_model_env extends uvm_env;

  //---------------------------------------
  // agents + virtual sequencer
  //---------------------------------------
  mem_agent            mem_agnt;     // AXI master agent
  apb_slave_agent      apb_agnt;     // APB slave agent
  tb_virtual_sequencer vsqr;
  axi2apb_coverage     cov;
  //mem_scoreboard     mem_scb;      // next step: AXI mon + apb_agnt.ap -> scoreboard

  `uvm_component_utils(axi_model_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mem_agnt = mem_agent::type_id::create("mem_agnt", this);
    apb_agnt = apb_slave_agent::type_id::create("apb_agnt", this);
    vsqr     = tb_virtual_sequencer::type_id::create("vsqr", this);
    cov      = axi2apb_coverage::type_id::create("cov", this);
  endfunction : build_phase

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    vsqr.axi_sqr = mem_agnt.sequencer;
    vsqr.apb_sqr = apb_agnt.sequencer;     // null if apb agent is passive
    // apb_agnt.ap.connect(mem_scb.apb_export);

    // functional coverage
    if (mem_agnt.ap != null) mem_agnt.ap.connect(cov.axi_imp);
    apb_agnt.ap.connect(cov.apb_imp);
  endfunction : connect_phase

endclass : axi_model_env
