
//--------------------------------------------------------------------------------------------------------
// Module  : fpga_top
// Type    : synthesizable, fpga top
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: example for hdmi_tx_top.v
//--------------------------------------------------------------------------------------------------------

module fpga_top (
    input  wire resetn,     // reset button
    input  wire clk,        // 27MHz
    output wire hdmi_clk_p,
    output wire hdmi_clk_n,
    output wire hdmi_tx0_p,
    output wire hdmi_tx0_n,
    output wire hdmi_tx1_p,
    output wire hdmi_tx1_n,
    output wire hdmi_tx2_p,
    output wire hdmi_tx2_n
);


localparam RESP_LATENCY = 1;

wire       rstn;
wire       pclk_x5;   // 125MHz

wire       req_en, req_sof, req_sol;         // request for pixel
wire [7:0] resp_red, resp_green, resp_blue;  // response pixel


/////////////////////////////////////////////////////////////////////////////////////////////
// use PLL to generate pclk_x5 (125MHz)
/////////////////////////////////////////////////////////////////////////////////////////////

Gowin_PLLVR u_pll (
    .clkout             ( pclk_x5             ),
    .lock               ( rstn                ),
    .reset              ( ~resetn             ),
    .clkin              ( clk                 )
);


/////////////////////////////////////////////////////////////////////////////////////////////
// generate green->purple scroll bars to test hdmi_tx_top
/////////////////////////////////////////////////////////////////////////////////////////////

pixel_generate # (
    .RESP_LATENCY       ( RESP_LATENCY        )
) u_pixel_generate (
    .clk                ( clk                 ),
    .req_en             ( req_en              ),
    .req_sof            ( req_sof             ),
    .req_sol            ( req_sol             ),
    .resp_red           ( resp_red            ),
    .resp_green         ( resp_green          ),
    .resp_blue          ( resp_blue           )
);


/////////////////////////////////////////////////////////////////////////////////////////////
// HDMI TX (display) controller.
/////////////////////////////////////////////////////////////////////////////////////////////

hdmi_tx_top #(
    .RESP_LATENCY       ( RESP_LATENCY        )
) u_hdmi_tx_top (
    .rstn               ( rstn                ),
    .clk                ( clk                 ),
    .req_en             ( req_en              ),
    .req_sof            ( req_sof             ),
    .req_eof            (                     ),
    .req_sol            ( req_sol             ),
    .req_eol            (                     ),
    .resp_red           ( resp_red            ),
    .resp_green         ( resp_green          ),
    .resp_blue          ( resp_blue           ),
    .pclk_x5            ( pclk_x5             ),
    .hdmi_clk_p         ( hdmi_clk_p          ),
    .hdmi_clk_n         ( hdmi_clk_n          ),
    .hdmi_tx0_p         ( hdmi_tx0_p          ),
    .hdmi_tx0_n         ( hdmi_tx0_n          ),
    .hdmi_tx1_p         ( hdmi_tx1_p          ),
    .hdmi_tx1_n         ( hdmi_tx1_n          ),
    .hdmi_tx2_p         ( hdmi_tx2_p          ),
    .hdmi_tx2_n         ( hdmi_tx2_n          )
);


endmodule

