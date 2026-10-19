
class axi_driver extends uvm_driver #(axi_seq_item);

  `uvm_component_utils(axi_driver)

  // Virtual interface
  virtual AXI_BUS.Master vif;

  // reqansaction handle
  axi_seq_item req;

  // Constructor
  function new(string name = "axi_driver",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Get virtual interface
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual AXI_BUS.Master)::get(
          this, "", "vif", vif))
      `uvm_fatal("DRIVER", "Virtual interface not found")
  endfunction

  // Run phase
  virtual task run_phase(uvm_phase phase);

    // Initialize signals
    reset_signals();

    // Wait for reset release
    wait(vif.rst_n == 1'b1);

    forever begin

      // Get reqansaction from sequencer
      seq_item_port.get_next_item(req);

     // if (req.is_write)
        write_reqansaction();
     // else
       // read_reqansaction();

      // Complete reqansaction
      seq_item_port.item_done();

    end
  endtask

  // Initialize AXI signals
  task reset_signals();

    vif.aw_valid = 0;
    vif.w_valid  = 0;
    vif.b_ready  = 0;

    vif.ar_valid = 0;
    vif.r_ready  = 0;

    vif.aw_id    = 0;
    vif.aw_addr  = 0;
    vif.aw_len   = 0;
    vif.aw_size  = 0;
    vif.aw_burst = 0;

    vif.w_data   = 0;
    vif.w_strb   = 0;
    vif.w_last   = 0;

    vif.ar_id    = 0;
    vif.ar_addr  = 0;
    vif.ar_len   = 0;
    vif.ar_size  = 0;
    vif.ar_burst = 0;

  endtask

  // ---------------- WRITE reqANSACTION ----------------

  task write_reqansaction();

    // Write address channel
    @(negedge vif.clk);

    vif.aw_id    = req.awid;
    vif.aw_addr  = req.awaddr;
    vif.aw_len   = req.awlen;
    vif.aw_size  = req.awsize;
    vif.aw_burst = req.awburst;
    vif.aw_valid = 1'b1;

    // Wait for AW handshake
    do begin
      @(posedge vif.clk);
    end while (!vif.aw_ready);

    @(negedge vif.clk);
    vif.aw_valid = 0;

    // Write data channel
    vif.w_data  = req.wdata;
    vif.w_strb  = req.wstrb;
    vif.w_last  = 1'b1;
    vif.w_valid = 1'b1;

    // Wait for W handshake
    do begin
      @(posedge vif.clk);
    end while (!vif.w_ready);

    @(negedge vif.clk);
    vif.w_valid = 0;
    vif.w_last  = 0;

    // Write response channel
    vif.b_ready = 1'b1;

    do begin
      @(posedge vif.clk);
    end while (!vif.b_valid);

    req.bresp = vif.b_resp;

    @(negedge vif.clk);
    vif.b_ready = 0;

  endtask

  // ---------------- READ reqANSACTION ----------------

  task read_reqansaction();

    // Read address channel
    @(negedge vif.clk);

    vif.ar_id    = req.arid;
    vif.ar_addr  = req.araddr;
    vif.ar_len   = req.arlen;
    vif.ar_size  = req.arsize;
    vif.ar_burst = req.arburst;
    vif.ar_valid = 1'b1;

    // Wait for AR handshake
    do begin
      @(posedge vif.clk);
    end while (!vif.ar_ready);

    @(negedge vif.clk);
    vif.ar_valid = 0;

    // Read data channel
    vif.r_ready = 1'b1;

    do begin
      @(posedge vif.clk);
    end while (!vif.r_valid);

    // Capture response
    req.rdata = vif.r_data;
    req.rresp = vif.r_resp;

    @(negedge vif.clk);
    vif.r_ready = 0;

  endtask

endclass

