// =============================================================================
// Tests
//
//  Tests marked [EXPECTED TO EXPOSE DUT ISSUES] exercise behaviour that the
//  bridge is meant to support but that looks questionable from reading the RTL.
// =============================================================================

// -----------------------------------------------------------------------------
// base test
// -----------------------------------------------------------------------------
class axi2apb_base_test extends uvm_test;

  `uvm_component_utils(axi2apb_base_test)

  axi2apb_env     env;
  axi2apb_env_cfg cfg;

  function new(string name = "axi2apb_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg = axi2apb_env_cfg::type_id::create("cfg");
    if (!uvm_config_db#(axi_vif_t)::get(this, "", "axi_vif", cfg.axi_cfg.vif))
      `uvm_fatal("NOVIF", "axi_vif not set")
    if (!uvm_config_db#(apb_vif_t)::get(this, "", "apb_vif", cfg.apb_cfg.vif))
      `uvm_fatal("NOVIF", "apb_vif not set")
    configure(cfg);
    uvm_config_db#(axi2apb_env_cfg)::set(this, "env", "cfg", cfg);
    // the APB slave answers every DUT access with a never-ending response sequence
    uvm_config_db#(uvm_object_wrapper)::set(this, "env.apb_ag.sqr.run_phase",
                                            "default_sequence", apb_slave_response_type());
    env = axi2apb_env::type_id::create("env", this);
  endfunction

  // hook for derived tests
  virtual function void configure(axi2apb_env_cfg c);
  endfunction

  // hook: which APB slave response sequence runs (default: profile from apb_agent_cfg)
  virtual function uvm_object_wrapper apb_slave_response_type();
    return apb_slave_seq::get_type();
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.set_timeout(5ms, 0);        // hang protection
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this, "test running");
    phase.phase_done.set_drain_time(this, 300ns);
    // wait for reset release
    @(posedge cfg.axi_cfg.vif.rst_n);
    repeat (5) @(posedge cfg.axi_cfg.vif.clk);
    test_body(phase);
    phase.drop_objection(this, "test done");
  endtask

  virtual task test_body(uvm_phase phase);
  endtask

  task run_rand(int unsigned n, bit burst = 0, bit narrow = 0, bit gaps = 0,
                strb_mode_e sm = STRB_FULL, int unsigned wr_pct = 50, bit idle = 0);
    axi_rand_seq s = axi_rand_seq::type_id::create("rand_seq");
    s.num_items    = n;
    s.burst_ok     = burst;
    s.narrow_ok    = narrow;
    s.w_gaps_ok    = gaps;
    s.strb_mode    = sm;
    s.wr_pct       = wr_pct;
    s.idle_between = idle;
    s.start(env.axi_ag.sqr);
  endtask

endclass

// -----------------------------------------------------------------------------
// 1. smoke
// -----------------------------------------------------------------------------
class axi2apb_smoke_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_smoke_test)
  function new(string name = "axi2apb_smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task test_body(uvm_phase phase);
    axi_smoke_seq s = axi_smoke_seq::type_id::create("s");
    s.start(env.axi_ag.sqr);
  endtask
endclass

// -----------------------------------------------------------------------------
// 2. random single transfers, zero-wait APB slave, one at a time
// -----------------------------------------------------------------------------
class axi2apb_single_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_single_test)
  function new(string name = "axi2apb_single_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task test_body(uvm_phase phase);
    run_rand(100, .idle(1));
  endtask
endclass

// -----------------------------------------------------------------------------
// 3. pipelined random singles (several outstanding), zero-wait APB
// -----------------------------------------------------------------------------
class axi2apb_pipelined_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_pipelined_test)
  function new(string name = "axi2apb_pipelined_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task test_body(uvm_phase phase);
    run_rand(300);
  endtask
endclass

// -----------------------------------------------------------------------------
// 4. APB wait states
// -----------------------------------------------------------------------------
class axi2apb_apb_wait_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_apb_wait_test)
  function new(string name = "axi2apb_apb_wait_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void configure(axi2apb_env_cfg c);
    c.apb_cfg.min_wait = 0;
    c.apb_cfg.max_wait = 6;
  endfunction
  task test_body(uvm_phase phase);
    run_rand(200);
  endtask
endclass

// -----------------------------------------------------------------------------
// 5. B / R back-pressure
// -----------------------------------------------------------------------------
class axi2apb_backpressure_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_backpressure_test)
  function new(string name = "axi2apb_backpressure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void configure(axi2apb_env_cfg c);
    c.axi_cfg.b_ready_pct = 15;
    c.axi_cfg.r_ready_pct = 15;
    c.apb_cfg.max_wait    = 2;
  endfunction
  task test_body(uvm_phase phase);
    run_rand(200);
  endtask
endclass

// -----------------------------------------------------------------------------
// 6. AW/W ordering
// -----------------------------------------------------------------------------
class axi2apb_order_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_order_test)
  function new(string name = "axi2apb_order_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task test_body(uvm_phase phase);
    axi_order_seq s = axi_order_seq::type_id::create("s");
    s.start(env.axi_ag.sqr);
  endtask
endclass

// -----------------------------------------------------------------------------
// 7. simultaneous read + write
// -----------------------------------------------------------------------------
class axi2apb_rw_collision_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_rw_collision_test)
  function new(string name = "axi2apb_rw_collision_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void configure(axi2apb_env_cfg c);
    c.apb_cfg.max_wait = 3;
  endfunction
  task test_body(uvm_phase phase);
    axi_rw_collision_seq s = axi_rw_collision_seq::type_id::create("s");
    s.start(env.axi_ag.sqr);
  endtask
endclass

// -----------------------------------------------------------------------------
// 8. write many locations, read them all back
// -----------------------------------------------------------------------------
class axi2apb_readback_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_readback_test)
  function new(string name = "axi2apb_readback_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void configure(axi2apb_env_cfg c);
    c.apb_cfg.max_wait = 2;
  endfunction
  task test_body(uvm_phase phase);
    axi_readback_seq s = axi_readback_seq::type_id::create("s");
    s.start(env.axi_ag.sqr);
  endtask
endclass

// -----------------------------------------------------------------------------
// 9. narrow transfers (size < bus width)
// -----------------------------------------------------------------------------
class axi2apb_narrow_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_narrow_test)
  function new(string name = "axi2apb_narrow_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void configure(axi2apb_env_cfg c);
    c.apb_cfg.max_wait = 2;
  endfunction
  task test_body(uvm_phase phase);
    run_rand(200, .narrow(1), .idle(1));
  endtask
endclass

// -----------------------------------------------------------------------------
// 10. word-granular strobes (64-bit bus)
//     [EXPECTED TO EXPOSE DUT ISSUES] single writes always write both words
// -----------------------------------------------------------------------------
class axi2apb_strobe_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_strobe_test)
  function new(string name = "axi2apb_strobe_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task test_body(uvm_phase phase);
    run_rand(100, .sm(STRB_WORD), .wr_pct(80), .idle(1));
  endtask
endclass

// -----------------------------------------------------------------------------
// 11. INCR bursts, zero-wait APB, continuous W stream (64-bit bus only)
// -----------------------------------------------------------------------------
class axi2apb_burst_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_burst_test)
  function new(string name = "axi2apb_burst_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task test_body(uvm_phase phase);
    if (AXI_DW != 64) begin
      `uvm_info("TEST", "bursts are only supported by the 64->32 bridge: test skipped", UVM_NONE)
      return;
    end
    run_rand(60, .burst(1), .idle(1));
  endtask
endclass

// -----------------------------------------------------------------------------
// 12. INCR bursts with APB wait states
//     [EXPECTED TO EXPOSE DUT ISSUES] see README
// -----------------------------------------------------------------------------
class axi2apb_burst_wait_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_burst_wait_test)
  function new(string name = "axi2apb_burst_wait_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void configure(axi2apb_env_cfg c);
    c.apb_cfg.min_wait = 1;
    c.apb_cfg.max_wait = 4;
  endfunction
  task test_body(uvm_phase phase);
    if (AXI_DW != 64) begin
      `uvm_info("TEST", "bursts are only supported by the 64->32 bridge: test skipped", UVM_NONE)
      return;
    end
    run_rand(60, .burst(1), .idle(1));
  endtask
endclass

// -----------------------------------------------------------------------------
// 13. INCR bursts with idle gaps between W beats
//     [EXPECTED TO EXPOSE DUT ISSUES] see README
// -----------------------------------------------------------------------------
class axi2apb_burst_wgap_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_burst_wgap_test)
  function new(string name = "axi2apb_burst_wgap_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task test_body(uvm_phase phase);
    if (AXI_DW != 64) begin
      `uvm_info("TEST", "bursts are only supported by the 64->32 bridge: test skipped", UVM_NONE)
      return;
    end
    run_rand(60, .burst(1), .gaps(1), .wr_pct(100), .idle(1));
  endtask
endclass

// -----------------------------------------------------------------------------
// 14. PSLVERR injection
//     [EXPECTED TO EXPOSE DUT ISSUES] bridge never maps PSLVERR to SLVERR
// -----------------------------------------------------------------------------
class axi2apb_slverr_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_slverr_test)
  function new(string name = "axi2apb_slverr_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void configure(axi2apb_env_cfg c);
    c.check_slverr_map = 1;
  endfunction
  virtual function uvm_object_wrapper apb_slave_response_type();
    return apb_error_slave_seq::get_type();
  endfunction
  task test_body(uvm_phase phase);
    run_rand(60, .idle(1));
  endtask
endclass

// -----------------------------------------------------------------------------
// 15. reset in the middle of traffic, then more traffic
// -----------------------------------------------------------------------------
class axi2apb_reset_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_reset_test)
  function new(string name = "axi2apb_reset_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void configure(axi2apb_env_cfg c);
    c.apb_cfg.max_wait = 3;
  endfunction
  task test_body(uvm_phase phase);
    uvm_event rst_req = uvm_event_pool::get_global_pool().get("tb_apply_reset");
    axi_vif_t vif     = cfg.axi_cfg.vif;
    repeat (3) begin
      fork
        run_rand(40);                       // traffic is queued ...
        begin
          repeat ($urandom_range(40, 8)) @(posedge vif.clk);
          rst_req.trigger();                // ... and reset hits somewhere in the middle
        end
      join
      @(negedge vif.rst_n);
      @(posedge vif.rst_n);
      repeat (5) @(posedge vif.clk);
    end
    run_rand(40, .idle(1));                 // clean traffic after the last reset
  endtask
endclass

// -----------------------------------------------------------------------------
// 16. everything mixed: waits, back-pressure, narrow, bursts (64-bit only)
//     [EXPECTED TO EXPOSE DUT ISSUES on the 64-bit bridge]
// -----------------------------------------------------------------------------
class axi2apb_random_test extends axi2apb_base_test;
  `uvm_component_utils(axi2apb_random_test)
  function new(string name = "axi2apb_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void configure(axi2apb_env_cfg c);
    c.apb_cfg.min_wait    = 0;
    c.apb_cfg.max_wait    = 4;
    c.axi_cfg.b_ready_pct = 60;
    c.axi_cfg.r_ready_pct = 60;
  endfunction
  task test_body(uvm_phase phase);
    run_rand(500, .burst(AXI_DW == 64), .narrow(1), .gaps(AXI_DW == 64), .sm(STRB_FULL));
  endtask
endclass
