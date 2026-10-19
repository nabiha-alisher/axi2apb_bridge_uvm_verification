// Long PREADY wait states
class axi_apb_wait_test extends axi_wr_rd_test;
  `uvm_component_utils(axi_apb_wait_test)
  function new(string name = "axi_apb_wait_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual function uvm_sequence_base get_vseq();
    vseq_apb_wait_states s = vseq_apb_wait_states::type_id::create("vseq");
    return s;
  endfunction
endclass

// PSLVERR injection
class axi_apb_slverr_test extends axi_wr_rd_test;
  `uvm_component_utils(axi_apb_slverr_test)
  function new(string name = "axi_apb_slverr_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual function uvm_sequence_base get_vseq();
    vseq_apb_slverr s = vseq_apb_slverr::type_id::create("vseq");
    return s;
  endfunction
endclass

// Directed PRDATA
class axi_apb_rdata_test extends axi_wr_rd_test;
  `uvm_component_utils(axi_apb_rdata_test)
  function new(string name = "axi_apb_rdata_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual function uvm_sequence_base get_vseq();
    vseq_apb_rdata s = vseq_apb_rdata::type_id::create("vseq");
    return s;
  endfunction
endclass

// No APB sequence at all: slave driver falls back to cfg defaults
// (random 0..5 wait states, 10 % PSLVERR) - proves the bridge never hangs
class axi_apb_default_rsp_test extends axi_wr_rd_test;
  `uvm_component_utils(axi_apb_default_rsp_test)
  function new(string name = "axi_apb_default_rsp_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual function void configure_apb(apb_slave_cfg c);
    c.min_wait = 0;
    c.max_wait = 5;
    c.err_pct  = 10;
  endfunction
endclass

// Runs every uvm_do_with AXI sequence under random PREADY wait states
class axi_plan_test extends axi_wr_rd_test;
  `uvm_component_utils(axi_plan_test)
  function new(string name = "axi_plan_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  virtual function uvm_sequence_base get_vseq();
    vseq_axi_plan s = vseq_axi_plan::type_id::create("vseq");
    return s;
  endfunction
endclass
