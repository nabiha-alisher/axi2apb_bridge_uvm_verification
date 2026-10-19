class mem_agent extends uvm_agent;

  //---------------------------------------
  // component instances
  //---------------------------------------
  axi_driver    driver;
  axi_sequencer sequencer;
  //mem_monitor   monitor;

  // completed AXI transactions (from the driver) -> coverage / scoreboard
  uvm_analysis_port #(axi_seq_item) ap;

  `uvm_component_utils(mem_agent)
  
  //---------------------------------------
  // constructor
  //---------------------------------------
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  //---------------------------------------
  // build_phase
  //---------------------------------------
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    //monitor = mem_monitor::type_id::create("monitor", this);

    //creating driver and sequencer only for ACTIVE agent
    if(get_is_active() == UVM_ACTIVE) begin
      driver    = axi_driver::type_id::create("driver", this);
      sequencer = axi_sequencer::type_id::create("sequencer", this);
    end
  endfunction : build_phase
  
  //---------------------------------------  
  // connect_phase - connecting the driver and sequencer port
  //---------------------------------------
  function void connect_phase(uvm_phase phase);
    if(get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
      ap = driver.item_done_ap;
    end
  endfunction : connect_phase

endclass : mem_agent
