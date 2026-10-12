// AXI4 bus interface (matches the signal names used by axi2apb_wrap / axi_slice_wrap)

interface AXI_BUS #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 32,
    parameter int AXI_ID_WIDTH   = 6,
    parameter int AXI_USER_WIDTH = 6
)(
    input logic clk,
    input logic rst_n
);

    localparam int AXI_STRB_WIDTH = AXI_DATA_WIDTH/8;

    // ---------------- Write address channel ----------------
    logic [AXI_ID_WIDTH-1:0]    aw_id;
    logic [AXI_ADDR_WIDTH-1:0]  aw_addr;
    logic [7:0]                 aw_len;
    logic [2:0]                 aw_size;
    logic [1:0]                 aw_burst;
    logic                       aw_lock;
    logic [3:0]                 aw_cache;
    logic [2:0]                 aw_prot;
    logic [3:0]                 aw_qos;
    logic [3:0]                 aw_region;
    logic [AXI_USER_WIDTH-1:0]  aw_user;
    logic                       aw_valid;
    logic                       aw_ready;

    // ---------------- Write data channel -------------------
    logic [AXI_DATA_WIDTH-1:0]  w_data;
    logic [AXI_STRB_WIDTH-1:0]  w_strb;
    logic                       w_last;
    logic [AXI_USER_WIDTH-1:0]  w_user;
    logic                       w_valid;
    logic                       w_ready;

    // ---------------- Write response channel ---------------
    logic [AXI_ID_WIDTH-1:0]    b_id;
    logic [1:0]                 b_resp;
    logic [AXI_USER_WIDTH-1:0]  b_user;
    logic                       b_valid;
    logic                       b_ready;

    // ---------------- Read address channel -----------------
    logic [AXI_ID_WIDTH-1:0]    ar_id;
    logic [AXI_ADDR_WIDTH-1:0]  ar_addr;
    logic [7:0]                 ar_len;
    logic [2:0]                 ar_size;
    logic [1:0]                 ar_burst;
    logic                       ar_lock;
    logic [3:0]                 ar_cache;
    logic [2:0]                 ar_prot;
    logic [3:0]                 ar_qos;
    logic [3:0]                 ar_region;
    logic [AXI_USER_WIDTH-1:0]  ar_user;
    logic                       ar_valid;
    logic                       ar_ready;

    // ---------------- Read data channel --------------------
    logic [AXI_ID_WIDTH-1:0]    r_id;
    logic [AXI_DATA_WIDTH-1:0]  r_data;
    logic [1:0]                 r_resp;
    logic                       r_last;
    logic [AXI_USER_WIDTH-1:0]  r_user;
    logic                       r_valid;
    logic                       r_ready;

    // Slave: the module receives requests and drives responses
    modport Slave (
        input  aw_id, aw_addr, aw_len, aw_size, aw_burst, aw_lock, aw_cache,
               aw_prot, aw_qos, aw_region, aw_user, aw_valid,
        output aw_ready,

        input  w_data, w_strb, w_last, w_user, w_valid,
        output w_ready,

        output b_id, b_resp, b_user, b_valid,
        input  b_ready,

        input  ar_id, ar_addr, ar_len, ar_size, ar_burst, ar_lock, ar_cache,
               ar_prot, ar_qos, ar_region, ar_user, ar_valid,
        output ar_ready,

        output r_id, r_data, r_resp, r_last, r_user, r_valid,
        input  r_ready
    );

    // Master: the module drives requests and receives responses
    modport Master (
        output aw_id, aw_addr, aw_len, aw_size, aw_burst, aw_lock, aw_cache,
               aw_prot, aw_qos, aw_region, aw_user, aw_valid,
        input  aw_ready,

        output w_data, w_strb, w_last, w_user, w_valid,
        input  w_ready,

        input  b_id, b_resp, b_user, b_valid,
        output b_ready,

        output ar_id, ar_addr, ar_len, ar_size, ar_burst, ar_lock, ar_cache,
               ar_prot, ar_qos, ar_region, ar_user, ar_valid,
        input  ar_ready,

        input  r_id, r_data, r_resp, r_last, r_user, r_valid,
        output r_ready
    );

    // Passive monitor: everything is an input (for testbenches / checkers)
    modport Monitor (
        input aw_id, aw_addr, aw_len, aw_size, aw_burst, aw_lock, aw_cache,
              aw_prot, aw_qos, aw_region, aw_user, aw_valid, aw_ready,
              w_data, w_strb, w_last, w_user, w_valid, w_ready,
              b_id, b_resp, b_user, b_valid, b_ready,
              ar_id, ar_addr, ar_len, ar_size, ar_burst, ar_lock, ar_cache,
              ar_prot, ar_qos, ar_region, ar_user, ar_valid, ar_ready,
              r_id, r_data, r_resp, r_last, r_user, r_valid, r_ready
    );

endinterface
