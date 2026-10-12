// =============================================================================
// axi_driver : AXI master driver
//
// Sequence items are handed over immediately to per-channel threads
// (AW / W / AR), so a sequence can queue many transactions and the channels
// run independently (AW before W, W before AW, read + write at the same time).
// B and R are accepted by two free-running threads with random ready.
// Signals are driven with non-blocking assignments at posedge clk.
// =============================================================================
class axi_driver extends uvm_driver #(axi_item);

  `uvm_component_utils(axi_driver)

  axi_agent_cfg       cfg;
  axi_vif_t           vif;
  uvm_phase           run_ph;
  bit                 obj_raised;

  mailbox #(axi_item) aw_mbx = new();
  mailbox #(axi_item) w_mbx  = new();
  mailbox #(axi_item) ar_mbx = new();

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axi_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "axi_agent_cfg not found")
    vif = cfg.vif;
  endfunction

  // ------------------------------------------------------------------ run
  task run_phase(uvm_phase phase);
    run_ph = phase;
    init_signals();
    fork
      fetch_loop();
      channel_manager();
    join
  endtask

  // take items from the sequencer and hand them to the channel threads
  task fetch_loop();
    axi_item t;
    forever begin
      seq_item_port.get_next_item(t);
      update_outstanding(+1);
      if (t.is_write) begin
        aw_mbx.put(t);
        w_mbx.put(t);
      end else
        ar_mbx.put(t);
      seq_item_port.item_done();
    end
  endtask

  // run the channel threads, restart them on every reset
  task channel_manager();
    forever begin
      if (vif.rst_n !== 1'b1) @(posedge vif.rst_n);
      fork : chans
        aw_thread();
        w_thread();
        ar_thread();
        b_thread();
        r_thread();
        @(negedge vif.rst_n);
      join_any
      disable chans;
      on_reset();
    end
  endtask

  task on_reset();
    axi_item d;
    while (aw_mbx.try_get(d)) begin end
    while (w_mbx.try_get(d))  begin end
    while (ar_mbx.try_get(d)) begin end
    init_signals();
    cfg.outstanding = 0;
    if (obj_raised) begin
      run_ph.drop_objection(this, "axi reset");
      obj_raised = 0;
    end
    @(posedge vif.rst_n);
  endtask

  function void init_signals();
    vif.aw_valid <= 0; vif.aw_id <= 0; vif.aw_addr <= 0; vif.aw_len <= 0; vif.aw_size <= 0;
    vif.aw_burst <= 0; vif.aw_lock <= 0; vif.aw_cache <= 0; vif.aw_prot <= 0; vif.aw_qos <= 0;
    vif.aw_region <= 0; vif.aw_user <= 0;
    vif.w_valid <= 0; vif.w_data <= 0; vif.w_strb <= 0; vif.w_last <= 0; vif.w_user <= 0;
    vif.b_ready <= 0;
    vif.ar_valid <= 0; vif.ar_id <= 0; vif.ar_addr <= 0; vif.ar_len <= 0; vif.ar_size <= 0;
    vif.ar_burst <= 0; vif.ar_lock <= 0; vif.ar_cache <= 0; vif.ar_prot <= 0; vif.ar_qos <= 0;
    vif.ar_region <= 0; vif.ar_user <= 0;
    vif.r_ready <= 0;
  endfunction

  function void update_outstanding(int d);
    if (d > 0) begin
      cfg.outstanding += d;
      if (!obj_raised) begin
        run_ph.raise_objection(this, "axi busy");
        obj_raised = 1;
      end
    end else begin
      if (cfg.outstanding > 0) cfg.outstanding--;
      if (cfg.outstanding == 0 && obj_raised) begin
        run_ph.drop_objection(this, "axi idle");
        obj_raised = 0;
      end
    end
  endfunction

  // wait n cycles; if n==0 and we are not already sitting on a clock edge, align to one
  task automatic wait_cycles(int unsigned n, ref bit at_edge);
    if (n > 0) repeat (n) @(posedge vif.clk);
    else if (!at_edge) @(posedge vif.clk);
    at_edge = 1;
  endtask

  // ------------------------------------------------------------------ AW
  task aw_thread();
    axi_item t;
    bit      at_edge = 0;
    forever begin
      if (at_edge) begin
        if (!aw_mbx.try_get(t)) begin at_edge = 0; aw_mbx.get(t); end
      end else
        aw_mbx.get(t);
      wait_cycles(t.addr_delay, at_edge);
      vif.aw_valid  <= 1'b1;
      vif.aw_id     <= t.id;
      vif.aw_addr   <= t.addr;
      vif.aw_len    <= t.len;
      vif.aw_size   <= t.size;
      vif.aw_burst  <= t.burst;
      vif.aw_lock   <= t.lock;
      vif.aw_cache  <= t.cache;
      vif.aw_prot   <= t.prot;
      vif.aw_qos    <= t.qos;
      vif.aw_region <= t.region;
      vif.aw_user   <= t.user;
      do @(posedge vif.clk); while (vif.aw_ready !== 1'b1);
      vif.aw_valid <= 1'b0;
      at_edge = 1;
    end
  endtask

  // ------------------------------------------------------------------ W
  task w_thread();
    axi_item t;
    bit      at_edge = 0;
    forever begin
      if (at_edge) begin
        if (!w_mbx.try_get(t)) begin at_edge = 0; w_mbx.get(t); end
      end else
        w_mbx.get(t);
      for (int unsigned i = 0; i <= t.len; i++) begin
        wait_cycles((i == 0) ? t.w_first_delay : t.get_gap(i), at_edge);
        vif.w_valid <= 1'b1;
        vif.w_data  <= t.data[i][AXI_DW-1:0];
        vif.w_strb  <= t.strb[i][AXI_SW-1:0];
        vif.w_last  <= (i == t.len);
        vif.w_user  <= t.w_user;
        do @(posedge vif.clk); while (vif.w_ready !== 1'b1);
        vif.w_valid <= 1'b0;
        vif.w_last  <= 1'b0;
        at_edge = 1;
      end
    end
  endtask

  // ------------------------------------------------------------------ AR
  task ar_thread();
    axi_item t;
    bit      at_edge = 0;
    forever begin
      if (at_edge) begin
        if (!ar_mbx.try_get(t)) begin at_edge = 0; ar_mbx.get(t); end
      end else
        ar_mbx.get(t);
      wait_cycles(t.addr_delay, at_edge);
      vif.ar_valid  <= 1'b1;
      vif.ar_id     <= t.id;
      vif.ar_addr   <= t.addr;
      vif.ar_len    <= t.len;
      vif.ar_size   <= t.size;
      vif.ar_burst  <= t.burst;
      vif.ar_lock   <= t.lock;
      vif.ar_cache  <= t.cache;
      vif.ar_prot   <= t.prot;
      vif.ar_qos    <= t.qos;
      vif.ar_region <= t.region;
      vif.ar_user   <= t.user;
      do @(posedge vif.clk); while (vif.ar_ready !== 1'b1);
      vif.ar_valid <= 1'b0;
      at_edge = 1;
    end
  endtask

  // ------------------------------------------------------------------ B / R (responses)
  task b_thread();
    forever begin
      @(posedge vif.clk);
      if (vif.b_valid === 1'b1 && vif.b_ready === 1'b1) update_outstanding(-1);
      vif.b_ready <= ($urandom_range(99) < cfg.b_ready_pct);
    end
  endtask

  task r_thread();
    forever begin
      @(posedge vif.clk);
      if (vif.r_valid === 1'b1 && vif.r_ready === 1'b1 && vif.r_last === 1'b1) update_outstanding(-1);
      vif.r_ready <= ($urandom_range(99) < cfg.r_ready_pct);
    end
  endtask

endclass
