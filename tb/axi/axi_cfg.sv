// =============================================================================
// axi_agent_cfg : configuration of the AXI master agent
// =============================================================================
class axi_agent_cfg extends uvm_object;

  axi_vif_t    vif;
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  // response-channel ready generation (percentage of cycles with ready = 1)
  int unsigned b_ready_pct = 100;
  int unsigned r_ready_pct = 100;

  // number of transactions accepted from sequences but not yet responded to
  // (maintained by the driver, used by sequences to wait for idle)
  int          outstanding = 0;

  `uvm_object_utils(axi_agent_cfg)

  function new(string name = "axi_agent_cfg");
    super.new(name);
  endfunction

endclass
