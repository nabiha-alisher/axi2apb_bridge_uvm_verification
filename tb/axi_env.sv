class axi_model_env extends uvm_env;

  //---------------------------------------
  // agents + virtual sequencer
  //---------------------------------------
  mem_agent            mem_agnt;     // AXI master agent
  apb_slave_agent      apb_agnt;     // APB slave agent
  tb_virtual_sequencer vsqr;
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
  endfunction : build_phase

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    vsqr.axi_sqr = mem_agnt.sequencer;
    vsqr.apb_sqr = apb_agnt.sequencer;     // null if apb agent is passive
    // apb_agnt.ap.connect(mem_scb.apb_export);
  endfunction : connect_phase

endclass : axi_model_env
