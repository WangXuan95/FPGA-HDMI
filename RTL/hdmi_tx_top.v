
//--------------------------------------------------------------------------------------------------------
// Module  : hdmi_tx_top
// Type    : synthesizable, IP's top
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: A HDMI TX (display) controller.
//           It can fetch video pixels from user-specified clock domain, cross them to the HDMI clock domain.
//           Then, display the video to HDMI (following DVI TMDS timing specification).
//--------------------------------------------------------------------------------------------------------

module hdmi_tx_top #(
    // the parameter of request to response latency ---------------------------------------
    parameter         RESP_LATENCY = 1,        // 1, 2, or 3
    // paramter of video sizes ------------------------------------------------------------
    parameter  [13:0] H_TOTAL      = 14'd800,
    parameter  [13:0] H_DRAW_START = 14'd0,
    parameter  [13:0] H_DRAW_WIDTH = 14'd640,
    parameter  [13:0] H_SYNC_START = 14'd656,
    parameter  [13:0] H_SYNC_WIDTH = 14'd96,
    parameter  [13:0] V_TOTAL      = 14'd525,
    parameter  [13:0] V_DRAW_START = 14'd0,
    parameter  [13:0] V_DRAW_HEIGHT= 14'd480,
    parameter  [13:0] V_SYNC_START = 14'd490,
    parameter  [13:0] V_SYNC_HEIGHT= 14'd2
) (
    // user's clock and reset -------------------------------------------------------------
    input  wire       rstn,
    input  wire       clk,        // can be asynchronous with pclk_x5. Its frequency must be slightly higher than f(pclk_x5) / 5
    // user's pixel request interface (these signals synchronize with clk) ----------------
    output reg        req_en,     // request for a pixel
    output reg        req_sof,    // the requested pixel is at start of frame
    output reg        req_eof,    // the requested pixel is at end   of frame
    output reg        req_sol,    // the requested pixel is at start of line
    output reg        req_eol,    // the requested pixel is at end   of line
    // user's pixel response interface (these signals synchronize with clk) ---------------
    input  wire [7:0] resp_red,
    input  wire [7:0] resp_green,
    input  wire [7:0] resp_blue,
    // HDMI driving clock, whose frequency must be 5 * pclk (pclk is the pixel clock) -----
    input  wire       pclk_x5,
    // HDMI TX out ------------------------------------------------------------------------
    output wire       hdmi_clk_p,
    output wire       hdmi_clk_n,
    output wire       hdmi_tx0_p,
    output wire       hdmi_tx0_n,
    output wire       hdmi_tx1_p,
    output wire       hdmi_tx1_n,
    output wire       hdmi_tx2_p,
    output wire       hdmi_tx2_n
);



reg  [13:0] hcnt    = 14'd0;
reg  [13:0] vcnt    = 14'd0;

reg         a_en    = 1'b0;
reg         a_hsync = 1'b0;
reg         a_vsync = 1'b0;

reg         b_en    = 1'b0;
reg         b_hsync = 1'b0;
reg         b_vsync = 1'b0;
reg         b_vde   = 1'b0;

reg         c_en    = 1'b0;
reg         c_hsync = 1'b0;
reg         c_vsync = 1'b0;
reg         c_vde   = 1'b0;

reg         d_en    = 1'b0;
reg         d_hsync = 1'b0;
reg         d_vsync = 1'b0;
reg         d_vde   = 1'b0;

reg  [ 7:0] d_red, d_green, d_blue;

//wire        h_rdy;
wire        h_en;
wire [ 9:0] h_tmds0_bits;
wire [ 9:0] h_tmds1_bits;
wire [ 9:0] h_tmds2_bits;

wire        j_en;
wire [ 9:0] j_tmds0_bits;
wire [ 9:0] j_tmds1_bits;
wire [ 9:0] j_tmds2_bits;

reg  [ 2:0] j_cnt5        = 3'd0;  // HDMI control counter, period=5 (j_cnt5 = 0 -> 1 -> 2 -> 3 -> 4 -> 0)
reg         j_fetch_start = 1'b0;
reg         j_fetch       = 1'b0;

wire        half_empty;

reg  [ 9:0] k_tmds0_bits  = 10'd0;
reg  [ 9:0] k_tmds1_bits  = 10'd0;
reg  [ 9:0] k_tmds2_bits  = 10'd0;
reg  [ 9:0] k_tmdsc_bits  = 10'd0;



/////////////////////////////////////////////////////////////////////////////////////////////
// reset synchronize
/////////////////////////////////////////////////////////////////////////////////////////////

reg [3:0] rstn_x5_shift = 4'd0;
wire      rstn_x5 = rstn_x5_shift[3];

always @ (posedge pclk_x5 or negedge rstn)
    if (~rstn) rstn_x5_shift <= 4'd0;
    else       rstn_x5_shift <= {rstn_x5_shift[2:0], 1'b1};

reg [3:0] rstn_main_shift = 4'd0;
wire      rstn_main = rstn_main_shift[3];

always @ (posedge clk or negedge rstn_x5)
    if (~rstn_x5) rstn_main_shift <= 4'd0;
    else          rstn_main_shift <= {rstn_main_shift[2:0], 1'b1};



/////////////////////////////////////////////////////////////////////////////////////////////
// pixel coordinate counter
/////////////////////////////////////////////////////////////////////////////////////////////

always @ (posedge clk or negedge rstn_main)
    if (~rstn_main) begin
        hcnt <= 14'd0;
        vcnt <= 14'd0;
    end else begin
        if (half_empty) begin
            if (hcnt < (H_TOTAL - 14'd1)) begin
                hcnt <= hcnt + 14'd1;
            end else begin
                hcnt <= 14'd0;
                vcnt <= (vcnt < (V_TOTAL - 14'd1)) ? (vcnt + 14'd1) : 14'd0;
            end
        end
    end

wire hsync  = (hcnt >= H_SYNC_START) && (hcnt < (H_SYNC_START+H_SYNC_WIDTH) );
wire vsync  = (vcnt >= V_SYNC_START) && (vcnt < (V_SYNC_START+V_SYNC_HEIGHT));
wire draw   = (hcnt >= H_DRAW_START) && (hcnt < (H_DRAW_START+H_DRAW_WIDTH) ) && (vcnt >= V_DRAW_START) && (vcnt < (V_DRAW_START+V_DRAW_HEIGHT));
wire hfirst = (hcnt == H_DRAW_START);
wire hlast  = (hcnt == (H_DRAW_START+H_DRAW_WIDTH-14'd1));
wire vfirst = (vcnt == V_DRAW_START);
wire vlast  = (vcnt == (V_DRAW_START+V_DRAW_HEIGHT-14'd1));



/////////////////////////////////////////////////////////////////////////////////////////////
// stage A : generate HSYNC, VSYNC, and request signals
/////////////////////////////////////////////////////////////////////////////////////////////

initial {req_en, req_sol, req_eol, req_sof, req_eof} = 5'b0;

always @ (posedge clk or negedge rstn_main)
    if (~rstn_main) begin
        {a_en, a_hsync, a_vsync} <= 3'b0;
        {req_en, req_sol, req_eol, req_sof, req_eof} <= 5'b0;
    end else begin
        a_en    <= half_empty;
        a_hsync <= hsync;
        a_vsync <= vsync;
        req_en  <= half_empty & draw;
        req_sol <= half_empty & draw & hfirst;
        req_eol <= half_empty & draw & hlast;
        req_sof <= half_empty & draw & hfirst & vfirst;
        req_eof <= half_empty & draw & hlast  & vlast;
    end



/////////////////////////////////////////////////////////////////////////////////////////////
// stage B - D : get user response
/////////////////////////////////////////////////////////////////////////////////////////////

always @ (posedge clk or negedge rstn_main)
    if (~rstn_main) begin
        {b_en, b_hsync, b_vsync, b_vde} <= 4'b0;
        {c_en, c_hsync, c_vsync, c_vde} <= 4'b0;
        {d_en, d_hsync, d_vsync, d_vde} <= 4'b0;
    end else begin
        {b_en, b_hsync, b_vsync, b_vde} <= {a_en, a_hsync, a_vsync, req_en};
        {c_en, c_hsync, c_vsync, c_vde} <= {b_en, b_hsync, b_vsync, b_vde};
        {d_en, d_hsync, d_vsync, d_vde} <= {c_en, c_hsync, c_vsync, c_vde};
    end

generate
    if          (RESP_LATENCY >= 3) begin
        always @ (*)
            {d_red, d_green, d_blue}  = {resp_red, resp_green, resp_blue};
        
    end else if (RESP_LATENCY == 2) begin
        always @ (posedge clk)
            {d_red, d_green, d_blue} <= {resp_red, resp_green, resp_blue};
        
    end else begin
        reg  [ 7:0] c_red, c_green, c_blue;
        always @ (posedge clk) begin
            {c_red, c_green, c_blue} <= {resp_red, resp_green, resp_blue};
            {d_red, d_green, d_blue} <= {c_red, c_green, c_blue};
        end
    end
endgenerate



/////////////////////////////////////////////////////////////////////////////////////////////
// stage E - H : TMDS encoding
/////////////////////////////////////////////////////////////////////////////////////////////

hdmi_tmds_encode u_tmds_encode_red (
    .rstn         ( rstn_main                                  ),
    .clk          ( clk                                        ),
    .i_en         ( d_en                                       ),
    .i_vde        ( d_vde                                      ),
    .i_vd         ( d_red                                      ),
    .i_cd         ( 2'b00                                      ),
    .o_en         (                                            ),
    .o_tmds_bits  ( h_tmds2_bits                               )
);

hdmi_tmds_encode u_tmds_encode_green (
    .rstn         ( rstn_main                                  ),
    .clk          ( clk                                        ),
    .i_en         ( d_en                                       ),
    .i_vde        ( d_vde                                      ),
    .i_vd         ( d_green                                    ),
    .i_cd         ( 2'b00                                      ),
    .o_en         (                                            ),
    .o_tmds_bits  ( h_tmds1_bits                               )
);

hdmi_tmds_encode u_tmds_encode_blue (
    .rstn         ( rstn_main                                  ),
    .clk          ( clk                                        ),
    .i_en         ( d_en                                       ),
    .i_vde        ( d_vde                                      ),
    .i_vd         ( d_blue                                     ),
    .i_cd         ( {d_vsync, d_hsync}                         ),
    .o_en         ( h_en                                       ),
    .o_tmds_bits  ( h_tmds0_bits                               )
);



/////////////////////////////////////////////////////////////////////////////////////////////
// stage J : cross to clock domain pclk_x5
/////////////////////////////////////////////////////////////////////////////////////////////

hdmi_async_fifo #(
    .DW           ( 30                                         ),
    .EA           ( 5                                          )
) u_hdmi_async_fifo (
    .i_rstn       ( rstn_main                                  ),
    .i_clk        ( clk                                        ),
    .i_tready     ( /*h_rdy*/                                  ),
    .i_tvalid     ( h_en                                       ),
    .i_tdata      ( {h_tmds0_bits, h_tmds1_bits, h_tmds2_bits} ),
    .o_rstn       ( rstn_x5                                    ),
    .o_clk        ( pclk_x5                                    ),
    .o_tready     ( j_fetch                                    ),
    .o_tvalid     ( j_en                                       ),
    .o_tdata      ( {j_tmds0_bits, j_tmds1_bits, j_tmds2_bits} ),
    .w_half_empty ( half_empty                                 )
);



/////////////////////////////////////////////////////////////////////////////////////////////
// stage H : fetch control
/////////////////////////////////////////////////////////////////////////////////////////////

always @ (posedge pclk_x5 or negedge rstn_x5)
    if (~rstn_x5) begin
        j_cnt5        <= 3'd0;
        j_fetch_start <= 1'b0;
        j_fetch       <= 1'b0;
    end else begin
        j_cnt5  <= j_cnt5[2] ? 3'd0 : (j_cnt5 + 3'd1);
        if (j_en & j_cnt5[2]) j_fetch_start <= 1'b1;
        j_fetch <= j_cnt5[2] & j_fetch_start;
    end



/////////////////////////////////////////////////////////////////////////////////////////////
// stage J : assert that u_hdmi_async_fifo never empty (only for simulation)
/////////////////////////////////////////////////////////////////////////////////////////////
/*
always @ (posedge pclk_x5 or negedge rstn_x5)
    if (~rstn_x5) begin
    end else begin
        if (j_fetch & ~j_en) begin
            $display("error : u_hdmi_async_fifo empty");
            $finish;
        end
    end*/



/////////////////////////////////////////////////////////////////////////////////////////////
// stage H : assert that u_hdmi_async_fifo never full (only for simulation)
/////////////////////////////////////////////////////////////////////////////////////////////
/*
always @ (posedge clk or negedge rstn_main)
    if (~rstn_main) begin
    end else begin
        if (~h_rdy & h_en) begin
            $display("error : u_hdmi_async_fifo full");
            $finish;
        end
    end*/



/////////////////////////////////////////////////////////////////////////////////////////////
// stage K : serialize TMDS signals
/////////////////////////////////////////////////////////////////////////////////////////////

always @ (posedge pclk_x5)
    if (j_fetch) begin
        k_tmds0_bits <= j_tmds0_bits;
        k_tmds1_bits <= j_tmds1_bits;
        k_tmds2_bits <= j_tmds2_bits;
        k_tmdsc_bits <= 10'b0000011111;
    end else begin
        k_tmds0_bits <= k_tmds0_bits >> 2;
        k_tmds1_bits <= k_tmds1_bits >> 2;
        k_tmds2_bits <= k_tmds2_bits >> 2;
        k_tmdsc_bits <= k_tmdsc_bits >> 2;
    end

hdmi_tddr u0p_ddr (pclk_x5,  k_tmds0_bits[1:0], hdmi_tx0_p);
hdmi_tddr u0n_ddr (pclk_x5, ~k_tmds0_bits[1:0], hdmi_tx0_n);
hdmi_tddr u1p_ddr (pclk_x5,  k_tmds1_bits[1:0], hdmi_tx1_p);
hdmi_tddr u1n_ddr (pclk_x5, ~k_tmds1_bits[1:0], hdmi_tx1_n);
hdmi_tddr u2p_ddr (pclk_x5,  k_tmds2_bits[1:0], hdmi_tx2_p);
hdmi_tddr u2n_ddr (pclk_x5, ~k_tmds2_bits[1:0], hdmi_tx2_n);
hdmi_tddr u3p_ddr (pclk_x5,  k_tmdsc_bits[1:0], hdmi_clk_p);
hdmi_tddr u3n_ddr (pclk_x5, ~k_tmdsc_bits[1:0], hdmi_clk_n);


endmodule

