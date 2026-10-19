// APB bus interface (matches the signal names used by axi2apb_wrap)

interface APB_BUS #(
    parameter int APB_ADDR_WIDTH = 32,
    parameter int APB_DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n
);

    logic [APB_ADDR_WIDTH-1:0]    paddr;
    logic [APB_DATA_WIDTH-1:0]    pwdata;
    logic                         pwrite;
    logic                         psel;
    logic                         penable;
    logic [APB_DATA_WIDTH-1:0]    prdata;
    logic                         pready;
    logic                         pslverr;

    // Master: drives the request, receives the response
    modport Master (
        output paddr, pwdata, pwrite, psel, penable,
        input  prdata, pready, pslverr
    );

    // Slave: receives the request, drives the response
    modport Slave (
	input clk,rst_n,
        input  paddr, pwdata, pwrite, psel, penable,
        output prdata, pready, pslverr
    );

    // Passive monitor
    modport Monitor (
	input clk,rst_n,
        input paddr, pwdata, pwrite, psel, penable, prdata, pready, pslverr
    );

endinterface
