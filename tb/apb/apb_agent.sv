// =============================================================================
// apb_agent : APB slave agent
//
//   sequence --> apb_sequencer --> apb_driver --> APB_BUS (psel/penable/pready/prdata/pslverr)
//                                                    |
//                                      apb_monitor <-+--> apb_item --> scoreboard / coverage
//
// Interface: the existing APB_BUS (rtl/apb_bus.sv, the same interface the DUT uses through
// its Master modport) is reused unchanged. The virtual interface reaches driver and monitor
// through apb_agent_cfg.vif:  tb_top -> config_db -> test -> env_cfg.apb_cfg.vif -> agent.
// =============================================================================
class apb_agent extends uvm_agent;

  `uvm_component_utils(apb_agent)

  apb_agent_cfg  cfg;
  apb_sequencer  sqr;
  apb_driver     drv;
  apb_monitor    mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(apb_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "apb_agent_cfg not found")
    // visible to driver, monitor, sequencer (and to sequences running on it)
    uvm_config_db#(apb_agent_cfg)::set(this, "*", "cfg", cfg);
    mon = apb_monitor::type_id::create("mon", this);
    if (cfg.is_active == UVM_ACTIVE) begin
      sqr = apb_sequencer::type_id::create("sqr", this);
      drv = apb_driver::type_id::create("drv", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (cfg.is_active == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass
