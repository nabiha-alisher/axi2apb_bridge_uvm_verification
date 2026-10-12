// =============================================================================
// Sequences
// =============================================================================

// -----------------------------------------------------------------------------
// base sequence: helpers shared by all sequences
// -----------------------------------------------------------------------------
class axi_base_seq extends uvm_sequence #(axi_item);

  `uvm_object_utils(axi_base_seq)

  axi_agent_cfg cfg;

  function new(string name = "axi_base_seq");
    super.new(name);
  endfunction

  task pre_body();
    if (!uvm_config_db#(axi_agent_cfg)::get(m_sequencer, "", "cfg", cfg))
      `uvm_warning("SEQ", "axi_agent_cfg not found: wait_axi_idle() falls back to a fixed delay")
  endtask

  // wait until every transaction handed to the driver has received its response
  task wait_axi_idle();
    if (cfg == null) begin
      #2us;
      return;
    end
    @(posedge cfg.vif.clk);
    wait (cfg.outstanding == 0);
    repeat (4) @(posedge cfg.vif.clk);
  endtask

  // full-width single write
  task send_single_write(bit [31:0] a, bit [63:0] d, int unsigned adly = 0, int unsigned wdly = 0);
    axi_item t = axi_item::type_id::create("wr");
    start_item(t);
    if (!t.randomize() with { is_write == 1; len == 0; addr == local::a; data[0] == local::d;
                              addr_delay == local::adly; w_first_delay == local::wdly; })
      `uvm_fatal("RAND", "randomize failed (send_single_write)")
    finish_item(t);
  endtask

  // full-width single read
  task send_single_read(bit [31:0] a, int unsigned adly = 0);
    axi_item t = axi_item::type_id::create("rd");
    start_item(t);
    if (!t.randomize() with { is_write == 0; len == 0; addr == local::a; addr_delay == local::adly; })
      `uvm_fatal("RAND", "randomize failed (send_single_read)")
    finish_item(t);
  endtask

endclass

// -----------------------------------------------------------------------------
// random traffic with knobs
// -----------------------------------------------------------------------------
class axi_rand_seq extends axi_base_seq;

  `uvm_object_utils(axi_rand_seq)

  int unsigned num_items   = 20;
  int unsigned wr_pct      = 50;
  bit          burst_ok    = 0;
  bit          narrow_ok   = 0;
  bit          w_gaps_ok   = 0;
  int unsigned max_len     = 7;
  strb_mode_e  strb_mode   = STRB_FULL;
  bit          idle_between = 0;   // wait for every transaction to finish before sending the next

  function new(string name = "axi_rand_seq");
    super.new(name);
  endfunction

  task body();
    repeat (num_items) begin
      axi_item t = axi_item::type_id::create("t");
      t.burst_ok  = burst_ok;
      t.narrow_ok = narrow_ok;
      t.w_gaps_ok = w_gaps_ok;
      t.max_len   = max_len;
      t.strb_mode = strb_mode;
      start_item(t);
      if (!t.randomize() with { is_write dist {1 := local::wr_pct, 0 := (100 - local::wr_pct)}; })
        `uvm_fatal("RAND", "randomize failed (axi_rand_seq)")
      finish_item(t);
      if (idle_between) wait_axi_idle();
    end
    wait_axi_idle();
  endtask

endclass

// -----------------------------------------------------------------------------
// smoke: write, read back
// -----------------------------------------------------------------------------
class axi_smoke_seq extends axi_base_seq;

  `uvm_object_utils(axi_smoke_seq)

  function new(string name = "axi_smoke_seq");
    super.new(name);
  endfunction

  task body();
    send_single_write(32'h1000_0100, 64'hA5A5_1234_DEAD_BEEF);
    wait_axi_idle();
    send_single_read(32'h1000_0100);
    wait_axi_idle();
  endtask

endclass

// -----------------------------------------------------------------------------
// AW before W, W before AW, same cycle
// -----------------------------------------------------------------------------
class axi_order_seq extends axi_base_seq;

  `uvm_object_utils(axi_order_seq)

  function new(string name = "axi_order_seq");
    super.new(name);
  endfunction

  task body();
    // address first, data 10 cycles later
    send_single_write(32'h1000_0200, 64'h1111_1111_2222_2222, 0, 10);
    wait_axi_idle();
    // data first, address 10 cycles later
    send_single_write(32'h1000_0208, 64'h3333_3333_4444_4444, 10, 0);
    wait_axi_idle();
    // same cycle
    send_single_write(32'h1000_0210, 64'h5555_5555_6666_6666, 0, 0);
    wait_axi_idle();
    // read them all back
    send_single_read(32'h1000_0200);
    send_single_read(32'h1000_0208);
    send_single_read(32'h1000_0210);
    wait_axi_idle();
  endtask

endclass

// -----------------------------------------------------------------------------
// read and write presented in the same cycle (bridge has to pick one)
// -----------------------------------------------------------------------------
class axi_rw_collision_seq extends axi_base_seq;

  `uvm_object_utils(axi_rw_collision_seq)

  int unsigned num_pairs = 20;

  function new(string name = "axi_rw_collision_seq");
    super.new(name);
  endfunction

  task body();
    for (int unsigned i = 0; i < num_pairs; i++) begin
      bit [31:0] wa = 32'h1000_0300 + 16 * i;
      bit [31:0] ra = 32'h1000_0800 + 16 * i;
      send_single_write(wa, {$urandom(), $urandom()}, 0, 0);
      send_single_read(ra, 0);
      wait_axi_idle();
    end
  endtask

endclass

// -----------------------------------------------------------------------------
// write N consecutive words, wait, read them all back
// -----------------------------------------------------------------------------
class axi_readback_seq extends axi_base_seq;

  `uvm_object_utils(axi_readback_seq)

  int unsigned num_words = 32;

  function new(string name = "axi_readback_seq");
    super.new(name);
  endfunction

  task body();
    for (int unsigned i = 0; i < num_words; i++)
      send_single_write(32'h1000_0400 + 8 * i, {$urandom(), $urandom()});
    wait_axi_idle();
    for (int unsigned i = 0; i < num_words; i++)
      send_single_read(32'h1000_0400 + 8 * i);
    wait_axi_idle();
  endtask

endclass
