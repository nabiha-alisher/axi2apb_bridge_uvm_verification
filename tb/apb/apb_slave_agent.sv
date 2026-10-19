//-------------------------------------------------------------------------
// apb_slave_agent
//   ACTIVE : sequencer + reactive slave driver + monitor
//   PASSIVE: monitor only
// The cfg object is taken from config_db ("apb_cfg") and pushed down to
// the driver and monitor.
//-------------------------------------------------------------------------
class apb_slave_agent extends uvm_agent;

  `uvm_component_utils(apb_slave_agent)

  apb_slave_cfg    cfg;
  apb_slave_driver driver;
  apb_sequencer    sequencer;
  apb_monitor      monitor;

  // re-exported monitor port
  uvm_analysis_port #(apb_seq_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(apb_slave_cfg)::get(this, "", "apb_cfg", cfg))
      cfg = apb_slave_cfg::type_id::create("cfg");
    is_active = cfg.is_active;
    uvm_config_db#(apb_slave_cfg)::set(this, "*", "apb_cfg", cfg);

    monitor = apb_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      driver    = apb_slave_driver::type_id::create("driver", this);
      sequencer = apb_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    ap = monitor.item_collected_port;
    if (get_is_active() == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction

endclass : apb_slave_agent
