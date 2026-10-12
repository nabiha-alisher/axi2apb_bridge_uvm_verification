// =============================================================================
// SVA protocol checkers (bound to the interfaces in tb_top)
// =============================================================================

// ----------------------------------------------------------------------------- AXI
module axi_protocol_checker (
  input logic        clk,
  input logic        rst_n,
  AXI_BUS.Monitor    axi
);

  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  // VALID must stay asserted, with stable payload, until READY (all five channels)
  a_aw_hold : assert property (axi.aw_valid && !axi.aw_ready |=> axi.aw_valid &&
              $stable({axi.aw_id, axi.aw_addr, axi.aw_len, axi.aw_size, axi.aw_burst}))
              else $error("AW: valid dropped or payload changed before ready");

  a_w_hold  : assert property (axi.w_valid && !axi.w_ready |=> axi.w_valid &&
              $stable({axi.w_data, axi.w_strb, axi.w_last}))
              else $error("W: valid dropped or payload changed before ready");

  a_ar_hold : assert property (axi.ar_valid && !axi.ar_ready |=> axi.ar_valid &&
              $stable({axi.ar_id, axi.ar_addr, axi.ar_len, axi.ar_size, axi.ar_burst}))
              else $error("AR: valid dropped or payload changed before ready");

  a_b_hold  : assert property (axi.b_valid && !axi.b_ready |=> axi.b_valid &&
              $stable({axi.b_id, axi.b_resp}))
              else $error("B: valid dropped or payload changed before ready");

  a_r_hold  : assert property (axi.r_valid && !axi.r_ready |=> axi.r_valid &&
              $stable({axi.r_id, axi.r_data, axi.r_resp, axi.r_last}))
              else $error("R: valid dropped or payload changed before ready");

  // no X on handshake signals out of reset
  a_no_x    : assert property (!$isunknown({axi.aw_ready, axi.w_ready, axi.ar_ready,
                                            axi.b_valid, axi.r_valid}))
              else $error("X/Z on DUT-driven AXI handshake signals");

  // responses must not appear without a request in flight (very coarse: counts)
  int unsigned wr_req_cnt, wr_rsp_cnt, rd_req_cnt, rd_rsp_cnt;
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) begin wr_req_cnt <= 0; wr_rsp_cnt <= 0; rd_req_cnt <= 0; rd_rsp_cnt <= 0; end
    else begin
      if (axi.aw_valid && axi.aw_ready) wr_req_cnt <= wr_req_cnt + 1;
      if (axi.b_valid  && axi.b_ready)  wr_rsp_cnt <= wr_rsp_cnt + 1;
      if (axi.ar_valid && axi.ar_ready) rd_req_cnt <= rd_req_cnt + 1;
      if (axi.r_valid  && axi.r_ready && axi.r_last) rd_rsp_cnt <= rd_rsp_cnt + 1;
    end
  a_b_has_req : assert property (axi.b_valid |-> wr_rsp_cnt < wr_req_cnt)
                else $error("B response without a matching AW");
  a_r_has_req : assert property (axi.r_valid |-> rd_rsp_cnt < rd_req_cnt)
                else $error("R response without a matching AR");

endmodule

// ----------------------------------------------------------------------------- APB
module apb_protocol_checker #(
  // The bridge asserts PSEL permanently and PENABLE together with the first cycle of
  // the access (no separate setup phase). Set to 1 to flag that as a violation.
  parameter bit STRICT_SETUP = 1'b0
)(
  input logic        clk,
  input logic        rst_n,
  APB_BUS.Monitor    apb
);

  default clocking cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  a_penable_needs_psel : assert property (apb.penable |-> apb.psel)
                         else $error("APB: PENABLE without PSEL");

  a_hold_in_wait : assert property (apb.psel && apb.penable && !apb.pready |=>
                         apb.penable && $stable({apb.paddr, apb.pwrite, apb.pwdata}))
                   else $error("APB: control/address/data changed or PENABLE dropped while waiting for PREADY");

  a_no_x : assert property (!$isunknown({apb.psel, apb.penable}) &&
                            (!apb.penable || !$isunknown({apb.paddr, apb.pwrite})))
           else $error("APB: X/Z on PSEL/PENABLE/PADDR/PWRITE");

  generate if (STRICT_SETUP) begin : g_strict
    a_setup_phase : assert property ($rose(apb.penable) |-> $past(apb.psel && !apb.penable))
                    else $error("APB: PENABLE rose without a preceding setup phase (PSEL=1, PENABLE=0)");
  end endgenerate

endmodule
