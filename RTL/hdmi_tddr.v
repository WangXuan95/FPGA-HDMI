
//--------------------------------------------------------------------------------------------------------
// Module  : hdmi_tddr
// Type    : synthesizable, IP's sub module
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: ODDR for hdmi_tx_top.v
//--------------------------------------------------------------------------------------------------------

module hdmi_tddr (
    input  wire       clk,
    input  wire [1:0] din,
    output wire       dout
);

reg d0, d1, d1r;

always @ (posedge clk) {d1, d0} <= din;

always @ (negedge clk) d1r <= d1;

assign dout = clk ? d1r : d0;

endmodule

