// =============================================================================
// axi_monitor : passive AXI monitor
//
//   req_ap  : published when AW / AR handshake happens. The item handle is
//             then *completed* in place (W beats are appended as they arrive;
//             R beats / B response are appended later).
//   done_ap : published when the response is complete (B handshake, or last R beat)
//
// W data that arrives before its AW is parked ("orphan") and attached later.
// =============================================================================
class axi_monitor extends uvm_monitor;

  `uvm_component_utils(axi_monitor)

  uvm_analysis_port #(axi_item) req_ap;
  uvm_analysis_port #(axi_item) done_ap;

  axi_agent_cfg cfg;
  axi_vif_t     vif;

  // write side
  axi_item      wr_q[$];          // writes waiting for B (AW order)
  axi_item      w_need_q[$];      // writes still missing W beats
  bit [63:0]    orphan_data[$];
  bit [7:0]     orphan_strb[$];
  // read side
  axi_item      rd_q[$];          // reads waiting for R (AR order)

  bit           in_reset;
  uvm_event     rst_ev;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    req_ap  = new("req_ap",  this);
    done_ap = new("done_ap", this);
    if (!uvm_config_db#(axi_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "axi_agent_cfg not found")
    vif    = cfg.vif;
    rst_ev = uvm_event_pool::get_global_pool().get("rst_assert");
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);
      if (vif.rst_n !== 1'b1) begin
        if (!in_reset) begin
          in_reset = 1;
          flush();
          rst_ev.trigger();
        end
        continue;
      end
      in_reset = 0;
      sample_aw();
      sample_w();
      sample_b();
      sample_ar();
      sample_r();
    end
  endtask

  function void flush();
    wr_q.delete(); w_need_q.delete(); orphan_data.delete(); orphan_strb.delete(); rd_q.delete();
  endfunction

  // ---------------------------------------------------------------- write address
  function void sample_aw();
    axi_item t;
    if (vif.aw_valid === 1'b1 && vif.aw_ready === 1'b1) begin
      t = axi_item::type_id::create("wr_obs");
      t.is_write = 1;
      t.id     = vif.aw_id;     t.addr   = vif.aw_addr;  t.len    = vif.aw_len;
      t.size   = vif.aw_size;   t.burst  = vif.aw_burst; t.lock   = vif.aw_lock;
      t.cache  = vif.aw_cache;  t.prot   = vif.aw_prot;  t.qos    = vif.aw_qos;
      t.region = vif.aw_region; t.user   = vif.aw_user;
      // adopt W beats that arrived before the address
      while (orphan_data.size() > 0 && t.data.size() < int'(t.len) + 1) begin
        t.data.push_back(orphan_data.pop_front());
        t.strb.push_back(orphan_strb.pop_front());
      end
      wr_q.push_back(t);
      if (t.data.size() < int'(t.len) + 1) w_need_q.push_back(t);
      req_ap.write(t);
    end
  endfunction

  // ---------------------------------------------------------------- write data
  function void sample_w();
    bit [63:0] d;
    bit [7:0]  s;
    axi_item   t;
    if (vif.w_valid === 1'b1 && vif.w_ready === 1'b1) begin
      d = '0; s = '0;
      d[AXI_DW-1:0] = vif.w_data;
      s[AXI_SW-1:0] = vif.w_strb;
      if (w_need_q.size() > 0) begin
        t = w_need_q[0];
        t.data.push_back(d);
        t.strb.push_back(s);
        if (vif.w_last !== (t.data.size() == int'(t.len) + 1))
          `uvm_error("AXI_MON", $sformatf("WLAST wrong on beat %0d of %0d (wlast=%b)",
                                          t.data.size(), int'(t.len) + 1, vif.w_last))
        if (t.data.size() == int'(t.len) + 1) void'(w_need_q.pop_front());
      end else begin
        orphan_data.push_back(d);
        orphan_strb.push_back(s);
      end
    end
  endfunction

  // ---------------------------------------------------------------- write response
  function void sample_b();
    axi_item t;
    if (vif.b_valid === 1'b1 && vif.b_ready === 1'b1) begin
      if (wr_q.size() == 0)
        `uvm_error("AXI_MON", "B response with no outstanding write")
      else begin
        t = wr_q.pop_front();
        t.bid   = vif.b_id;
        t.bresp = vif.b_resp;
        done_ap.write(t);
      end
    end
  endfunction

  // ---------------------------------------------------------------- read address
  function void sample_ar();
    axi_item t;
    if (vif.ar_valid === 1'b1 && vif.ar_ready === 1'b1) begin
      t = axi_item::type_id::create("rd_obs");
      t.is_write = 0;
      t.id     = vif.ar_id;     t.addr   = vif.ar_addr;  t.len    = vif.ar_len;
      t.size   = vif.ar_size;   t.burst  = vif.ar_burst; t.lock   = vif.ar_lock;
      t.cache  = vif.ar_cache;  t.prot   = vif.ar_prot;  t.qos    = vif.ar_qos;
      t.region = vif.ar_region; t.user   = vif.ar_user;
      rd_q.push_back(t);
      req_ap.write(t);
    end
  endfunction

  // ---------------------------------------------------------------- read data
  function void sample_r();
    bit [63:0] d;
    axi_item   t;
    if (vif.r_valid === 1'b1 && vif.r_ready === 1'b1) begin
      if (rd_q.size() == 0)
        `uvm_error("AXI_MON", "R beat with no outstanding read")
      else begin
        t = rd_q[0];
        d = '0;
        d[AXI_DW-1:0] = vif.r_data;
        t.rdata.push_back(d);
        t.rresp.push_back(vif.r_resp);
        t.rid.push_back(vif.r_id);
        t.rlast.push_back(vif.r_last);
        // complete on RLAST, or when all beats arrived (missing RLAST is reported by the scoreboard)
        if (vif.r_last === 1'b1 || t.rdata.size() == int'(t.len) + 1) begin
          void'(rd_q.pop_front());
          done_ap.write(t);
        end
      end
    end
  endfunction

endclass
