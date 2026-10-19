//-------------------------------------------------------------------------
// Virtual sequencer: holds handles to the AXI and APB sequencers so that
// one virtual sequence can coordinate both agents.
// Handles are assigned in axi_model_env::connect_phase.
//-------------------------------------------------------------------------
class tb_virtual_sequencer extends uvm_sequencer;

  `uvm_component_utils(tb_virtual_sequencer)

  axi_sequencer axi_sqr;
  apb_sequencer apb_sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass : tb_virtual_sequencer
