// =============================================================================
// axi2apb_env : AXI master agent + APB slave agent + scoreboard + coverage
// =============================================================================
class axi2apb_env extends uvm_env;

  `uvm_component_utils(axi2apb_env)

  axi2apb_env_cfg     cfg;
  axi_agent           axi_ag;
  apb_agent           apb_ag;
  axi2apb_scoreboard  sb;
  axi2apb_coverage    cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axi2apb_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "axi2apb_env_cfg not found")

    uvm_config_db#(axi_agent_cfg)::set(this, "axi_ag", "cfg", cfg.axi_cfg);
    uvm_config_db#(apb_agent_cfg)::set(this, "apb_ag", "cfg", cfg.apb_cfg);

    axi_ag = axi_agent::type_id::create("axi_ag", this);
    apb_ag = apb_agent::type_id::create("apb_ag", this);
    if (cfg.enable_scoreboard) begin
      sb = axi2apb_scoreboard::type_id::create("sb", this);
      sb.cfg = cfg;
    end
    if (cfg.enable_coverage)
      cov = axi2apb_coverage::type_id::create("cov", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    if (sb != null) begin
      axi_ag.mon.req_ap.connect(sb.axi_req_imp);
      axi_ag.mon.done_ap.connect(sb.axi_done_imp);
      apb_ag.mon.ap.connect(sb.apb_imp);
    end
    if (cov != null) begin
      axi_ag.mon.done_ap.connect(cov.axi_imp);
      apb_ag.mon.ap.connect(cov.apb_imp);
    end
  endfunction

endclass
