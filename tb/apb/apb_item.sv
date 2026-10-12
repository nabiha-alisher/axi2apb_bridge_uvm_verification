// =============================================================================
// apb_item : one completed APB access, as observed by the monitor
// =============================================================================
class apb_item extends uvm_sequence_item;

  bit [APB_AW-1:0] addr;
  bit              write;
  bit [APB_DW-1:0] wdata;
  bit [APB_DW-1:0] rdata;
  bit              slverr;
  int unsigned     waits;     // wait states inserted by the slave (penable && !pready cycles)
  time             t_done;

  `uvm_object_utils(apb_item)

  function new(string name = "apb_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("APB %s addr=0x%08h %s=0x%08h err=%0b waits=%0d",
                     write ? "WR" : "RD", addr,
                     write ? "wdata" : "rdata", write ? wdata : rdata, slverr, waits);
  endfunction

endclass
