// =============================================================================
// apb_monitor : publishes one apb_item per completed access
//   completed = rising clock edge with PSEL && PENABLE && PREADY
// =============================================================================
class apb_monitor extends uvm_monitor;

  `uvm_component_utils(apb_monitor)

  uvm_analysis_port #(apb_item) ap;

  apb_agent_cfg cfg;
  apb_vif_t     vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(apb_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "apb_agent_cfg not found")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    int unsigned cnt = 0;
    apb_item     a;
    forever begin
      @(posedge vif.clk);
      if (vif.rst_n !== 1'b1) begin
        cnt = 0;
        continue;
      end
      if (vif.psel === 1'b1 && vif.penable === 1'b1) begin
        if (vif.pready === 1'b1) begin
          a = apb_item::type_id::create("apb_obs");
          a.addr   = vif.paddr;
          a.write  = vif.pwrite;
          a.wdata  = vif.pwdata;
          a.rdata  = vif.prdata;
          a.slverr = vif.pslverr;
          a.waits  = cnt;
          a.t_done = $time;
          cnt = 0;
          ap.write(a);
        end else
          cnt++;
      end else
        cnt = 0;
    end
  endtask

endclass
