
//--------------------------------------------------------------------------------------------------------
// Module  : hdmi_tmds_encode
// Type    : synthesizable, IP's sub module
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: encode VSYNC, HSYNC and pixels to 10-bit TMDS data.
//--------------------------------------------------------------------------------------------------------

module hdmi_tmds_encode (
    input  wire       rstn,
    input  wire       clk,
    input  wire       i_en,
    input  wire       i_vde,   // video data enable, to choose between cd (when vde=0) and i_vd (when vde=1)
    input  wire [7:0] i_vd,    // video data (red, green or blue)
    input  wire [1:0] i_cd,    // control data
    output wire       o_en,
    output wire [9:0] o_tmds_bits
);


wire [3:0] i_n1bs  = {3'd0,i_vd[0]} + {3'd0,i_vd[1]} + {3'd0,i_vd[2]} + {3'd0,i_vd[3]} + {3'd0,i_vd[4]} + {3'd0,i_vd[5]} + {3'd0,i_vd[6]} + {3'd0,i_vd[7]};



/////////////////////////////////////////////////////////////////////////////////////////////
// stage E
/////////////////////////////////////////////////////////////////////////////////////////////

reg        e_en    = 1'b0;
reg        e_vde   = 1'b0;
reg  [7:0] e_vd    = 8'd0;
reg  [1:0] e_cd    = 2'd0;
reg        e_bxnor = 1'b0;

always @ (posedge clk or negedge rstn)
    if (~rstn) begin
        e_en    <= 1'b0;
        e_vde   <= 1'b0;
        e_vd    <= 8'd0;
        e_cd    <= 2'd0;
        e_bxnor <= 1'b0;
    end else begin
        e_en    <= i_en;
        e_vde   <= i_vde;
        e_vd    <= i_vd;
        e_cd    <= i_cd;
        e_bxnor <= (i_n1bs>4'd4) || ((i_n1bs==4'd4) && (i_vd[0]==1'b0));
    end

wire [8:0] d_qm;
assign d_qm[0] = e_vd[0];
assign d_qm[1] = e_vd[1] ^ e_bxnor ^ d_qm[0];
assign d_qm[2] = e_vd[2] ^ e_bxnor ^ d_qm[1];
assign d_qm[3] = e_vd[3] ^ e_bxnor ^ d_qm[2];
assign d_qm[4] = e_vd[4] ^ e_bxnor ^ d_qm[3];
assign d_qm[5] = e_vd[5] ^ e_bxnor ^ d_qm[4];
assign d_qm[6] = e_vd[6] ^ e_bxnor ^ d_qm[5];
assign d_qm[7] = e_vd[7] ^ e_bxnor ^ d_qm[6];
assign d_qm[8] = ~e_bxnor;



/////////////////////////////////////////////////////////////////////////////////////////////
// stage F
/////////////////////////////////////////////////////////////////////////////////////////////

reg        f_en  = 1'b0;
reg        f_vde = 1'b0;
reg  [1:0] f_cd  = 2'd0;
reg  [8:0] f_qm  = 9'd0;

always @ (posedge clk or negedge rstn)
    if (~rstn) begin
        f_en  <= 1'b0;
        f_vde <= 1'b0;
        f_cd  <= 2'd0;
        f_qm  <= 9'd0;
    end else begin
        f_en  <= e_en;
        f_vde <= e_vde;
        f_cd  <= e_cd;
        f_qm  <= d_qm;
    end

wire [3:0] f_bal = {3'd0,f_qm[0]} + {3'd0,f_qm[1]} + {3'd0,f_qm[2]} + {3'd0,f_qm[3]} + {3'd0,f_qm[4]} + {3'd0,f_qm[5]} + {3'd0,f_qm[6]} + {3'd0,f_qm[7]} - 4'd4;



/////////////////////////////////////////////////////////////////////////////////////////////
// stage G
/////////////////////////////////////////////////////////////////////////////////////////////

reg        g_en   = 1'b0;
reg        g_vde  = 1'b0;
reg  [1:0] g_cd   = 2'd0;
reg  [8:0] g_qm   = 9'd0;
reg  [3:0] g_bal  = 4'd0;
reg        g_bal0 = 1'b0;

always @ (posedge clk or negedge rstn)
    if (~rstn) begin
        g_en   <= 1'b0;
        g_vde  <= 1'b0;
        g_cd   <= 2'd0;
        g_qm   <= 9'd0;
        g_bal  <= 4'd0;
        g_bal0 <= 1'b0;
    end else begin
        g_en   <= f_en;
        g_vde  <= f_vde;
        g_cd   <= f_cd;
        g_qm   <= f_qm;
        g_bal  <= f_bal;
        g_bal0 <= (f_bal == 4'd0);
    end



/////////////////////////////////////////////////////////////////////////////////////////////
// stage H
/////////////////////////////////////////////////////////////////////////////////////////////

reg        h_en        = 1'b0;
reg  [3:0] h_acc       = 4'd0;
reg  [9:0] h_tmds_bits = 10'd0;

wire       eq_0      = (g_bal0 || (h_acc==4'd0));
wire       eq_sign   = (g_bal[3] == h_acc[3]);
wire       invert_qm = eq_0 ? (~g_qm[8]) : eq_sign;
wire       change    = (g_qm[8] ^ ~eq_sign) & ~eq_0;
wire [3:0] acc_inc   = g_bal - {3'd0, change};
wire [3:0] acc_new   = invert_qm ? (h_acc - acc_inc) : (h_acc + acc_inc);
wire [7:0] tmds_datal= g_qm[7:0] ^ {8{invert_qm}};
wire [9:0] tmds_data = {invert_qm, g_qm[8], tmds_datal};

wire [9:0] tmds_ctrl = (g_cd == 2'b00) ? 10'b1101010100 :
                       (g_cd == 2'b01) ? 10'b0010101011 :
                       (g_cd == 2'b10) ? 10'b0101010100 :
                                         10'b1010101011 ;

always @ (posedge clk or negedge rstn)
    if (~rstn) begin
        h_en        <= 1'b0;
        h_acc       <= 4'd0;
        h_tmds_bits <= 10'd0;
    end else begin
        h_en        <= g_en;
        if (g_en) begin
            h_acc       <= g_vde ? acc_new   : 4'd0;
            h_tmds_bits <= g_vde ? tmds_data : tmds_ctrl;
        end
    end



/////////////////////////////////////////////////////////////////////////////////////////////
// assign output
/////////////////////////////////////////////////////////////////////////////////////////////

assign o_en        = h_en;
assign o_tmds_bits = h_tmds_bits;


endmodule

