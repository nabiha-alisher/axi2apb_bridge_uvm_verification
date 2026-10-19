//-------------------------------------------------------------------------
// axi2apb_coverage : functional coverage for the AXI -> APB bridge
//
// Inputs
//   axi_imp : completed AXI transactions   (mem_agnt.ap, from the AXI driver)
//   apb_imp : completed APB transfers      (apb_agnt.ap, from the APB monitor)
//
// Covergroups
//   cg_axi_wr   AXI write : id, user, addr, align, size, len, burst, strb,
//                           data, AW/W order + delays, B delay, BRESP
//   cg_axi_rd   AXI read  : id, user, addr, align, size, len, burst,
//                           R delay, RRESP, RLAST
//   cg_seq      back-to-back ordering   (WR->WR, WR->RD, RD->WR, RD->RD ...)
//   cg_xlate    how many APB transfers each AXI request produced
//               (documents "bursts are NOT converted")
//   cg_priority simultaneous read+write : which one reached APB first
//   cg_apb      APB side : direction, PREADY wait states, PSLVERR, address
//
// Notes
//   - "bins other = default" bins are NOT counted in the coverage score,
//     they only make unexpected values visible in the report.
//   - Items are sampled when they COMPLETE, so one AXI item produces one
//     sample (two in the read+write case).
//-------------------------------------------------------------------------
`uvm_analysis_imp_decl(_axi)
`uvm_analysis_imp_decl(_apb)

