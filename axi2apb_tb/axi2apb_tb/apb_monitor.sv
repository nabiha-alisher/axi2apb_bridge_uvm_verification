//-------------------------------------------------------------------------
// apb_monitor : passive APB monitor + protocol checker
//
// A transfer = consecutive cycles with PSEL && PENABLE; it completes at
// the first edge where PREADY=1.  This works for BOTH a standard APB
// master (setup cycle first) and the supplied bridge (PSEL always 1,
// PENABLE rises together with PADDR, no setup cycle).
//
// Publishes one apb_seq_item per completed transfer on
// item_collected_port (feed this to the scoreboard / coverage).
//
// Checks (cfg.checks_en):
//   - PENABLE=1 while PSEL=0
//   - PENABLE/PSEL dropped before PREADY (transfer abandoned)
//   - PADDR / PWRITE / PWDATA changed while waiting for PREADY
//   - PREADY stuck low > cfg.pready_timeout cycles
//   - PREADY / PSLVERR unknown (X/Z) when sampled
//   - (cfg.strict_apb only) access phase without a preceding setup phase
//
// report_phase prints how many transfers had no setup phase - this is a
// DUT OBSERVATION to document in the verification report, not a TB error.
//-------------------------------------------------------------------------
class apb_monitor extends uvm_monitor;

  `uvm_component_utils(apb_monitor)

  virtual APB_BUS.Monitor vif;
  apb_slave_cfg           cfg;

  uvm_analysis_port #(apb_seq_item) item_collected_port;

  protected int unsigned n_transfers;
  protected int unsigned n_no_setup;

  function new(string name = "apb_monitor", uvm_component parent = null);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual APB_BUS.Monitor)::get(this, "", "apb_mon_vif", vif))
      `uvm_fatal("APB_MON", "Virtual interface 'apb_mon_vif' not found in config_db")
    if (!uvm_config_db#(apb_slave_cfg)::get(this, "", "apb_cfg", cfg))
      cfg = apb_slave_cfg::type_id::create("cfg");
  endfunction

  virtual task run_phase(uvm_phase phase);
    typedef enum {IDLE, ACCESS} state_e;
    state_e      st = IDLE;
    apb_seq_item item;
    bit [31:0]   a, d;
    bit          w;
    bit          access;
    bit          prev_setup = 0;   // previous cycle was PSEL=1, PENABLE=0
    int unsigned waits = 0;
    bit          timeout_reported = 0;

    forever begin
      @(posedge vif.clk);          // samples the values of the cycle that just ended

      // ---- reset: abandon whatever was in flight ----
      if (vif.rst_n !== 1'b1) begin
        if (st == ACCESS)
          `uvm_info("APB_MON", "Reset during an APB transfer - transfer aborted", UVM_LOW)
        st = IDLE;
        prev_setup = 0;
        continue;
      end

      access = (vif.psel === 1'b1) && (vif.penable === 1'b1);

      if (cfg.checks_en && vif.penable === 1'b1 && vif.psel !== 1'b1)
        `uvm_error("APB_PROTO", "PENABLE=1 while PSEL=0")

      // ---- transfer start ----
      if (st == IDLE && access) begin
        a = vif.paddr;  w = vif.pwrite;  d = vif.pwdata;
        waits = 0;  timeout_reported = 0;
        n_transfers++;
        if (!prev_setup) begin
          n_no_setup++;
          if (cfg.checks_en && cfg.strict_apb)
            `uvm_error("APB_PROTO", "Access phase without a preceding setup phase (PSEL=1, PENABLE=0)")
        end
        st = ACCESS;
      end
      // ---- transfer abandoned ----
      else if (st == ACCESS && !access) begin
        if (cfg.checks_en)
          `uvm_error("APB_PROTO", "PENABLE/PSEL dropped before PREADY was seen")
        st = IDLE;
      end
      // ---- stability while waiting ----
      else if (st == ACCESS) begin
        if (cfg.checks_en &&
            (vif.paddr !== a || vif.pwrite !== w || (w && vif.pwdata !== d)))
          `uvm_error("APB_PROTO", "PADDR/PWRITE/PWDATA changed during access phase")
      end

      // ---- this cycle is an access cycle: completed or waiting? ----
      if (st == ACCESS) begin
        if (vif.pready === 1'b1) begin
          if (cfg.checks_en && ^vif.pslverr === 1'bx)
            `uvm_error("APB_PROTO", "PSLVERR is X/Z when PREADY=1")

          item = apb_seq_item::type_id::create("apb_item");
          item.paddr          = a;
          item.pwrite         = w;
          item.pwdata         = d;
          item.prdata         = vif.prdata;
          item.pslverr        = vif.pslverr;
          item.observed_waits = waits;
          `uvm_info("APB_MON", item.convert2string(), UVM_MEDIUM)
          item_collected_port.write(item);
          st = IDLE;
        end
        else begin
          if (cfg.checks_en && vif.pready !== 1'b0)
            `uvm_error("APB_PROTO", "PREADY is X/Z during access phase")
          waits++;
          if (cfg.checks_en && !timeout_reported && waits >= cfg.pready_timeout) begin
            `uvm_error("APB_PROTO",
              $sformatf("PREADY stuck low for %0d cycles (addr=0x%08h) - APB slave not responding?",
                        waits, a))
            timeout_reported = 1;
          end
        end
      end

      prev_setup = (vif.psel === 1'b1) && (vif.penable === 1'b0);
    end
  endtask

  virtual function void report_phase(uvm_phase phase);
    if (n_transfers > 0)
      `uvm_info("APB_MON",
        $sformatf("OBSERVATION: %0d of %0d APB transfers started with PENABLE=1 in the first cycle (no PSEL=1/PENABLE=0 setup phase). AMBA APB requires a setup phase - document this in the verification report.",
                  n_no_setup, n_transfers), UVM_LOW)
  endfunction

endclass : apb_monitor
