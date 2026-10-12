module axi_single_slice #(
    parameter int BUFFER_DEPTH = -1,
    parameter int DATA_WIDTH   = -1
) (
    input  logic                  clk_i,    // Clock
    input  logic                  rst_ni,  // Asynchronous reset active low
    input  logic                  testmode_i,
    input  logic                  valid_i,
    output logic                  ready_o,
    input  logic [DATA_WIDTH-1:0] data_i,

    input  logic                  ready_i,
    output logic                  valid_o,
    output logic [DATA_WIDTH-1:0] data_o
);

    logic full, empty;

    assign ready_o = ~full;
    assign valid_o = ~empty;

    fifo #(
        .FALL_THROUGH ( 1'b0         ),
        .DATA_WIDTH   ( DATA_WIDTH   ),
        .DEPTH        ( BUFFER_DEPTH )
    ) i_fifo (
        .clk_i      ( clk_i             ),
        .rst_ni     ( rst_ni            ),
        .flush_i    ( 1'b0              ),
        .threshold_o (), // NC
        .testmode_i ( testmode_i        ),
        .full_o     ( full              ),
        .empty_o    ( empty             ),
        .data_i     ( data_i            ),
        .push_i     ( valid_i & ready_o ),
        .data_o     ( data_o            ),
        .pop_i      ( ready_i & valid_o )
    );

endmodule
