// =============================================================================
// axi2apb_env_cfg : top-level environment configuration
// =============================================================================
class axi2apb_env_cfg extends uvm_object;

  axi_agent_cfg axi_cfg;
  apb_agent_cfg apb_cfg;

  bit enable_scoreboard = 1;
  bit enable_coverage   = 1;

  // When 1 the scoreboard expects PSLVERR on any APB access of a transaction to be
  // reported as SLVERR on B/R. When 0 the response code is not checked in that case.
  bit check_slverr_map  = 0;

  `uvm_object_utils(axi2apb_env_cfg)

  function new(string name = "axi2apb_env_cfg");
    super.new(name);
    axi_cfg = axi_agent_cfg::type_id::create("axi_cfg");
    apb_cfg = apb_agent_cfg::type_id::create("apb_cfg");
  endfunction

endclass