class axi2apb_coverage extends uvm_component;

  `uvm_component_utils(axi2apb_coverage)

  typedef enum {K_NONE, K_WR, K_RD, K_BOTH}  kind_e;
  typedef enum {O_SAME, O_AW_FIRST, O_W_FIRST} order_e;
  typedef enum {F_NA, F_READ, F_WRITE}        first_e;

  uvm_analysis_imp_axi #(axi_seq_item, axi2apb_coverage) axi_imp;
  uvm_analysis_imp_apb #(apb_seq_item, axi2apb_coverage) apb_imp;

  bit enable = 1;

  //---------------------------------------------------------------------
  // sample variables
  //---------------------------------------------------------------------
  // AXI write
  bit [5:0]    w_id, w_user;
  bit [31:0]   w_addr, w_data;
  bit [1:0]    w_off, w_burst, w_resp;
  bit [2:0]    w_size;
  bit [3:0]    w_len, w_strb;
  int unsigned w_awd, w_wd, w_bd;
  order_e      w_order;

  // AXI read
  bit [5:0]    r_id, r_user;
  bit [31:0]   r_addr;
  bit [1:0]    r_off, r_burst, r_resp;
  bit [2:0]    r_size;
  bit [3:0]    r_len;
  bit          r_last;
  int unsigned r_rd;

  // sequencing / translation / priority
  kind_e       cur_kind, prev_kind = K_NONE;
  kind_e       x_kind;
  bit          x_burst;          // request had len > 0
  int unsigned x_cnt;            // APB transfers seen for this AXI request
  first_e      x_first = F_NA;
  bit          x_same;

  // APB
  bit          a_write, a_err;
  int unsigned a_waits;
  bit [31:0]   a_addr;

  // APB transfers since the last completed AXI item
  protected int unsigned apb_since_last = 0;
  protected bit          first_apb_write;

  // statistics
  protected int unsigned n_axi_wr, n_axi_rd, n_apb_wr, n_apb_rd;

  //---------------------------------------------------------------------
  // AXI write
  //---------------------------------------------------------------------
  covergroup cg_axi_wr;
    option.per_instance = 1;

    cp_id   : coverpoint w_id   { bins zero = {0};  bins low  = {[1:15]};  bins mid = {[16:47]};
                                  bins high = {[48:62]};  bins max = {63}; }
    cp_user : coverpoint w_user { bins zero = {0};  bins low  = {[1:15]};  bins mid = {[16:47]};
                                  bins high = {[48:62]};  bins max = {63}; }

    cp_addr : coverpoint w_addr { bins zero = {0};
                                  bins low  = {[1:'h7F]};
                                  bins mid  = {['h80:'hFFFF]};
                                  bins high = {['h1_0000:'hFFFF_FFFE]};
                                  bins max  = {32'hFFFF_FFFF}; }
    cp_off  : coverpoint w_off  { bins off[] = {[0:3]}; }

    cp_size  : coverpoint w_size  { bins b1 = {0};  bins h2 = {1};  bins w4 = {2};
                                    bins other = default; }
    cp_len   : coverpoint w_len   { bins l0 = {0};  bins l1 = {1};  bins l3 = {3};
                                    bins l7 = {7};  bins l15 = {15};  bins other = default; }
    cp_burst : coverpoint w_burst { bins fixed = {0};  bins incr = {1};  bins wrap = {2};
                                    bins other = default; }

    cp_strb : coverpoint w_strb { bins all    = {4'hF};
                                  bins none   = {4'h0};
                                  bins single[] = {4'h1, 4'h2, 4'h4, 4'h8};
                                  bins pair[]   = {4'h3, 4'hC};
                                  bins other  = default; }

    cp_data : coverpoint w_data { bins zero = {0};  bins ones = {32'hFFFF_FFFF};
                                  bins p55  = {32'h5555_5555};  bins pAA = {32'hAAAA_AAAA};
                                  bins lsb  = {32'h1};  bins msb = {32'h8000_0000};
                                  bins other = default; }

    cp_awd : coverpoint w_awd { bins zero = {0};  bins s1_2 = {[1:2]};  bins s3_5 = {[3:5]};  bins l6up = {[6:$]}; }
    cp_wd  : coverpoint w_wd  { bins zero = {0};  bins s1_2 = {[1:2]};  bins s3_5 = {[3:5]};  bins l6up = {[6:$]}; }
    cp_bd  : coverpoint w_bd  { bins zero = {0};  bins s1_2 = {[1:2]};  bins s3_5 = {[3:5]};  bins l6up = {[6:$]}; }

    cp_order : coverpoint w_order { bins same = {O_SAME};  bins aw_first = {O_AW_FIRST};
                                    bins w_first = {O_W_FIRST}; }

    cp_resp : coverpoint w_resp { bins okay = {0};  bins not_okay = default; }

    x_order_bd : cross cp_order, cp_bd;
    x_size_off : cross cp_size, cp_off;
    x_burst_len: cross cp_burst, cp_len {
      // burst type is meaningless for a single beat
      ignore_bins len0_nonfixed = binsof(cp_len.l0) &&
                                  (binsof(cp_burst.incr) || binsof(cp_burst.wrap));
    }
  endgroup

  //---------------------------------------------------------------------
  // AXI read
  //---------------------------------------------------------------------
  covergroup cg_axi_rd;
    option.per_instance = 1;

    cp_id   : coverpoint r_id   { bins zero = {0};  bins low  = {[1:15]};  bins mid = {[16:47]};
                                  bins high = {[48:62]};  bins max = {63}; }
    cp_user : coverpoint r_user { bins zero = {0};  bins low  = {[1:15]};  bins mid = {[16:47]};
                                  bins high = {[48:62]};  bins max = {63}; }

    cp_addr : coverpoint r_addr { bins zero = {0};
                                  bins low  = {[1:'h7F]};
                                  bins mid  = {['h80:'hFFFF]};
                                  bins high = {['h1_0000:'hFFFF_FFFE]};
                                  bins max  = {32'hFFFF_FFFF}; }
    cp_off  : coverpoint r_off  { bins off[] = {[0:3]}; }

    cp_size  : coverpoint r_size  { bins b1 = {0};  bins h2 = {1};  bins w4 = {2};
                                    bins other = default; }
    cp_len   : coverpoint r_len   { bins l0 = {0};  bins l1 = {1};  bins l3 = {3};
                                    bins l7 = {7};  bins l15 = {15};  bins other = default; }
    cp_burst : coverpoint r_burst { bins fixed = {0};  bins incr = {1};  bins wrap = {2};
                                    bins other = default; }

    cp_rd   : coverpoint r_rd   { bins zero = {0};  bins s1_2 = {[1:2]};  bins s3_5 = {[3:5]};  bins l6up = {[6:$]}; }
    cp_resp : coverpoint r_resp { bins okay = {0};  bins not_okay = default; }
    cp_last : coverpoint r_last { bins last = {1};  bins not_last = default; }

    x_size_off : cross cp_size, cp_off;
    x_burst_len: cross cp_burst, cp_len {
      ignore_bins len0_nonfixed = binsof(cp_len.l0) &&
                                  (binsof(cp_burst.incr) || binsof(cp_burst.wrap));
    }
  endgroup

  //---------------------------------------------------------------------
  // back-to-back ordering
  //---------------------------------------------------------------------
  covergroup cg_seq;
    option.per_instance = 1;

    cp_prev : coverpoint prev_kind { bins wr = {K_WR};  bins rd = {K_RD};  bins both = {K_BOTH}; }
    cp_cur  : coverpoint cur_kind  { bins wr = {K_WR};  bins rd = {K_RD};  bins both = {K_BOTH}; }

    x_b2b : cross cp_prev, cp_cur {
      // a simultaneous request right after a read / another simultaneous
      // request adds nothing new
      ignore_bins both_after_rd_both = binsof(cp_cur.both) &&
                                       (binsof(cp_prev.rd) || binsof(cp_prev.both));
    }
  endgroup

  //---------------------------------------------------------------------
  // AXI request -> number of APB transfers (burst / conversion behaviour)
  //---------------------------------------------------------------------
  covergroup cg_xlate;
    option.per_instance = 1;

    cp_cnt   : coverpoint x_cnt    { bins one = {1};  bins two = {2};  bins other = default; }
    cp_kind  : coverpoint x_kind   { bins wr = {K_WR};  bins rd = {K_RD};  bins both = {K_BOTH}; }
    cp_burst : coverpoint x_burst  { bins single = {0};  bins burst = {1}; }

    x_xlate : cross cp_kind, cp_burst, cp_cnt {
      ignore_bins single_req_two_apb = (binsof(cp_kind.wr) || binsof(cp_kind.rd)) && binsof(cp_cnt.two);
      ignore_bins both_one_apb       = binsof(cp_kind.both) && binsof(cp_cnt.one);
      ignore_bins both_burst         = binsof(cp_kind.both) && binsof(cp_burst.burst);
    }
  endgroup

  //---------------------------------------------------------------------
  // simultaneous read + write : who reaches APB first?
  //---------------------------------------------------------------------
  covergroup cg_priority;
    option.per_instance = 1;

    cp_first : coverpoint x_first { bins read_first = {F_READ};
                                    bins other      = default; }   // write-first would land here
    cp_same  : coverpoint x_same  { bins same_addr = {1};  bins diff_addr = {0}; }

    x_prio : cross cp_first, cp_same;
  endgroup

  //---------------------------------------------------------------------
  // APB side
  //---------------------------------------------------------------------
  covergroup cg_apb;
    option.per_instance = 1;

    cp_dir   : coverpoint a_write { bins rd = {0};  bins wr = {1}; }
    cp_waits : coverpoint a_waits { bins zero = {0};  bins one = {1};  bins w2_3 = {[2:3]};
                                    bins w4_7 = {[4:7]};  bins w8up = {[8:$]}; }
    cp_err   : coverpoint a_err   { bins no = {0};  bins yes = {1}; }
    cp_addr  : coverpoint a_addr  { bins zero = {0};
                                    bins low  = {[1:'h7F]};
                                    bins mid  = {['h80:'hFFFF]};
                                    bins high = {['h1_0000:'hFFFF_FFFF]}; }

    x_dir_waits : cross cp_dir, cp_waits;
    x_dir_err   : cross cp_dir, cp_err;
  endgroup

  //---------------------------------------------------------------------
  // construction
  //---------------------------------------------------------------------
  function new(string name = "axi2apb_coverage", uvm_component parent = null);
    super.new(name, parent);
    axi_imp = new("axi_imp", this);
    apb_imp = new("apb_imp", this);
    cg_axi_wr   = new();
    cg_axi_rd   = new();
    cg_seq      = new();
    cg_xlate    = new();
    cg_priority = new();
    cg_apb      = new();
  endfunction

  //---------------------------------------------------------------------
  // APB transfer completed
  //---------------------------------------------------------------------
  function void write_apb(apb_seq_item t);
    if (!enable) return;

    a_write = t.pwrite;
    a_err   = t.pslverr;
    a_waits = t.observed_waits;
    a_addr  = t.paddr;
    cg_apb.sample();

    if (t.pwrite) n_apb_wr++; else n_apb_rd++;

    apb_since_last++;
    if (apb_since_last == 1) first_apb_write = t.pwrite;
  endfunction

  //---------------------------------------------------------------------
  // AXI transaction completed
  //---------------------------------------------------------------------
  function void write_axi(axi_seq_item t);
    kind_e k;
    if (!enable) return;

    k = (t.awvalid && t.arvalid) ? K_BOTH : (t.awvalid ? K_WR : K_RD);
    cur_kind = k;

    if (t.awvalid) begin
      w_id    = t.awid;     w_user  = t.awuser;
      w_addr  = t.awaddr;   w_off   = t.awaddr[1:0];
      w_size  = t.awsize;   w_len   = t.awlen;    w_burst = t.awburst;
      w_strb  = t.wstrb;    w_data  = t.wdata;
      w_awd   = t.aw_delay; w_wd    = t.w_delay;  w_bd    = t.b_delay;
      w_resp  = t.bresp;
      w_order = (t.aw_delay == t.w_delay) ? O_SAME :
                (t.aw_delay <  t.w_delay) ? O_AW_FIRST : O_W_FIRST;
      cg_axi_wr.sample();
      n_axi_wr++;
    end

    if (t.arvalid) begin
      r_id    = t.arid;     r_user  = t.aruser;
      r_addr  = t.araddr;   r_off   = t.araddr[1:0];
      r_size  = t.arsize;   r_len   = t.arlen;    r_burst = t.arburst;
      r_rd    = t.r_delay;  r_resp  = t.rresp;    r_last  = t.rlast;
      cg_axi_rd.sample();
      n_axi_rd++;
    end

    // how many APB transfers did this request cause?
    x_cnt   = apb_since_last;
    x_kind  = k;
    x_burst = (t.awvalid && t.awlen != 0) || (t.arvalid && t.arlen != 0);
    cg_xlate.sample();

    // read/write priority: only meaningful when both were presented together
    if (k == K_BOTH) begin
      x_first = (apb_since_last > 0 && first_apb_write) ? F_WRITE : F_READ;
      x_same  = (t.awaddr == t.araddr);
      cg_priority.sample();
    end

    cg_seq.sample();          // uses prev_kind / cur_kind
    prev_kind      = k;
    apb_since_last = 0;
  endfunction

  //---------------------------------------------------------------------
  // report
  //---------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
    real sum;
    sum = cg_axi_wr.get_inst_coverage() + cg_axi_rd.get_inst_coverage() +
          cg_seq.get_inst_coverage()    + cg_xlate.get_inst_coverage() +
          cg_priority.get_inst_coverage() + cg_apb.get_inst_coverage();

    `uvm_info("COV", "================ FUNCTIONAL COVERAGE ================", UVM_LOW)
    `uvm_info("COV", $sformatf("cg_axi_wr   : %6.2f %%", cg_axi_wr.get_inst_coverage()),   UVM_LOW)
    `uvm_info("COV", $sformatf("cg_axi_rd   : %6.2f %%", cg_axi_rd.get_inst_coverage()),   UVM_LOW)
    `uvm_info("COV", $sformatf("cg_seq      : %6.2f %%", cg_seq.get_inst_coverage()),      UVM_LOW)
    `uvm_info("COV", $sformatf("cg_xlate    : %6.2f %%", cg_xlate.get_inst_coverage()),    UVM_LOW)
    `uvm_info("COV", $sformatf("cg_priority : %6.2f %%", cg_priority.get_inst_coverage()), UVM_LOW)
    `uvm_info("COV", $sformatf("cg_apb      : %6.2f %%", cg_apb.get_inst_coverage()),      UVM_LOW)
    `uvm_info("COV", $sformatf("AVERAGE     : %6.2f %%", sum / 6.0),                       UVM_LOW)
    `uvm_info("COV", $sformatf("AXI wr=%0d rd=%0d | APB wr=%0d rd=%0d",
                               n_axi_wr, n_axi_rd, n_apb_wr, n_apb_rd), UVM_LOW)

    if (n_axi_wr != n_apb_wr || n_axi_rd != n_apb_rd)
      `uvm_info("COV",
        "OBSERVATION: AXI request count differs from APB transfer count (expected 1:1 for this bridge)",
        UVM_LOW)
  endfunction

endclass : axi2apb_coverage
