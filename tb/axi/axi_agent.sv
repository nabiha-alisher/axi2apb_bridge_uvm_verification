// =============================================================================
// axi_agent : AXI master agent (sequencer + driver + monitor)
// =============================================================================
typedef uvm_sequencer #(axi_item) axi_sequencer;

class axi_agent extends uvm_agent;

  `uvm_component_utils(axi_agent)

  axi_agent_cfg  cfg;
  axi_sequencer  sqr;
  axi_driver     drv;
  axi_monitor    mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axi_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "axi_agent_cfg not found")
    // make the cfg visible to all children (and to sequences running on sqr)
    uvm_config_db#(axi_agent_cfg)::set(this, "*", "cfg", cfg);
    mon = axi_monitor::type_id::create("mon", this);
    if (cfg.is_active == UVM_ACTIVE) begin
      sqr = axi_sequencer::type_id::create("sqr", this);
      drv = axi_driver::type_id::create("drv", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (cfg.is_active == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass
