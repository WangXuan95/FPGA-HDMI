
//--------------------------------------------------------------------------------------------------------
// Module  : tb_hdmi_tx_top
// Type    : simulation, top
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: testbench for hdmi_tx_top.v
//--------------------------------------------------------------------------------------------------------

module tb_hdmi_tx_top ();


//initial $dumpvars(1, tb_hdmi_tx_top);

initial begin   repeat(10000000) @ (posedge clk);   $finish;   end



/////////////////////////////////////////////////////////////////////////////////////////////
// generate two clocks (clk and pclk_x5)
/////////////////////////////////////////////////////////////////////////////////////////////

localparam CLK_PEROID     = 37037;  // T=37037ps   f=27MHz
localparam PCLK_X5_PEROID = 8000;   // T=4000ps    f=125MHz

wire clk;
wire pclk_x5;

tb_clkgen #(0,     CLK_PEROID, 200) u1_clkgen (clk);       // jitter=200ps
tb_clkgen #(0, PCLK_X5_PEROID, 200) u2_clkgen (pclk_x5);   // jitter=200ps



/////////////////////////////////////////////////////////////////////////////////////////////
// generate reset_n
/////////////////////////////////////////////////////////////////////////////////////////////

reg  rstn = 1'b0;
initial begin   repeat (4) @(posedge clk);   rstn <= 1'b1;   end



/////////////////////////////////////////////////////////////////////////////////////////////
// signals
/////////////////////////////////////////////////////////////////////////////////////////////

wire       req_en, req_sof, req_sol;         // request for pixel
wire [7:0] resp_red, resp_green, resp_blue;  // response pixel
wire       hdmi_clk_p, hdmi_tx0_p, hdmi_tx1_p, hdmi_tx2_p;



/////////////////////////////////////////////////////////////////////////////////////////////
// generate green->purple scroll bars to test hdmi_tx_top
/////////////////////////////////////////////////////////////////////////////////////////////

localparam RESP_LATENCY   = 1;      // request to response latency

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
    // user's clock and reset -------------------------------------------------------------
    .rstn               ( rstn                ),
    .clk                ( clk                 ),
    // user's pixel request interface (these signals synchronize with clk) ----------------
    .req_en             ( req_en              ),
    .req_sof            ( req_sof             ),
    .req_eof            (                     ),
    .req_sol            ( req_sol             ),
    .req_eol            (                     ),
    // user's pixel response interface (these signals synchronize with clk) ---------------
    .resp_red           ( resp_red            ),
    .resp_green         ( resp_green          ),
    .resp_blue          ( resp_blue           ),
    // HDMI driving clock, whose frequency must be 5 * pclk (pclk is the pixel clock) -----
    .pclk_x5            ( pclk_x5             ),
    // HDMI TX out ------------------------------------------------------------------------
    .hdmi_clk_p         ( hdmi_clk_p          ),
    .hdmi_clk_n         (                     ),
    .hdmi_tx0_p         ( hdmi_tx0_p          ),
    .hdmi_tx0_n         (                     ),
    .hdmi_tx1_p         ( hdmi_tx1_p          ),
    .hdmi_tx1_n         (                     ),
    .hdmi_tx2_p         ( hdmi_tx2_p          ),
    .hdmi_tx2_n         (                     )
);



/////////////////////////////////////////////////////////////////////////////////////////////
// decode three TMDS channels (non-synthesizable!!!, only for simulation)
/////////////////////////////////////////////////////////////////////////////////////////////

wire       dec_vde, dec_vsync, dec_hsync;
wire [7:0] dec_red, dec_green, dec_blue;

tb_tmds_decode # (        // only for simulation
    .HDMI_CLK_PEROID    ( PCLK_X5_PEROID * 5  )
) u_tmds_decode_red (
    .tmds_clk           ( hdmi_clk_p          ),
    .tmds_dat           ( hdmi_tx2_p          ),
    .decoded_vde        (                     ),
    .decoded_vsync      (                     ),
    .decoded_hsync      (                     ),
    .decoded_data       ( dec_red             )
);

tb_tmds_decode # (        // only for simulation
    .HDMI_CLK_PEROID    ( PCLK_X5_PEROID * 5  )
) u_tmds_decode_green (
    .tmds_clk           ( hdmi_clk_p          ),
    .tmds_dat           ( hdmi_tx1_p          ),
    .decoded_vde        (                     ),
    .decoded_vsync      (                     ),
    .decoded_hsync      (                     ),
    .decoded_data       ( dec_green           )
);

tb_tmds_decode # (        // only for simulation
    .HDMI_CLK_PEROID    ( PCLK_X5_PEROID * 5  )
) u_tmds_decode_blue (
    .tmds_clk           ( hdmi_clk_p          ),
    .tmds_dat           ( hdmi_tx0_p          ),
    .decoded_vde        ( dec_vde             ),
    .decoded_vsync      ( dec_vsync           ),
    .decoded_hsync      ( dec_hsync           ),
    .decoded_data       ( dec_blue            )
);



/////////////////////////////////////////////////////////////////////////////////////////////
// Check if the decoded pixels match the pixels generated by pixel_generate.v
/////////////////////////////////////////////////////////////////////////////////////////////

tb_pixel_verify u_tb_pixel_verify (
    .clk                ( hdmi_clk_p          ),
    .vde                ( dec_vde             ),
    .vsync              ( dec_vsync           ),
    .red                ( dec_red             ),
    .green              ( dec_green           ),
    .blue               ( dec_blue            )
);


endmodule

