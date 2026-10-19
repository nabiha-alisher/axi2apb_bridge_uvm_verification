//-------------------------------------------------------------------------
// apb_slave_driver  (reactive APB slave / completer)
//
// The supplied bridge does NOT use a classic APB setup phase:
//     PSEL    = 1 permanently
//     PENABLE = write_req | read_req   (rises TOGETHER with PADDR/PWDATA)
// so a transfer is "a run of cycles with PENABLE=1", and it completes at
// the first clock edge where PENABLE && PREADY.  This driver therefore
// triggers on PENABLE, never on PSEL.
//
// Timing (all drives happen 1 time unit after the clock edge, so the
// bridge sees them as stable in the same cycle):
//
//   cycle 1 : PENABLE rises  -> driver samples PADDR/PWRITE/PWDATA
//             wait_cycles = 0 -> PREADY=1 driven in THIS cycle (0 wait states)
//             wait_cycles = k -> PREADY stays 0 for k cycles, then goes 1
//   edge    : PENABLE && PREADY -> transfer completes
//
// If no sequence supplies a response item, a default one is randomized
// from apb_slave_cfg, so the bridge can never hang because nobody started
// an APB sequence.
//
// Built-in memory model: writes are stored, reads return stored data (or
// cfg.default_rdata).  Use poke()/peek() for backdoor access.
//-------------------------------------------------------------------------
class apb_slave_driver extends uvm_driver #(apb_seq_item);

  `uvm_component_utils(apb_slave_driver)

  virtual APB_BUS.Slave vif;
  apb_slave_cfg         cfg;

  // slave memory model
  bit [31:0] mem [bit [31:0]];

  protected bit item_pending;   // an item from the sequencer is open (needs item_done)

  function new(string name = "apb_slave_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual APB_BUS.Slave)::get(this, "", "apb_slv_vif", vif))
      `uvm_fatal("APB_DRV", "Virtual interface 'apb_slv_vif' not found in config_db")
    if (!uvm_config_db#(apb_slave_cfg)::get(this, "", "apb_cfg", cfg))
      cfg = apb_slave_cfg::type_id::create("cfg");
  endfunction

  // ---- backdoor access -------------------------------------------------
  function void poke(bit [31:0] addr, bit [31:0] data);
    mem[addr] = data;
  endfunction

  function bit [31:0] peek(bit [31:0] addr);
    return mem.exists(addr) ? mem[addr] : cfg.default_rdata;
  endfunction

  // ---- run phase: serve until reset, idle during reset, repeat ----------
  virtual task run_phase(uvm_phase phase);
    idle_bus();
    forever begin
      wait (vif.rst_n === 1'b1);
      fork
        begin
          fork
            serve_requests();
            @(negedge vif.rst_n);          // asynchronous reset assertion
          join_any
          disable fork;
        end
      join
      // reset hit in the middle of a transfer: clean up
      if (item_pending) begin
        seq_item_port.item_done();
        item_pending = 0;
      end
      idle_bus();
      `uvm_info("APB_DRV", "Reset asserted - slave returned to idle", UVM_MEDIUM)
    end
  endtask

  task idle_bus();
    vif.pready  = 1'b0;
    vif.pslverr = 1'b0;
    vif.prdata  = '0;
  endtask

  // ---- one transfer per loop iteration -----------------------------------
  protected task serve_requests();
    apb_seq_item item;
    bit          from_seq;
    bit [31:0]   addr, wdata, rdata;
    bit          wr;

    forever begin
      @(posedge vif.clk);
      #1;                                   // let the bridge outputs settle

      if (vif.psel === 1'b1 && vif.penable === 1'b1) begin   // first access cycle
        addr  = vif.paddr;
        wr    = vif.pwrite;
        wdata = vif.pwdata;

        get_response(item, from_seq);

        // wait states: PREADY stays low for wait_cycles more cycles
        repeat (item.wait_cycles) begin
          @(posedge vif.clk);
          #1;
        end

        // answer in this cycle
        if (wr) rdata = '0;
        else    rdata = item.override_prdata ? item.prdata : peek(addr);
        vif.prdata  = rdata;
        vif.pslverr = item.pslverr;
        vif.pready  = 1'b1;

        @(posedge vif.clk);                 // completion edge (PENABLE && PREADY)

        if (wr && (!item.pslverr || cfg.store_on_error))
          mem[addr] = wdata;

        #1;
        idle_bus();

        // report what the bridge did back to the (reactive) sequence
        item.paddr  = addr;
        item.pwrite = wr;
        item.pwdata = wdata;
        if (!wr) item.prdata = rdata;

        `uvm_info("APB_DRV", {"Served: ", item.convert2string()}, UVM_HIGH)

        if (from_seq) begin
          seq_item_port.item_done();
          item_pending = 0;
        end
      end
    end
  endtask

  // Take the next response item if a sequence has one waiting, otherwise
  // build a default one from the cfg knobs.
  protected task get_response(output apb_seq_item item, output bit from_seq);
    seq_item_port.try_next_item(item);
    if (item == null) begin
      from_seq = 0;
      item = apb_seq_item::type_id::create("default_rsp");
      if (!item.randomize() with {
            wait_cycles inside {[cfg.min_wait : cfg.max_wait]};
            pslverr dist {1'b1 := cfg.err_pct, 1'b0 := (100 - cfg.err_pct)};
            override_prdata == 1'b0;
          })
        `uvm_error("APB_DRV", "Randomization of default response failed")
    end
    else begin
      from_seq     = 1;
      item_pending = 1;
    end
  endtask

endclass : apb_slave_driver
