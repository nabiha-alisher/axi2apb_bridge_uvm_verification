
class axi_seq_item extends uvm_sequence_item;

  `uvm_object_utils(axi_seq_item)

  // Write Address Channel (AW)

  rand bit        awvalid;
  rand bit [5:0]  awid;          // widened 4 -> 6 bits (bus is aw_id[5:0])
  rand bit [3:0]  awlen;
  rand bit [2:0]  awsize;
  rand bit [31:0] awaddr;
  rand bit [1:0]  awburst;
  rand bit [5:0]  awuser;        // NEW

  // Write Data Channel (W)

  rand bit        wvalid;
  rand bit [3:0]  wid;
  rand bit [31:0] wdata;
  rand bit [3:0]  wstrb;

  // Write Response Channel (B)

  bit             bready;
  bit             bvalid;
  bit [5:0]       bid;           // widened
  bit [1:0]       bresp;
  bit [5:0]       buser;         // NEW (captured by driver)

  // Read Address Channel (AR)

  rand bit        arvalid;
  rand bit [5:0]  arid;          // widened
  rand bit [31:0] araddr;
  rand bit [3:0]  arlen;
  rand bit [2:0]  arsize;
  rand bit [1:0]  arburst;
  rand bit [5:0]  aruser;        // NEW

  // Read Data Channel (R)

  bit             rready;
  bit             rvalid;
  bit [5:0]       rid;           // widened
  bit [31:0]      rdata;
  bit [1:0]       rresp;
  bit             rlast;
  bit [5:0]       ruser;         // NEW (captured by driver)

  // Handshake timing knobs (clock cycles).  NEW.
  //  aw_delay > 0, w_delay == 0 : W is presented BEFORE AW
  //  w_delay  > 0, aw_delay == 0: AW is presented BEFORE W
  //  b_delay / r_delay          : BREADY / RREADY back-pressure
  rand int unsigned aw_delay;
  rand int unsigned w_delay;
  rand int unsigned b_delay;
  rand int unsigned r_delay;

  // Constructor

  function new(string name = "axi_seq_item");
    super.new(name);
  endfunction

  //---------------------------------------------------------------------
  // Default constraints are SOFT so that uvm_do_with can override them
  // (boundary addresses, burst probes, odd sizes ...).
  //---------------------------------------------------------------------

  // FIXED burst only
  constraint c_awburst { soft awburst == 2'b00; }

  // Supported transfer sizes: 1, 2, 4 bytes
  constraint c_awsize  { soft awsize inside {3'b000, 3'b001, 3'b010}; }

  // Address range: 0 to 127
  constraint c_awaddr  { soft awaddr inside {[0:127]}; }

  // Supported burst lengths: 1, 2, 4, 8, 16 beats
  constraint c_awlen   { soft awlen inside {4'd0, 4'd1, 4'd3, 4'd7, 4'd15}; }

  constraint c_arburst { soft arburst == 2'b00; }
  constraint c_arsize  { soft arsize inside {3'b000, 3'b001, 3'b010}; }
  constraint c_araddr  { soft araddr inside {[0:127]}; }
  constraint c_arlen   { soft arlen inside {4'd0, 4'd1, 4'd3, 4'd7, 4'd15}; }

  // No delays unless a sequence asks for them
  constraint c_delays  {
    soft aw_delay == 0;
    soft w_delay  == 0;
    soft b_delay  == 0;
    soft r_delay  == 0;
  }

  // Needed so req.clone() (used to publish completed items) copies the fields.
  virtual function void do_copy(uvm_object rhs);
    axi_seq_item r;
    super.do_copy(rhs);
    if (!$cast(r, rhs))
      `uvm_fatal("AXI_ITEM", "do_copy: type mismatch")
    awvalid = r.awvalid;
    awid = r.awid;
    awlen = r.awlen;
    awsize = r.awsize;
    awaddr = r.awaddr;
    awburst = r.awburst;
    awuser = r.awuser;
    wvalid = r.wvalid;
    wid = r.wid;
    wdata = r.wdata;
    wstrb = r.wstrb;
    bready = r.bready;
    bvalid = r.bvalid;
    bid = r.bid;
    bresp = r.bresp;
    buser = r.buser;
    arvalid = r.arvalid;
    arid = r.arid;
    araddr = r.araddr;
    arlen = r.arlen;
    arsize = r.arsize;
    arburst = r.arburst;
    aruser = r.aruser;
    rready = r.rready;
    rvalid = r.rvalid;
    rid = r.rid;
    rdata = r.rdata;
    rresp = r.rresp;
    rlast = r.rlast;
    ruser = r.ruser;
    aw_delay = r.aw_delay;
    w_delay = r.w_delay;
    b_delay = r.b_delay;
    r_delay = r.r_delay;
  endfunction

endclass
