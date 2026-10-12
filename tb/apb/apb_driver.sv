// =============================================================================
// 4. apb_driver : reactive APB slave driver
//
//   * idles with PREADY = cfg.idle_pready
//   * when the DUT starts an access (PSEL && PENABLE) it pulls ONE apb_seq_item from the
//     sequencer: that item says how many wait states to insert, whether to raise PSLVERR
//     and (optionally) which read data to return
//   * a word memory backs the slave: writes store PWDATA, reads return the stored word
//     (or cfg default_data() for never-written locations)
//   * the observed access (addr/write/wdata/rdata) is written back into the item and
//     item_done() releases the sequence
//
// Timing: the DUT's APB outputs are combinational from its FSM and the FSM samples PREADY
// in the same cycle PENABLE is high, so the driver reacts at the FALLING clock edge
// (outputs settled) and the DUT sees the response at the next rising edge.
// =============================================================================
class apb_driver extends uvm_driver #(apb_seq_item);

  `uvm_component_utils(apb_driver)

  apb_agent_cfg    cfg;
  apb_vif_t        vif;

  bit [APB_DW-1:0] mem [bit [APB_AW-3:0]];     // word-addressed slave memory

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(apb_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "apb_agent_cfg not found")
    vif = cfg.vif;
  endfunction

  // ------------------------------------------------------------------ helpers
  function void drive_idle();
    vif.pready  = cfg.idle_pready;
    vif.pslverr = 1'b0;
    vif.prdata  = '0;
  endfunction

  function bit access_active();
    return (vif.rst_n === 1'b1 && vif.psel === 1'b1 && vif.penable === 1'b1);
  endfunction

  // ------------------------------------------------------------------ main loop
  task run_phase(uvm_phase phase);
    apb_seq_item item;
    drive_idle();
    forever begin
      @(negedge vif.clk);
      if (!access_active()) begin
        drive_idle();
        continue;
      end
      // hold the DUT in a wait state until a response profile is available
      vif.pready  = 1'b0;
      vif.pslverr = 1'b0;
      vif.prdata  = '0;
      seq_item_port.get_next_item(item);
      serve(item);
      seq_item_port.item_done();
    end
  endtask

  // answer one access according to the item
  task serve(apb_seq_item t);
    int unsigned     waits = t.waits;
    bit [APB_AW-3:0] widx;
    bit [APB_DW-1:0] rd;

    while (waits > 0) begin
      vif.pready  = 1'b0;
      vif.pslverr = 1'b0;
      vif.prdata  = '0;
      waits--;
      @(negedge vif.clk);
      if (!access_active()) begin          // reset (or DUT gave up) during the wait
        drive_idle();
        t.aborted = 1'b1;
        return;
      end
    end

    // completion cycle
    t.addr  = vif.paddr;
    t.write = vif.pwrite;
    t.wdata = vif.pwdata;
    widx    = vif.paddr[APB_AW-1:2];

    vif.pready  = 1'b1;
    vif.pslverr = t.slverr;
    if (t.write) begin
      vif.prdata = '0;
      t.rdata    = '0;
      if (!t.slverr) mem[widx] = vif.pwdata;
    end else begin
      if (t.rdata_override_en) rd = t.rdata_override;
      else                     rd = mem.exists(widx) ? mem[widx] : apb_agent_cfg::default_data(vif.paddr);
      vif.prdata = rd;
      t.rdata    = rd;
    end
  endtask

endclass
