
//--------------------------------------------------------------------------------------------------------
// Module  : pixel_generate
// Type    : synthesizable
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: generate green->purple scroll bars to test hdmi_tx_top.v
//--------------------------------------------------------------------------------------------------------

module pixel_generate # (
    // the parameter of request to response latency ---------------------------------------
    parameter         RESP_LATENCY = 1         // 1, 2, or 3
) (
    // user's clock -----------------------------------------------------------------------
    input  wire       clk,
    // user's pixel request interface (these signals synchronize with clk) ----------------
    input  wire       req_en,
    input  wire       req_sof,
    input  wire       req_sol,
    // user's pixel response interface (these signals synchronize with clk) ---------------
    output wire [7:0] resp_red,
    output wire [7:0] resp_green,
    output wire [7:0] resp_blue
);


reg  [7:0] nrow;
reg  [7:0] nframe = 8'h0;

reg  [7:0] resp1_red, resp1_green, resp1_blue;
reg  [7:0] resp2_red, resp2_green, resp2_blue;
reg  [7:0] resp3_red, resp3_green, resp3_blue;


generate
    if      (RESP_LATENCY <= 1) assign {resp_red, resp_green, resp_blue} = {resp1_red, resp1_green, resp1_blue};
    else if (RESP_LATENCY == 2) assign {resp_red, resp_green, resp_blue} = {resp2_red, resp2_green, resp2_blue};
    else                        assign {resp_red, resp_green, resp_blue} = {resp3_red, resp3_green, resp3_blue};
endgenerate


always @ (posedge clk)
    if (req_en) begin
        if          (req_sof) begin
            nrow        <= nframe + 8'd1;
            nframe      <= nframe + 8'd1;
            resp1_red   <= nframe;
            resp1_green <= 8'hFF - nframe;
            resp1_blue  <= nframe;
        end else if (req_sol) begin
            nrow        <= nrow + 8'h1;
            resp1_red   <= nrow;
            resp1_green <= 8'hFF - nrow;
            resp1_blue  <= nrow;
        end else begin
            resp1_red   <= resp1_red   + 8'h1;
            resp1_green <= resp1_green - 8'h1;
            resp1_blue  <= resp1_blue  + 8'h1;
        end
    end


always @ (posedge clk) begin
    {resp2_red, resp2_green, resp2_blue} <= {resp1_red, resp1_green, resp1_blue};
    {resp3_red, resp3_green, resp3_blue} <= {resp2_red, resp2_green, resp2_blue};
end


endmodule

