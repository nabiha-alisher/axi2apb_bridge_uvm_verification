//-------------------------------------------------------------------------
//						mem_write_read_test - www.verificationguide.com 
//-------------------------------------------------------------------------
class axi_wr_rd_test extends axi_model_base_test;

  `uvm_component_utils(axi_wr_rd_test)
  
  //---------------------------------------
  // sequence instance 
  //--------------------------------------- 
  direct_read_seq seq;

  //---------------------------------------
  // constructor
  //---------------------------------------
  function new(string name = "mem_wr_rd_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction : new

  //---------------------------------------
  // build_phase
  //---------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create the sequence
    seq = direct_read_seq::type_id::create("seq");
  endfunction : build_phase
  
  //---------------------------------------
  // run_phase - starting the test
  //---------------------------------------
  task run_phase(uvm_phase phase);
    
    phase.raise_objection(this);
      seq.start(env.mem_agnt.sequencer);
    phase.drop_objection(this);
    
    //set a drain-time for the environment if desired
    phase.phase_done.set_drain_time(this, 50);
  endtask : run_phase
  
endclass : axi_wr_rd_test
