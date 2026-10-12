// =============================================================================
// apb_agent_cfg : configuration of the APB slave (responder) agent
// =============================================================================
class apb_agent_cfg extends uvm_object;

  apb_vif_t    vif;
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  int unsigned min_wait    = 0;      // wait states per access: random in [min_wait : max_wait]
  int unsigned max_wait    = 0;
  int unsigned err_pct     = 0;      // % of accesses answered with PSLVERR
  bit          idle_pready = 1'b1;   // PREADY value while no access is in progress

  `uvm_object_utils(apb_agent_cfg)

  function new(string name = "apb_agent_cfg");
    super.new(name);
  endfunction

  // data returned by the slave for locations that were never written
  static function bit [APB_DW-1:0] default_data(bit [APB_AW-1:0] addr);
    return (32'(addr >> 2) * 32'h9E37_79B1) ^ 32'h5A5A_C3C3;
  endfunction

endclass
