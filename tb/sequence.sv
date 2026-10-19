
class direct_write_seq extends uvm_sequence #(axi_seq_item);

  `uvm_object_utils(direct_write_seq)
 `uvm_declare_p_sequencer(axi_sequencer)
  axi_seq_item req;

  function new(string name = "direct_write_seq");
    super.new(name);
  endfunction

  task body();

    req = axi_seq_item::type_id::create("req");

    start_item(req);

    // AW Channel

    req.awvalid = 1'b1;
    req.awid    = 4'd1;
    req.awaddr  = 32'd20;
    req.awlen   = 4'd0;
    req.awsize  = 3'b010;
    req.awburst = 2'b00;
   
 // W Channel

    req.wvalid = 1'b1;

  //  req.wdata = new[1];
    //req.wstrb = new[1];

    req.wdata = 32'hAABBCCDD;
    req.wstrb = 4'b1111;

//B Channel
    req.bready = 1'b1;

    finish_item(req);

  endtask

endclass

class direct_read_seq extends uvm_sequence #(axi_seq_item);

  `uvm_object_utils(direct_read_seq)

  axi_seq_item req;

  function new(string name = "direct_read_seq");
    super.new(name);
  endfunction

  task body();

    req = axi_seq_item::type_id::create("req");

    start_item(req);
//AR Channel
    req.arvalid = 1'b1;
    req.arid    = 4'd1;
    req.araddr  = 32'd20;
    req.arlen   = 4'd0;
    req.arsize  = 3'b010;
    req.arburst = 2'b00;
// R Channel
    req.rready = 1'b1;

    finish_item(req);

  endtask

endclass

