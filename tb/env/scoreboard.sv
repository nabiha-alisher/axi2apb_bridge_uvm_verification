// =============================================================================
// axi2apb_scoreboard
//
// Reference model of the bridge (specification-level behaviour):
//
//  * one AXI transaction -> an ordered list of 32-bit APB accesses
//      - 32-bit AXI : one APB access per beat
//      - 64-bit AXI, full-width beat (size = 3): two accesses per beat (low word first,
//        then high word); a 32-bit word whose strobe nibble is zero is not written
//      - 64-bit AXI, narrow beat: one access at the beat address, using the 32-bit half
//        selected by addr[2]
//  * write: APB PWDATA must equal the AXI data on every byte whose strobe is set
//  * read : RDATA of every beat must be built from the APB PRDATA that was returned
//  * B/R: ID must be echoed, RLAST only on the last beat, response OKAY (SLVERR if the
//         slave signalled PSLVERR and cfg.check_slverr_map is set)
//
// APB accesses are attributed to AXI transactions dynamically (the DUT may serve a
// read before an older write): when no transaction is "active", the access must match
// the first expected access of the oldest pending transaction that can match it.
// =============================================================================
typedef struct {
  bit                write;
  bit [APB_AW-1:0]   addr;
  bit [31:0]         wdata;
  bit [31:0]         wmask;
  int unsigned       k;       // beat index
  int unsigned       w;       // word index inside the beat
} exp_acc_t;

typedef enum {EXP_OK, EXP_NONE, EXP_NODATA} exp_status_e;

// per-transaction tracking state
class txn_ctx;
  axi_item     t;
  int unsigned k = 0;
  int unsigned w = 0;
  bit          slverr = 0;
  bit [31:0]   rd_words[$];
  int unsigned n_apb = 0;
  function new(axi_item t);
    this.t = t;
  endfunction
endclass

