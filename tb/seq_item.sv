
class axi_seq_item extends uvm_sequence_item;

  `uvm_object_utils(axi_seq_item)

  // Write Address Channel (AW)

  rand bit        awvalid;
  rand bit [3:0]  awid;
  rand bit [3:0]  awlen;
  rand bit [2:0]  awsize;
  rand bit [31:0] awaddr;
  rand bit [1:0]  awburst;

  // Write Data Channel (W)

  rand bit        wvalid;
  rand bit [3:0]  wid;
  rand bit [31:0] wdata;
  rand bit [3:0]  wstrb;


  // Write Response Channel (B)

  bit             bready;
  bit             bvalid;
  bit [3:0]       bid;
  bit [1:0]       bresp;


  // Read Address Channel (AR)

  rand bit        arvalid;
  rand bit [3:0]  arid;
  rand bit [31:0] araddr;
  rand bit [3:0]  arlen;
  rand bit [2:0]  arsize;
  rand bit [1:0]  arburst;

  // Read Data Channel (R)

  bit             rready;
  bit             rvalid;
  bit [3:0]       rid;
  bit [31:0]      rdata;
  bit [1:0]       rresp;
  bit             rlast;

  // Constructor

  function new(string name = "axi_seq_item");
    super.new(name);
  endfunction


  // AW Channel Constraints


  // FIXED burst only
  constraint c_awburst {
    awburst == 2'b00;
  }

  // Supported transfer sizes: 1, 2, 4 bytes
  constraint c_awsize {
    awsize inside {3'b000, 3'b001, 3'b010};
  }

  // Address range: 0 to 127
  constraint c_awaddr {
    awaddr inside {[0:127]};
  }

  // Supported burst lengths: 1, 2, 4, 8, 16 beats
  constraint c_awlen {
    awlen inside {4'd0, 4'd1, 4'd3, 4'd7, 4'd15};
  }

 
  // W Channel Constraints


  // Number of data beats = AWLEN + 1
 // constraint c_wdata_size {
   // wdata.size() == (awlen + 1);
    //wstrb.size() == (awlen + 1);
//  }


  // AR Channel Constraints


  // FIXED burst only
  constraint c_arburst {
    arburst == 2'b00;
  }

  // Supported transfer sizes: 1, 2, 4 bytes
  constraint c_arsize {
    arsize inside {3'b000, 3'b001, 3'b010};
  }

  // Address range: 0 to 127
  constraint c_araddr {
    araddr inside {[0:127]};
  }

  // Supported burst lengths: 1, 2, 4, 8, 16 beats
  constraint c_arlen {
    arlen inside {4'd0, 4'd1, 4'd3, 4'd7, 4'd15};
  }

endclass
