
class direct_write_seq extends uvm_sequence #(axi_seq_item);

  `uvm_object_utils(direct_write_seq)
 `uvm_declare_p_sequencer(axi_sequencer)
  axi_seq_item req;

  function new(string name = "direct_write_seq");
    super.new(name);
  endfunction

  task body();

    req = axi_seq_item::type_id::create("req");

    start_item(req);

    // AW Channel

    req.awvalid = 1'b1;
    req.awid    = 4'd1;
    req.awaddr  = 32'd20;
    req.awlen   = 4'd0;
    req.awsize  = 3'b010;
    req.awburst = 2'b00;
   
 // W Channel

    req.wvalid = 1'b1;

  //  req.wdata = new[1];
    //req.wstrb = new[1];

    req.wdata = 32'hAABBCCDD;
    req.wstrb = 4'b1111;

//B Channel
    req.bready = 1'b1;

    finish_item(req);

  endtask

endclass

class direct_read_seq extends uvm_sequence #(axi_seq_item);

  `uvm_object_utils(direct_read_seq)

  axi_seq_item req;

  function new(string name = "direct_read_seq");
    super.new(name);
  endfunction

  task body();

    req = axi_seq_item::type_id::create("req");

    start_item(req);
//AR Channel
    req.arvalid = 1'b1;
    req.arid    = 4'd1;
    req.araddr  = 32'd20;
    req.arlen   = 4'd0;
    req.arsize  = 3'b010;
    req.arburst = 2'b00;
// R Channel
    req.rready = 1'b1;

    finish_item(req);

  endtask

endclass



//=========================================================================
//  uvm_do_with SEQUENCES
//
//  RULES used in every uvm_do_with below
//   - awvalid / wvalid / arvalid are rand in axi_seq_item, so EVERY item
//     pins them:   write -> awvalid=1 wvalid=1 arvalid=0
//                  read  -> awvalid=0 wvalid=0 arvalid=1
//                  both  -> all three = 1  (read/write priority test)
//   - awlen / arlen are 0 for functional tests (the bridge is single-beat)
//   - sequence knobs are plain members (wr_addr, rd_id ...) so they never
//     collide with item field names inside the constraint block
//=========================================================================


//-------------------------------------------------------------------------
// axi_base_seq : response checkers shared by all sequences
//   BID/BUSER must equal AWID/AWUSER, RID/RUSER must equal ARID/ARUSER,
//   RLAST must be 1.  BRESP/RRESP != OKAY is only a warning because the
//   supplied RTL is documented to return OKAY always.
//-------------------------------------------------------------------------
class axi_base_seq extends uvm_sequence #(axi_seq_item);

  `uvm_object_utils(axi_base_seq)

  function new(string name = "axi_base_seq");
    super.new(name);
  endfunction

  protected function void check_wr(axi_seq_item t);
    if (t.bid !== t.awid)
      `uvm_error(get_type_name(), $sformatf("BID 0x%0h != AWID 0x%0h", t.bid, t.awid))
    if (t.buser !== t.awuser)
      `uvm_error(get_type_name(), $sformatf("BUSER 0x%0h != AWUSER 0x%0h", t.buser, t.awuser))
    if (t.bresp !== 2'b00)
      `uvm_warning(get_type_name(), $sformatf("BRESP=%0b (expected OKAY from supplied RTL)", t.bresp))
  endfunction

  protected function void check_rd(axi_seq_item t);
    if (t.rid !== t.arid)
      `uvm_error(get_type_name(), $sformatf("RID 0x%0h != ARID 0x%0h", t.rid, t.arid))
    if (t.ruser !== t.aruser)
      `uvm_error(get_type_name(), $sformatf("RUSER 0x%0h != ARUSER 0x%0h", t.ruser, t.aruser))
    if (t.rlast !== 1'b1)
      `uvm_error(get_type_name(), "RLAST not asserted on single-beat read")
    if (t.rresp !== 2'b00)
      `uvm_warning(get_type_name(), $sformatf("RRESP=%0b (expected OKAY from supplied RTL)", t.rresp))
  endfunction

  protected function void compare_data(string what, bit [31:0] got, bit [31:0] exp);
    if (got !== exp)
      `uvm_error(get_type_name(), $sformatf("%s mismatch: got 0x%08h expected 0x%08h", what, got, exp))
  endfunction

endclass : axi_base_seq


//-------------------------------------------------------------------------
// 1) axi_single_wr_seq   [plan: AW/W handshake, write->APB, B channel,
//                         BREADY backpressure, ID/USER on B]
//    One fully-directed write.  All timing knobs available.
//-------------------------------------------------------------------------
class axi_single_wr_seq extends axi_base_seq;

  `uvm_object_utils(axi_single_wr_seq)

  bit [5:0]    wr_id   = 6'd1;
  bit [31:0]   wr_addr = 32'h20;
  bit [31:0]   wr_data = 32'hA5A5_5A5A;
  bit [3:0]    wr_strb = 4'hF;
  bit [5:0]    wr_user = 6'd0;
  int unsigned aw_dly  = 0;
  int unsigned w_dly   = 0;
  int unsigned b_dly   = 0;

  function new(string name = "axi_single_wr_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_do_with(req, {
      awvalid == 1;  wvalid == 1;  arvalid == 0;
      awid    == wr_id;
      awaddr  == wr_addr;
      awlen   == 0;
      awsize  == 3'b010;
      awburst == 2'b00;
      awuser  == wr_user;
      wdata   == wr_data;
      wstrb   == wr_strb;
      aw_delay == aw_dly;
      w_delay  == w_dly;
      b_delay  == b_dly;
    })
    check_wr(req);
  endtask

endclass : axi_single_wr_seq


//-------------------------------------------------------------------------
// 2) axi_single_rd_seq   [plan: AR handshake, read->APB, RDATA, RLAST,
//                         RREADY backpressure, ID/USER on R]
//-------------------------------------------------------------------------
class axi_single_rd_seq extends axi_base_seq;

  `uvm_object_utils(axi_single_rd_seq)

  bit [5:0]    rd_id      = 6'd1;
  bit [31:0]   rd_addr    = 32'h20;
  bit [5:0]    rd_user    = 6'd0;
  int unsigned r_dly      = 0;
  bit          check_data = 0;        // 1: compare RDATA with exp_data
  bit [31:0]   exp_data;

  function new(string name = "axi_single_rd_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_do_with(req, {
      awvalid == 0;  wvalid == 0;  arvalid == 1;
      arid    == rd_id;
      araddr  == rd_addr;
      arlen   == 0;
      arsize  == 3'b010;
      arburst == 2'b00;
      aruser  == rd_user;
      r_delay == r_dly;
    })
    check_rd(req);
    if (check_data) compare_data("RDATA", req.rdata, exp_data);
  endtask

endclass : axi_single_rd_seq


//-------------------------------------------------------------------------
// 3) axi_wr_rd_back_seq   [plan: write conversion + PRDATA capture/RDATA]
//    Random data written, read back from the same address, compared.
//-------------------------------------------------------------------------
class axi_wr_rd_back_seq extends axi_base_seq;

  `uvm_object_utils(axi_wr_rd_back_seq)

  bit [31:0] rw_addr = 32'h40;
  bit [31:0] exp;

  function new(string name = "axi_wr_rd_back_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_do_with(req, {
      awvalid == 1;  wvalid == 1;  arvalid == 0;
      awid == 6'd2;  awaddr == rw_addr;
      awlen == 0;    awsize == 3'b010;  awburst == 2'b00;
      wstrb == 4'hF;
    })
    check_wr(req);
    exp = req.wdata;

    `uvm_do_with(req, {
      awvalid == 0;  wvalid == 0;  arvalid == 1;
      arid == 6'd2;  araddr == rw_addr;
      arlen == 0;    arsize == 3'b010;  arburst == 2'b00;
    })
    check_rd(req);
    compare_data("Read-back", req.rdata, exp);
  endtask

endclass : axi_wr_rd_back_seq


//-------------------------------------------------------------------------
// 4) axi_aw_w_order_seq   [plan: AW handshake, W handshake]
//    Write accepted only when AW and W are both valid, so test both orders
//    with several gaps:  AW first / W late  and  W first / AW late.
//-------------------------------------------------------------------------
class axi_aw_w_order_seq extends axi_base_seq;

  `uvm_object_utils(axi_aw_w_order_seq)

  int unsigned gaps[3] = '{1, 2, 5};
  bit [31:0]   exp;

  function new(string name = "axi_aw_w_order_seq");
    super.new(name);
  endfunction

  virtual task body();
    foreach (gaps[i]) begin
      int unsigned gap = gaps[i];
      bit [31:0]   adr = 32'h60 + 8*i;

      // ---- AW first, W gap cycles later ----
      `uvm_do_with(req, {
        awvalid == 1;  wvalid == 1;  arvalid == 0;
        awid == 6'd5;  awaddr == adr;  awlen == 0;  awsize == 3'b010;  awburst == 2'b00;
        wstrb == 4'hF;
        aw_delay == 0;  w_delay == gap;
      })
      check_wr(req);
      exp = req.wdata;
      `uvm_do_with(req, {
        awvalid == 0;  wvalid == 0;  arvalid == 1;
        arid == 6'd5;  araddr == adr;  arlen == 0;  arsize == 3'b010;  arburst == 2'b00;
      })
      check_rd(req);
      compare_data($sformatf("AW-first gap=%0d read-back", gap), req.rdata, exp);

      // ---- W first, AW gap cycles later ----
      `uvm_do_with(req, {
        awvalid == 1;  wvalid == 1;  arvalid == 0;
        awid == 6'd6;  awaddr == adr + 4;  awlen == 0;  awsize == 3'b010;  awburst == 2'b00;
        wstrb == 4'hF;
        aw_delay == gap;  w_delay == 0;
      })
      check_wr(req);
      exp = req.wdata;
      `uvm_do_with(req, {
        awvalid == 0;  wvalid == 0;  arvalid == 1;
        arid == 6'd6;  araddr == adr + 4;  arlen == 0;  arsize == 3'b010;  arburst == 2'b00;
      })
      check_rd(req);
      compare_data($sformatf("W-first gap=%0d read-back", gap), req.rdata, exp);
    end
  endtask

endclass : axi_aw_w_order_seq


//-------------------------------------------------------------------------
// 5) axi_wstrb_seq   [plan: unsupported features - WSTRB]
//    APB bus has no PSTRB, and the FSM ignores WSTRB, so the whole word
//    is expected to reach APB.  This sequence only REPORTS what it saw;
//    the pass/fail judgement belongs in the scoreboard / report.
//-------------------------------------------------------------------------
class axi_wstrb_seq extends axi_base_seq;

  `uvm_object_utils(axi_wstrb_seq)

  bit [3:0] strobes[8] = '{4'h0, 4'h1, 4'h2, 4'h4, 4'h8, 4'h3, 4'hC, 4'hF};

  function new(string name = "axi_wstrb_seq");
    super.new(name);
  endfunction

  virtual task body();
    foreach (strobes[i]) begin
      bit [3:0]  st  = strobes[i];
      bit [31:0] adr = 32'h10 + 4*i;
      bit [31:0] sent;

      `uvm_do_with(req, {
        awvalid == 1;  wvalid == 1;  arvalid == 0;
        awid == 6'd7;  awaddr == adr;  awlen == 0;  awsize == 3'b010;  awburst == 2'b00;
        wdata == 32'h1122_3344;
        wstrb == st;
      })
      check_wr(req);
      sent = req.wdata;

      `uvm_do_with(req, {
        awvalid == 0;  wvalid == 0;  arvalid == 1;
        arid == 6'd7;  araddr == adr;  arlen == 0;  arsize == 3'b010;  arburst == 2'b00;
      })
      check_rd(req);
      `uvm_info(get_type_name(),
        $sformatf("OBSERVED: WSTRB=%04b sent 0x%08h read-back 0x%08h (%s)",
                  st, sent, req.rdata, (sent === req.rdata) ? "WSTRB ignored" : "WSTRB affected data"),
        UVM_LOW)
    end
  endtask

endclass : axi_wstrb_seq


//-------------------------------------------------------------------------
// 6) axi_bready_seq   [plan: B channel response and BREADY backpressure]
//    BREADY held low 1..8 cycles; the driver checks BVALID/payload hold.
//-------------------------------------------------------------------------
class axi_bready_seq extends axi_base_seq;

  `uvm_object_utils(axi_bready_seq)

  int unsigned num = 8;

  function new(string name = "axi_bready_seq");
    super.new(name);
  endfunction

  virtual task body();
    repeat (num) begin
      `uvm_do_with(req, {
        awvalid == 1;  wvalid == 1;  arvalid == 0;
        awlen == 0;  awsize == 3'b010;  awburst == 2'b00;
        b_delay inside {[1:8]};
      })
      check_wr(req);
    end
  endtask

endclass : axi_bready_seq


//-------------------------------------------------------------------------
// 7) axi_rready_seq   [plan: RVALID/RREADY backpressure and RLAST]
//    RREADY held low 1..8 cycles; the driver checks RVALID/payload hold.
//-------------------------------------------------------------------------
class axi_rready_seq extends axi_base_seq;

  `uvm_object_utils(axi_rready_seq)

  int unsigned num = 8;
  bit [31:0]   exp;

  function new(string name = "axi_rready_seq");
    super.new(name);
  endfunction

  virtual task body();
    // known data to read back
    `uvm_do_with(req, {
      awvalid == 1;  wvalid == 1;  arvalid == 0;
      awid == 6'd9;  awaddr == 32'h50;  awlen == 0;  awsize == 3'b010;  awburst == 2'b00;
      wstrb == 4'hF;
    })
    check_wr(req);
    exp = req.wdata;

    repeat (num) begin
      `uvm_do_with(req, {
        awvalid == 0;  wvalid == 0;  arvalid == 1;
        araddr == 32'h50;  arlen == 0;  arsize == 3'b010;  arburst == 2'b00;
        r_delay inside {[1:8]};
      })
      check_rd(req);
      compare_data("RDATA after RREADY delay", req.rdata, exp);
    end
  endtask

endclass : axi_rready_seq


//-------------------------------------------------------------------------
// 8) axi_id_user_seq   [plan: ID and USER propagation, different ID/USER]
//    idx 0 -> ID=0 / USER=0, idx 1 -> ID=63 / USER=63, rest random.
//    check_wr / check_rd compare BID/BUSER and RID/RUSER with the request.
//-------------------------------------------------------------------------
class axi_id_user_seq extends axi_base_seq;

  `uvm_object_utils(axi_id_user_seq)

  int unsigned num = 12;

  function new(string name = "axi_id_user_seq");
    super.new(name);
  endfunction

  virtual task body();
    for (int idx = 0; idx < num; idx++) begin
      bit [31:0] adr = 32'h08 + 4*idx;

      `uvm_do_with(req, {
        awvalid == 1;  wvalid == 1;  arvalid == 0;
        awaddr == adr;  awlen == 0;  awsize == 3'b010;  awburst == 2'b00;
        (idx == 0) -> (awid == 6'd0  && awuser == 6'd0);
        (idx == 1) -> (awid == 6'h3F && awuser == 6'h3F);
      })
      check_wr(req);

      `uvm_do_with(req, {
        awvalid == 0;  wvalid == 0;  arvalid == 1;
        araddr == adr;  arlen == 0;  arsize == 3'b010;  arburst == 2'b00;
        (idx == 0) -> (arid == 6'd0  && aruser == 6'd0);
        (idx == 1) -> (arid == 6'h3F && aruser == 6'h3F);
      })
      check_rd(req);
    end
  endtask

endclass : axi_id_user_seq


//-------------------------------------------------------------------------
// 9) axi_back_to_back_seq   [plan: back-to-back transactions]
//    A) N writes in a row   B) N reads in a row   C) alternating WR/RD
//-------------------------------------------------------------------------
class axi_back_to_back_seq extends axi_base_seq;

  `uvm_object_utils(axi_back_to_back_seq)

  int unsigned num = 8;
  bit [31:0]   exp[bit [31:0]];

  function new(string name = "axi_back_to_back_seq");
    super.new(name);
  endfunction

  virtual task body();
    // A) writes
    for (int i = 0; i < num; i++) begin
      bit [31:0] adr = 32'h00 + 4*i;
      `uvm_do_with(req, {
        awvalid == 1;  wvalid == 1;  arvalid == 0;
        awaddr == adr;  awlen == 0;  awsize == 3'b010;  awburst == 2'b00;
        wstrb == 4'hF;
      })
      check_wr(req);
      exp[adr] = req.wdata;
    end

    // B) reads
    for (int i = 0; i < num; i++) begin
      bit [31:0] adr = 32'h00 + 4*i;
      `uvm_do_with(req, {
        awvalid == 0;  wvalid == 0;  arvalid == 1;
        araddr == adr;  arlen == 0;  arsize == 3'b010;  arburst == 2'b00;
      })
      check_rd(req);
      compare_data($sformatf("B2B read @0x%0h", adr), req.rdata, exp[adr]);
    end

    // C) alternating write / read
    for (int i = 0; i < num; i++) begin
      bit [31:0] adr = 32'h40 + 4*i;
      `uvm_do_with(req, {
        awvalid == 1;  wvalid == 1;  arvalid == 0;
        awaddr == adr;  awlen == 0;  awsize == 3'b010;  awburst == 2'b00;
        wstrb == 4'hF;
      })
      check_wr(req);
      exp[adr] = req.wdata;
      `uvm_do_with(req, {
        awvalid == 0;  wvalid == 0;  arvalid == 1;
        araddr == adr;  arlen == 0;  arsize == 3'b010;  arburst == 2'b00;
      })
      check_rd(req);
      compare_data($sformatf("Alternating read @0x%0h", adr), req.rdata, exp[adr]);
    end
  endtask

endclass : axi_back_to_back_seq


//-------------------------------------------------------------------------
// 10) axi_rand_mem_seq   [plan: different address / data / ID / USER]
//     Random writes (word aligned, 0..127) then read every written
//     address and compare against a local reference memory.
//-------------------------------------------------------------------------
class axi_rand_mem_seq extends axi_base_seq;

  `uvm_object_utils(axi_rand_mem_seq)

  int unsigned num = 30;
  bit [31:0]   exp[bit [31:0]];

  function new(string name = "axi_rand_mem_seq");
    super.new(name);
  endfunction

  virtual task body();
    repeat (num) begin
      `uvm_do_with(req, {
        awvalid == 1;  wvalid == 1;  arvalid == 0;
        awlen == 0;  awsize == 3'b010;  awburst == 2'b00;
        awaddr[1:0] == 2'b00;
        wstrb == 4'hF;
        aw_delay inside {[0:2]};
        w_delay  inside {[0:2]};
        b_delay  inside {[0:6]};
      })
      check_wr(req);
      exp[req.awaddr] = req.wdata;
    end

    foreach (exp[a]) begin
      bit [31:0] adr = a;
      `uvm_do_with(req, {
        awvalid == 0;  wvalid == 0;  arvalid == 1;
        araddr == adr;  arlen == 0;  arsize == 3'b010;  arburst == 2'b00;
        r_delay inside {[0:6]};
      })
      check_rd(req);
      compare_data($sformatf("Random read @0x%0h", adr), req.rdata, exp[adr]);
    end
  endtask

endclass : axi_rand_mem_seq


//-------------------------------------------------------------------------
// 11) axi_boundary_seq   [plan: boundary addresses and parameter-width]
//     Set apb_addr_width to the DUT's APB_ADDR_WIDTH.  Addresses that
//     differ only above that width must alias, so the expected value is
//     tracked under the MASKED address.
//-------------------------------------------------------------------------
class axi_boundary_seq extends axi_base_seq;

  `uvm_object_utils(axi_boundary_seq)

  int unsigned apb_addr_width = 32;

  bit [31:0] addrs[8] = '{32'h0000_0000, 32'h0000_0004, 32'h0000_007C, 32'h0000_0080,
                          32'h0000_0FFC, 32'h0000_FFFC, 32'h0001_0000, 32'hFFFF_FFFC};
  bit [31:0] pats[8]  = '{32'h0000_0000, 32'hFFFF_FFFF, 32'h5555_5555, 32'hAAAA_AAAA,
                          32'h0000_0001, 32'h8000_0000, 32'h0F0F_0F0F, 32'hF0F0_F0F0};
  bit [31:0] exp[bit [31:0]];

  function new(string name = "axi_boundary_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] mask = (apb_addr_width >= 32) ? 32'hFFFF_FFFF
                                             : ((32'h1 << apb_addr_width) - 1);

    foreach (addrs[i]) begin
      bit [31:0] adr = addrs[i];
      bit [31:0] dat = pats[i];
      `uvm_do_with(req, {
        awvalid == 1;  wvalid == 1;  arvalid == 0;
        awaddr == adr;  awlen == 0;  awsize == 3'b010;  awburst == 2'b00;
        wdata == dat;  wstrb == 4'hF;
      })
      check_wr(req);
      exp[adr & mask] = dat;
    end

    foreach (addrs[i]) begin
      bit [31:0] adr = addrs[i];
      `uvm_do_with(req, {
        awvalid == 0;  wvalid == 0;  arvalid == 1;
        araddr == adr;  arlen == 0;  arsize == 3'b010;  arburst == 2'b00;
      })
      check_rd(req);
      compare_data($sformatf("Boundary read @0x%08h (masked 0x%08h)", adr, adr & mask),
                   req.rdata, exp[adr & mask]);
    end
  endtask

endclass : axi_boundary_seq


//-------------------------------------------------------------------------
// 12) axi_rd_wr_same_time_seq   [plan: simultaneous read/write priority]
//     Pre-load ADDR with old_data, then present AW+W+AR together to the
//     SAME address with new_data.  Read has priority => the read must
//     return OLD data; the write must still land afterwards.
//-------------------------------------------------------------------------
class axi_rd_wr_same_time_seq extends axi_base_seq;

  `uvm_object_utils(axi_rd_wr_same_time_seq)

  bit [31:0] sim_addr = 32'h24;
  bit [31:0] old_data = 32'h0123_4567;
  bit [31:0] new_data = 32'hF0F0_F0F0;

  function new(string name = "axi_rd_wr_same_time_seq");
    super.new(name);
  endfunction

  virtual task body();
    // pre-load
    `uvm_do_with(req, {
      awvalid == 1;  wvalid == 1;  arvalid == 0;
      awaddr == sim_addr;  awlen == 0;  awsize == 3'b010;  awburst == 2'b00;
      wdata == old_data;  wstrb == 4'hF;
    })
    check_wr(req);

    // simultaneous write + read, same address
    `uvm_do_with(req, {
      awvalid == 1;  wvalid == 1;  arvalid == 1;
      awid == 6'd3;  awaddr == sim_addr;  awlen == 0;  awsize == 3'b010;  awburst == 2'b00;
      arid == 6'd4;  araddr == sim_addr;  arlen == 0;  arsize == 3'b010;  arburst == 2'b00;
      wdata == new_data;  wstrb == 4'hF;
    })
    check_wr(req);
    check_rd(req);

    if (req.rdata === old_data)
      `uvm_info(get_type_name(), "OBSERVED: read served BEFORE write (read priority confirmed)", UVM_LOW)
    else if (req.rdata === new_data)
      `uvm_error(get_type_name(), "Write was served BEFORE read - read priority NOT observed")
    else
      `uvm_error(get_type_name(),
        $sformatf("Unexpected RDATA 0x%08h (old 0x%08h, new 0x%08h)", req.rdata, old_data, new_data))

    // the write must not have been lost
    `uvm_do_with(req, {
      awvalid == 0;  wvalid == 0;  arvalid == 1;
      araddr == sim_addr;  arlen == 0;  arsize == 3'b010;  arburst == 2'b00;
    })
    check_rd(req);
    compare_data("Read after simultaneous write", req.rdata, new_data);

    // simultaneous write + read to DIFFERENT addresses:
    // read of sim_addr must still return new_data, write to sim_addr+4 must land
    `uvm_do_with(req, {
      awvalid == 1;  wvalid == 1;  arvalid == 1;
      awid == 6'd10;  awaddr == sim_addr + 4;  awlen == 0;  awsize == 3'b010;  awburst == 2'b00;
      arid == 6'd11;  araddr == sim_addr;      arlen == 0;  arsize == 3'b010;  arburst == 2'b00;
      wdata == 32'h0BAD_F00D;  wstrb == 4'hF;
    })
    check_wr(req);
    check_rd(req);
    compare_data("Simultaneous (diff addr) read", req.rdata, new_data);

    `uvm_do_with(req, {
      awvalid == 0;  wvalid == 0;  arvalid == 1;
      araddr == sim_addr + 4;  arlen == 0;  arsize == 3'b010;  arburst == 2'b00;
    })
    check_rd(req);
    compare_data("Read of simultaneous (diff addr) write", req.rdata, 32'h0BAD_F00D);
  endtask

endclass : axi_rd_wr_same_time_seq


//-------------------------------------------------------------------------
// 13) axi_unsupported_probe_seq   [plan: bursts / sizes - document, don't assume]
//     Drives awlen/arlen > 0, INCR/WRAP bursts and sizes 1/2/4 with odd
//     offsets.  The driver sends ONE W beat, which is all the bridge FSM
//     looks at.  Nothing here is judged pass/fail; every result is logged
//     as OBSERVED for the verification report, and the APB monitor shows
//     how many APB transfers each AXI request produced.
//-------------------------------------------------------------------------
class axi_unsupported_probe_seq extends axi_base_seq;

  `uvm_object_utils(axi_unsupported_probe_seq)

  bit [3:0] lens[4]   = '{4'd1, 4'd3, 4'd7, 4'd15};
  bit [1:0] bursts[3] = '{2'b00, 2'b01, 2'b10};   // FIXED, INCR, WRAP
  bit [2:0] sizes[3]  = '{3'b000, 3'b001, 3'b010};

  function new(string name = "axi_unsupported_probe_seq");
    super.new(name);
  endfunction

  virtual task body();
    // ---- burst length x burst type ----
    foreach (lens[i]) foreach (bursts[j]) begin
      bit [3:0]  ln  = lens[i];
      bit [1:0]  bt  = bursts[j];
      bit [31:0] adr = 32'h20;

      `uvm_do_with(req, {
        awvalid == 1;  wvalid == 1;  arvalid == 0;
        awid == 6'd8;  awaddr == adr;  awlen == ln;  awsize == 3'b010;  awburst == bt;
        wstrb == 4'hF;
      })
      `uvm_info(get_type_name(),
        $sformatf("OBSERVED write awlen=%0d awburst=%0d (1 W beat sent): BRESP=%0b BID=0x%0h",
                  ln, bt, req.bresp, req.bid), UVM_LOW)

      `uvm_do_with(req, {
        awvalid == 0;  wvalid == 0;  arvalid == 1;
        arid == 6'd8;  araddr == adr;  arlen == ln;  arsize == 3'b010;  arburst == bt;
      })
      `uvm_info(get_type_name(),
        $sformatf("OBSERVED read  arlen=%0d arburst=%0d: RLAST=%0b RRESP=%0b RDATA=0x%08h",
                  ln, bt, req.rlast, req.rresp, req.rdata), UVM_LOW)
    end

    // ---- transfer size x byte offset ----
    foreach (sizes[i]) for (int off = 0; off < 4; off++) begin
      bit [2:0]  sz  = sizes[i];
      bit [31:0] adr = 32'h30 + off;

      `uvm_do_with(req, {
        awvalid == 1;  wvalid == 1;  arvalid == 0;
        awid == 6'd9;  awaddr == adr;  awlen == 0;  awsize == sz;  awburst == 2'b00;
        wstrb == 4'hF;
      })
      `uvm_do_with(req, {
        awvalid == 0;  wvalid == 0;  arvalid == 1;
        arid == 6'd9;  araddr == adr;  arlen == 0;  arsize == sz;  arburst == 2'b00;
      })
      `uvm_info(get_type_name(),
        $sformatf("OBSERVED size=%0d addr=0x%08h: RRESP=%0b RDATA=0x%08h",
                  sz, adr, req.rresp, req.rdata), UVM_LOW)
    end
  endtask

endclass : axi_unsupported_probe_seq
