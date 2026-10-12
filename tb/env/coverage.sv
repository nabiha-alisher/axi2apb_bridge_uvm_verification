// =============================================================================
// axi2apb_coverage : functional coverage on both interfaces
// =============================================================================
class axi2apb_coverage extends uvm_component;

  `uvm_component_utils(axi2apb_coverage)

  uvm_analysis_imp_axi_done #(axi_item, axi2apb_coverage) axi_imp;
  uvm_analysis_imp_apb      #(apb_item, axi2apb_coverage) apb_imp;

  // sampled values
  bit          c_is_write;
  bit [7:0]    c_len;
  bit [2:0]    c_size;
  bit [2:0]    c_off;
  int unsigned c_strbkind;     // 0 full, 1 low half only, 2 high half only, 3 other, 4 read
  bit          c_resp_err;
  int unsigned c_waits;
  bit          c_apb_write;
  bit          c_apb_err;

  covergroup cg_axi;
    option.per_instance = 1;
    cp_dir  : coverpoint c_is_write { bins rd = {0}; bins wr = {1}; }
    cp_len  : coverpoint c_len      { bins single = {0}; bins short_b = {[1:3]};
                                      bins mid = {[4:7]}; bins long_b = {[8:255]}; }
    cp_size : coverpoint c_size     { bins b1 = {0}; bins b2 = {1}; bins b4 = {2}; bins b8 = {3}; }
    cp_off  : coverpoint c_off      { bins a0 = {0}; bins a4 = {4}; bins other = default; }
    cp_strb : coverpoint c_strbkind { bins full = {0}; bins low_only = {1}; bins high_only = {2};
                                      bins other = {3}; bins is_read = {4}; }
    cp_resp : coverpoint c_resp_err { bins okay = {0}; bins err = {1}; }
    cx_dir_len      : cross cp_dir, cp_len;
    cx_dir_size_off : cross cp_dir, cp_size, cp_off;
    cx_dir_strb     : cross cp_dir, cp_strb { ignore_bins rd_strb = binsof(cp_dir.rd) && !binsof(cp_strb.is_read);
                                              ignore_bins wr_rdk  = binsof(cp_dir.wr) && binsof(cp_strb.is_read); }
  endgroup

  covergroup cg_apb;
    option.per_instance = 1;
    cp_rw   : coverpoint c_apb_write { bins rd = {0}; bins wr = {1}; }
    cp_wait : coverpoint c_waits     { bins w0 = {0}; bins w1 = {1}; bins w2_3 = {[2:3]}; bins w4_up = {[4:$]}; }
    cp_err  : coverpoint c_apb_err   { bins okay = {0}; bins err = {1}; }
    cx_rw_wait : cross cp_rw, cp_wait;
    cx_rw_err  : cross cp_rw, cp_err;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    axi_imp = new("axi_imp", this);
    apb_imp = new("apb_imp", this);
    cg_axi  = new();
    cg_apb  = new();
  endfunction

  function void write_axi_done(axi_item t);
    c_is_write = t.is_write;
    c_len      = t.len;
    c_size     = t.size;
    c_off      = t.addr[2:0];
    c_resp_err = t.is_write ? (t.bresp != 0) : ((t.rresp.size() > 0) ? (t.rresp[0] != 0) : 0);
    if (!t.is_write || t.strb.size() == 0)
      c_strbkind = 4;
    else if (t.strb[0] == ((1 << AXI_SW) - 1))
      c_strbkind = 0;
    else if (AXI_SW == 8 && t.strb[0] == 8'h0F)
      c_strbkind = 1;
    else if (AXI_SW == 8 && t.strb[0] == 8'hF0)
      c_strbkind = 2;
    else
      c_strbkind = 3;
    cg_axi.sample();
  endfunction

  function void write_apb(apb_item a);
    c_apb_write = a.write;
    c_apb_err   = a.slverr;
    c_waits     = a.waits;
    cg_apb.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("AXI coverage = %0.1f%%  APB coverage = %0.1f%%",
                               cg_axi.get_inst_coverage(), cg_apb.get_inst_coverage()), UVM_NONE)
  endfunction

endclass