class axi2apb_scoreboard extends uvm_component;

  `uvm_component_utils(axi2apb_scoreboard)

  uvm_analysis_imp_axi_req  #(axi_item, axi2apb_scoreboard) axi_req_imp;
  uvm_analysis_imp_axi_done #(axi_item, axi2apb_scoreboard) axi_done_imp;
  uvm_analysis_imp_apb      #(apb_item, axi2apb_scoreboard) apb_imp;

  axi2apb_env_cfg cfg;

  txn_ctx pending[$];
  txn_ctx ctx_of[axi_item];
  txn_ctx active;

  int unsigned n_wr, n_rd, n_apb_wr, n_apb_rd, n_partial_strb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    axi_req_imp  = new("axi_req_imp",  this);
    axi_done_imp = new("axi_done_imp", this);
    apb_imp      = new("apb_imp",      this);
  endfunction

  // ------------------------------------------------------------- reset handling
  task run_phase(uvm_phase phase);
    uvm_event ev = uvm_event_pool::get_global_pool().get("rst_assert");
    forever begin
      ev.wait_trigger();
      flush();
    end
  endtask

  function void flush();
    if (pending.size() > 0)
      `uvm_info("SB", $sformatf("reset: dropping %0d in-flight transactions", pending.size()), UVM_LOW)
    pending.delete();
    ctx_of.delete();
    active = null;
  endfunction

  // ------------------------------------------------------------- model helpers
  function int unsigned words_per_beat(axi_item t);
    return (AXI_DW == 64 && t.size == 3) ? 2 : 1;
  endfunction

  function bit [31:0] beat_addr(axi_item t, int unsigned k);
    int unsigned bytes = 1 << t.size;
    bit [31:0]   base;
    if (k == 0) return t.addr;
    base = (t.addr / bytes) * bytes;
    return base + k * bytes;
  endfunction

  function bit [31:0] nib2mask(bit [3:0] n);
    bit [31:0] m = '0;
    for (int i = 0; i < 4; i++) m[8*i +: 8] = {8{n[i]}};
    return m;
  endfunction

  function void advance(ref int unsigned k, ref int unsigned w, input int unsigned wpb);
    w++;
    if (w >= wpb) begin w = 0; k++; end
  endfunction

  // next expected APB access of a transaction (without consuming it)
  function exp_status_e peek_next(txn_ctx c, output exp_acc_t e);
    int unsigned wpb    = words_per_beat(c.t);
    int unsigned nbeats = int'(c.t.len) + 1;
    int unsigned k      = c.k;
    int unsigned w      = c.w;
    int unsigned widx;
    bit [31:0]   ba;
    bit [3:0]    nib;
    e = '{default: '0};
    while (k < nbeats) begin
      ba   = beat_addr(c.t, k);
      widx = (AXI_DW == 64) ? ((wpb == 2) ? w : ba[2]) : 0;
      e.k  = k;
      e.w  = w;
      e.addr = (wpb == 2) ? ((ba & ~32'h7) + 4 * w) : ba;
      if (c.t.is_write) begin
        if (k >= c.t.data.size()) return EXP_NODATA;
        nib = c.t.strb[k][4*widx +: 4];
        if (nib == 4'h0) begin       // nothing to write in this word
          advance(k, w, wpb);
          continue;
        end
        e.write = 1;
        e.wdata = c.t.data[k][32*widx +: 32];
        e.wmask = nib2mask(nib);
        return EXP_OK;
      end else begin
        e.write = 0;
        return EXP_OK;
      end
    end
    return EXP_NONE;
  endfunction

  function void consume(txn_ctx c, exp_acc_t e);
    c.k = e.k;
    c.w = e.w;
    advance(c.k, c.w, words_per_beat(c.t));
  endfunction

  function string compare_acc(exp_acc_t e, apb_item a);
    if (e.write !== a.write) return $sformatf("direction (exp %s, got %s)", e.write ? "WR" : "RD", a.write ? "WR" : "RD");
    if (e.addr  !== a.addr)  return $sformatf("address (exp 0x%08h, got 0x%08h)", e.addr, a.addr);
    if (e.write && ((e.wdata & e.wmask) !== (a.wdata & e.wmask)))
      return $sformatf("write data (exp 0x%08h, got 0x%08h, mask 0x%08h)", e.wdata, a.wdata, e.wmask);
    return "";
  endfunction

  // ------------------------------------------------------------- AXI request seen
  function void write_axi_req(axi_item t);
    txn_ctx c = new(t);
    if (t.burst != AXI_BURST_INCR)
      `uvm_warning("SB_UNSUP", $sformatf("burst type %0d is not modelled (treated as INCR): %s", t.burst, t.convert2string()))
    pending.push_back(c);
    ctx_of[t] = c;
    if (t.is_write) n_wr++; else n_rd++;
  endfunction

  // ------------------------------------------------------------- APB access seen
  function void write_apb(apb_item a);
    txn_ctx      c = null;
    exp_acc_t    e, e2;
    exp_status_e st;
    string       why;

    if (a.write) n_apb_wr++; else n_apb_rd++;

    if (active != null) begin
      c = active;
    end else begin
      foreach (pending[i]) begin
        exp_acc_t ce;
        if (peek_next(pending[i], ce) == EXP_OK && compare_acc(ce, a) == "") begin
          c = pending[i];
          break;
        end
      end
      if (c == null) begin
        `uvm_error("SB_APB", $sformatf("APB access matches no pending AXI transaction (%0d pending): %s",
                                       pending.size(), a.convert2string()))
        return;
      end
      active = c;
    end

    st = peek_next(c, e);
    if (st != EXP_OK) begin
      `uvm_error("SB_APB", $sformatf("unexpected APB access for AXI txn {%s} (%s): %s",
                                     c.t.convert2string(), st.name(), a.convert2string()))
      if (st == EXP_NONE) active = null;
      return;
    end

    why = compare_acc(e, a);
    if (why != "")
      `uvm_error("SB_APB", $sformatf("APB mismatch on %s -- expected %s addr=0x%08h (beat %0d word %0d) -- got: %s -- AXI txn {%s}",
                                     why, e.write ? "WR" : "RD", e.addr, e.k, e.w, a.convert2string(), c.t.convert2string()))

    if (e.write && e.wmask != 32'hFFFF_FFFF) n_partial_strb++;

    consume(c, e);
    c.n_apb++;
    if (a.slverr) c.slverr = 1;
    if (!a.write) c.rd_words.push_back(a.rdata);

    if (peek_next(c, e2) == EXP_NONE) active = null;
  endfunction

  // ------------------------------------------------------------- AXI response complete
  function void write_axi_done(axi_item t);
    txn_ctx      c;
    exp_acc_t    e;
    exp_status_e st;
    bit [1:0]    exp_resp;

    if (!ctx_of.exists(t)) begin
      `uvm_error("SB_AXI", $sformatf("response for unknown transaction: %s", t.convert2string()))
      return;
    end
    c = ctx_of[t];

    st = peek_next(c, e);
    if (st != EXP_NONE)
      `uvm_error("SB_AXI", $sformatf("response (%s) returned before all APB accesses were done (next expected: %s addr=0x%08h beat %0d word %0d) -- txn {%s}",
                                     t.is_write ? "B" : "R", e.write ? "WR" : "RD", e.addr, e.k, e.w, t.convert2string()))

    exp_resp = (c.slverr && cfg.check_slverr_map) ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
    if (t.is_write) check_write(c, exp_resp); else check_read(c, exp_resp);

    // retire
    if (active == c) active = null;
    ctx_of.delete(t);
    foreach (pending[i]) if (pending[i] == c) begin pending.delete(i); break; end
  endfunction

  function void check_write(txn_ctx c, bit [1:0] exp_resp);
    axi_item t = c.t;
    if (t.bid !== t.id)
      `uvm_error("SB_B", $sformatf("BID 0x%0h != AWID 0x%0h", t.bid, t.id))
    if (!(c.slverr && !cfg.check_slverr_map) && t.bresp !== exp_resp)
      `uvm_error("SB_B", $sformatf("BRESP %0d != expected %0d (apb error seen = %0b) -- txn {%s}",
                                   t.bresp, exp_resp, c.slverr, t.convert2string()))
    if (t.data.size() != int'(t.len) + 1)
      `uvm_error("SB_B", $sformatf("write completed with %0d of %0d W beats", t.data.size(), int'(t.len) + 1))
  endfunction

  function void check_read(txn_ctx c, bit [1:0] exp_resp);
    axi_item     t     = c.t;
    int unsigned wpb   = words_per_beat(t);
    int unsigned nbeat = int'(t.len) + 1;
    bit [63:0]   exp_d, got_d;
    int unsigned widx;

    if (t.rdata.size() != nbeat) begin
      `uvm_error("SB_R", $sformatf("got %0d R beats, expected %0d -- txn {%s}", t.rdata.size(), nbeat, t.convert2string()))
      return;
    end
    for (int unsigned k = 0; k < nbeat; k++) begin
      if (t.rid[k] !== t.id)
        `uvm_error("SB_R", $sformatf("beat %0d: RID 0x%0h != ARID 0x%0h", k, t.rid[k], t.id))
      if (t.rlast[k] !== (k == nbeat - 1))
        `uvm_error("SB_R", $sformatf("beat %0d of %0d: RLAST=%0b", k, nbeat, t.rlast[k]))
      if (!(c.slverr && !cfg.check_slverr_map) && t.rresp[k] !== exp_resp)
        `uvm_error("SB_R", $sformatf("beat %0d: RRESP %0d != expected %0d (apb error seen = %0b)",
                                     k, t.rresp[k], exp_resp, c.slverr))
      // data
      if (wpb == 2) begin
        if (2*k + 1 >= c.rd_words.size()) begin
          `uvm_error("SB_R", $sformatf("beat %0d: missing APB read data", k))
          continue;
        end
        exp_d = {c.rd_words[2*k + 1], c.rd_words[2*k]};
        got_d = t.rdata[k];
      end else begin
        if (k >= c.rd_words.size()) begin
          `uvm_error("SB_R", $sformatf("beat %0d: missing APB read data", k))
          continue;
        end
        widx  = (AXI_DW == 64) ? beat_addr(t, k) >> 2 & 1 : 0;
        exp_d = c.rd_words[k];
        got_d = t.rdata[k][32*widx +: 32];
      end
      if (got_d !== exp_d)
        `uvm_error("SB_R", $sformatf("beat %0d: RDATA 0x%h != APB read data 0x%h -- txn {%s}",
                                     k, got_d, exp_d, t.convert2string()))
    end
  endfunction

  // ------------------------------------------------------------- end of test
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (pending.size() != 0)
      `uvm_error("SB_END", $sformatf("%0d AXI transaction(s) never completed (first: %s)",
                                     pending.size(), pending[0].t.convert2string()))
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB_SUMMARY", $sformatf("AXI: %0d writes, %0d reads | APB: %0d writes, %0d reads | partial-strobe words: %0d",
                                      n_wr, n_rd, n_apb_wr, n_apb_rd, n_partial_strb), UVM_NONE)
  endfunction

endclass
