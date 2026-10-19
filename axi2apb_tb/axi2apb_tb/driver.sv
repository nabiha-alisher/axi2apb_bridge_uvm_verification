//-------------------------------------------------------------------------
// axi_driver  (AXI master driver)
//
//  1. AW and W are driven IN PARALLEL (fork/join). The bridge FSM only
//     accepts a write when AWVALID and WVALID are both present.
//     req.aw_delay / req.w_delay shift one channel later than the other.
//  2. Request type chosen by req.awvalid / req.arvalid
//     (both set => write and read issued together, tests read priority).
//  3. req.b_delay / req.r_delay hold BREADY / RREADY low and check that
//     BVALID / RVALID and their payload stay stable meanwhile.
//  4. Every handshake has a timeout that raises a clear uvm_error instead
//     of letting the whole test die with PH_TIMEOUT.
//  5. Unused sideband signals are driven to 0 instead of X.
//-------------------------------------------------------------------------
class axi_driver extends uvm_driver #(axi_seq_item);

  `uvm_component_utils(axi_driver)

  virtual AXI_BUS.Master vif;

  int unsigned handshake_timeout = 1000;   // clock cycles

  // Completed transactions (with BID/BRESP/RDATA/... filled in) are
  // broadcast here -> coverage / scoreboard.
  uvm_analysis_port #(axi_seq_item) item_done_ap;

  function new(string name = "axi_driver", uvm_component parent = null);
    super.new(name, parent);
    item_done_ap = new("item_done_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual AXI_BUS.Master)::get(this, "", "vif", vif))
      `uvm_fatal("AXI_DRV", "Virtual interface not found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    reset_signals();
    wait (vif.rst_n === 1'b1);

    forever begin
      seq_item_port.get_next_item(req);

      if (req.awvalid && req.arvalid) begin
        fork
          write_transaction();
          read_transaction();
        join
      end
      else if (req.awvalid) write_transaction();
      else if (req.arvalid) read_transaction();
      else `uvm_warning("AXI_DRV", "Item has neither awvalid nor arvalid set - ignored")

      publish_item();
      seq_item_port.item_done();
    end
  endtask

  protected function void publish_item();
    axi_seq_item t;
    if ($cast(t, req.clone()))
      item_done_ap.write(t);
  endfunction

  // ---------------- signal init ----------------
  task reset_signals();
    vif.aw_valid = 0;  vif.w_valid  = 0;  vif.b_ready = 0;
    vif.ar_valid = 0;  vif.r_ready  = 0;

    vif.aw_id    = 0;  vif.aw_addr  = 0;  vif.aw_len   = 0;
    vif.aw_size  = 0;  vif.aw_burst = 0;

    vif.w_data   = 0;  vif.w_strb   = 0;  vif.w_last   = 0;

    vif.ar_id    = 0;  vif.ar_addr  = 0;  vif.ar_len   = 0;
    vif.ar_size  = 0;  vif.ar_burst = 0;

    drive_sideband_defaults();
  endtask

  // If your AXI_BUS modport does not contain one of these, delete that line.
  task drive_sideband_defaults();
    vif.aw_lock = 0;  vif.aw_cache = 0;  vif.aw_prot = 0;
    vif.aw_qos  = 0;  vif.aw_region = 0; vif.aw_user = 0;
    vif.w_user  = 0;
    vif.ar_lock = 0;  vif.ar_cache = 0;  vif.ar_prot = 0;
    vif.ar_qos  = 0;  vif.ar_region = 0; vif.ar_user = 0;
  endtask

  // ---------------- WRITE ----------------
  task write_transaction();
    fork
      drive_aw();
      drive_w();
    join
    drive_b();
  endtask

  task drive_aw();
    int unsigned cnt = 0;
    repeat (req.aw_delay) @(negedge vif.clk);
    @(negedge vif.clk);
    vif.aw_id    = req.awid;
    vif.aw_addr  = req.awaddr;
    vif.aw_len   = req.awlen;
    vif.aw_size  = req.awsize;
    vif.aw_burst = req.awburst;
    vif.aw_user  = req.awuser;
    vif.aw_valid = 1'b1;

    do begin @(posedge vif.clk); cnt++; end
    while (!vif.aw_ready && cnt < handshake_timeout);
    if (!vif.aw_ready)
      `uvm_error("AXI_DRV", $sformatf("Timeout (%0d clk) waiting for AWREADY", handshake_timeout))

    @(negedge vif.clk);
    vif.aw_valid = 0;
  endtask

  task drive_w();
    int unsigned cnt = 0;
    repeat (req.w_delay) @(negedge vif.clk);
    @(negedge vif.clk);
    vif.w_data  = req.wdata;
    vif.w_strb  = req.wstrb;
    vif.w_last  = 1'b1;
    vif.w_valid = 1'b1;

    do begin @(posedge vif.clk); cnt++; end
    while (!vif.w_ready && cnt < handshake_timeout);
    if (!vif.w_ready)
      `uvm_error("AXI_DRV", $sformatf("Timeout (%0d clk) waiting for WREADY", handshake_timeout))

    @(negedge vif.clk);
    vif.w_valid = 0;
    vif.w_last  = 0;
  endtask

  task drive_b();
    int unsigned cnt = 0;
    bit          seen = 0;
    bit [5:0]    id_q, user_q;
    bit [1:0]    resp_q;

    // BREADY back-pressure: hold BREADY low, BVALID must stay up and stable
    if (req.b_delay > 0) begin
      repeat (req.b_delay) begin
        @(posedge vif.clk);
        if (seen && !vif.b_valid)
          `uvm_error("AXI_DRV", "BVALID dropped before BREADY was given")
        if (vif.b_valid) begin
          if (seen && ({vif.b_id, vif.b_resp, vif.b_user} !== {id_q, resp_q, user_q}))
            `uvm_error("AXI_DRV", "B payload changed while BVALID=1 and BREADY=0")
          seen = 1;  id_q = vif.b_id;  resp_q = vif.b_resp;  user_q = vif.b_user;
        end
      end
      @(negedge vif.clk);
    end

    vif.b_ready = 1'b1;

    do begin @(posedge vif.clk); cnt++; end
    while (!vif.b_valid && cnt < handshake_timeout);
    if (!vif.b_valid)
      `uvm_error("AXI_DRV",
        $sformatf("Timeout (%0d clk) waiting for BVALID - bridge never completed the write (is APB PREADY being driven? is reset released?)",
                  handshake_timeout))
    else begin
      req.bid   = vif.b_id;
      req.bresp = vif.b_resp;
      req.buser = vif.b_user;
    end

    @(negedge vif.clk);
    vif.b_ready = 0;
  endtask

  // ---------------- READ ----------------
  task read_transaction();
    int unsigned cnt = 0;
    bit          seen = 0;
    bit [5:0]    id_q, user_q;
    bit [31:0]   data_q;
    bit [1:0]    resp_q;
    bit          last_q;

    @(negedge vif.clk);
    vif.ar_id    = req.arid;
    vif.ar_addr  = req.araddr;
    vif.ar_len   = req.arlen;
    vif.ar_size  = req.arsize;
    vif.ar_burst = req.arburst;
    vif.ar_user  = req.aruser;
    vif.ar_valid = 1'b1;

    do begin @(posedge vif.clk); cnt++; end
    while (!vif.ar_ready && cnt < handshake_timeout);
    if (!vif.ar_ready)
      `uvm_error("AXI_DRV", $sformatf("Timeout (%0d clk) waiting for ARREADY", handshake_timeout))

    @(negedge vif.clk);
    vif.ar_valid = 0;

    // RREADY back-pressure: RVALID and payload must hold
    if (req.r_delay > 0) begin
      repeat (req.r_delay) begin
        @(posedge vif.clk);
        if (seen && !vif.r_valid)
          `uvm_error("AXI_DRV", "RVALID dropped before RREADY was given")
        if (vif.r_valid) begin
          if (seen && ({vif.r_id, vif.r_data, vif.r_resp, vif.r_last, vif.r_user}
                       !== {id_q, data_q, resp_q, last_q, user_q}))
            `uvm_error("AXI_DRV", "R payload changed while RVALID=1 and RREADY=0")
          seen = 1;  id_q = vif.r_id;  data_q = vif.r_data;
          resp_q = vif.r_resp;  last_q = vif.r_last;  user_q = vif.r_user;
        end
      end
      @(negedge vif.clk);
    end

    vif.r_ready = 1'b1;
    cnt = 0;
    do begin @(posedge vif.clk); cnt++; end
    while (!vif.r_valid && cnt < handshake_timeout);
    if (!vif.r_valid)
      `uvm_error("AXI_DRV",
        $sformatf("Timeout (%0d clk) waiting for RVALID - bridge never completed the read", handshake_timeout))
    else begin
      req.rid   = vif.r_id;
      req.rdata = vif.r_data;
      req.rresp = vif.r_resp;
      req.rlast = vif.r_last;
      req.ruser = vif.r_user;
    end

    @(negedge vif.clk);
    vif.r_ready = 0;
  endtask

endclass : axi_driver
