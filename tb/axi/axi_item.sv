// =============================================================================
// axi_item : one AXI transaction (read or write)
//   - request fields + timing knobs are randomised by sequences
//   - response fields (bresp/rdata/...) are filled in by the monitor
// =============================================================================
typedef enum bit [1:0] {AXI_BURST_FIXED = 2'b00,
                        AXI_BURST_INCR  = 2'b01,
                        AXI_BURST_WRAP  = 2'b10} axi_burst_e;

typedef enum bit [1:0] {AXI_RESP_OKAY   = 2'b00,
                        AXI_RESP_EXOKAY = 2'b01,
                        AXI_RESP_SLVERR = 2'b10,
                        AXI_RESP_DECERR = 2'b11} axi_resp_e;

typedef enum {STRB_FULL, STRB_WORD, STRB_ANY} strb_mode_e;

class axi_item extends uvm_sequence_item;

  // ---------------------------------------------------------------- request
  rand bit                 is_write;
  rand bit [AXI_IDW-1:0]   id;
  rand bit [AXI_AW-1:0]    addr;
  rand bit [7:0]           len;      // beats - 1
  rand bit [2:0]           size;     // log2(bytes per beat)
  rand bit [1:0]           burst;
  rand bit                 lock;
  rand bit [3:0]           cache;
  rand bit [2:0]           prot;
  rand bit [3:0]           qos;
  rand bit [3:0]           region;
  rand bit [AXI_UW-1:0]    user;
  rand bit [63:0]          data[$];  // write data, one entry per beat (low AXI_DW bits used)
  rand bit [7:0]           strb[$];  // write strobes, one entry per beat
  rand bit [AXI_UW-1:0]    w_user;

  // ---------------------------------------------------------------- timing knobs
  rand int unsigned        addr_delay;      // cycles before AW/AR valid
  rand int unsigned        w_first_delay;   // cycles before first W beat
  rand int unsigned        w_gap[$];        // idle cycles before each W beat (index 0 unused)

  // ---------------------------------------------------------------- generation knobs (not random)
  bit            burst_ok  = 0;             // allow len > 0
  bit            narrow_ok = 0;             // allow size < full width
  bit            w_gaps_ok = 0;             // allow idle cycles between W beats
  int unsigned   max_len   = 7;
  strb_mode_e    strb_mode = STRB_FULL;

  // ---------------------------------------------------------------- observed response (monitor)
  bit [1:0]                bresp;
  bit [AXI_IDW-1:0]        bid;
  bit [63:0]               rdata[$];
  bit [1:0]                rresp[$];
  bit [AXI_IDW-1:0]        rid[$];
  bit                      rlast[$];

  `uvm_object_utils(axi_item)

  function new(string name = "axi_item");
    super.new(name);
  endfunction

  // ---------------------------------------------------------------- constraints
  constraint c_burst_type { burst == AXI_BURST_INCR; }   // FIXED/WRAP are not supported by the DUT

  // bursts always use full-width beats (narrow bursts are not supported by the DUT)
  constraint c_size {
    if (len > 0)        size == AXI_MAX_SIZE;
    else if (narrow_ok) size <= AXI_MAX_SIZE;
    else                size == AXI_MAX_SIZE;
  }

  constraint c_len {
    if (burst_ok) len <= max_len; else len == 0;
  }

  // addresses aligned to the beat size, inside a few 4 KB pages, never crossing 4 KB
  constraint c_align      { (addr & ((1 << size) - 1)) == 0; }
  constraint c_addr_range { addr[31:12] inside {[20'h10000 : 20'h10003]};
                            addr[11:0]  < 12'hF00; }

  constraint c_arrays {
    data.size()  == (is_write ? int'(len) + 1 : 0);
    strb.size()  == data.size();
    w_gap.size() == data.size();
  }

  constraint c_strb {
    foreach (strb[i]) {
      (strb[i] >> AXI_SW) == 0;                       // only legal lanes
      if (strb_mode == STRB_FULL)
        strb[i] == 8'(((16'h1 << (16'h1 << size)) - 16'h1) << (addr % AXI_SW));
      else if (strb_mode == STRB_WORD) {
        strb[i][3:0] inside {4'h0, 4'hF};
        strb[i][7:4] inside {4'h0, 4'hF};
        strb[i] != 0;
      } else
        strb[i] != 0;
    }
  }

  constraint c_delays {
    addr_delay    dist {0 := 6, [1:4] :/ 4};
    w_first_delay dist {0 := 6, [1:6] :/ 4};
    foreach (w_gap[i]) {
      if (w_gaps_ok) w_gap[i] inside {[0:3]};
      else           w_gap[i] == 0;
    }
  }

  // ---------------------------------------------------------------- helpers
  function int unsigned get_gap(int unsigned i);
    return (i < w_gap.size()) ? w_gap[i] : 0;
  endfunction

  function string convert2string();
    string s;
    s = $sformatf("%s id=%0h addr=0x%08h len=%0d size=%0d burst=%0d",
                  is_write ? "WR" : "RD", id, addr, len, size, burst);
    if (is_write) foreach (data[i]) s = {s, $sformatf(" [%0d]=%h/%h", i, data[i], strb[i])};
    return s;
  endfunction

endclass
