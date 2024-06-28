
//--------------------------------------------------------------------------------------------------------
// Module  : tb_tmds_decode
// Type    : simulation, sub module
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: Decode a TMDS channel (non-synthesizable!!!, only for simulation)
//--------------------------------------------------------------------------------------------------------

module tb_tmds_decode # (
    parameter  HDMI_CLK_PEROID = 3145
) (
    // input
    input  wire       tmds_clk,
    input  wire       tmds_dat,
    // output decoded data
    output wire       decoded_vde,
    output wire       decoded_vsync,
    output wire       decoded_hsync,
    output wire [7:0] decoded_data
);

localparam L1 = HDMI_CLK_PEROID / 20;
localparam L2 = HDMI_CLK_PEROID / 10;

reg [ 9:0] tmds_data = 10'd0;
reg [10:0] decoded   = 11'd0;
reg        started   = 1'b0;

assign {decoded_vde, decoded_vsync, decoded_hsync, decoded_data} = decoded;

initial begin
    while(1) begin
        @ (posedge tmds_clk);
        
        if (started) begin
            case (tmds_data)
                10'b1101010100 : decoded <= 11'b0_00_00000000;
                10'b0010101011 : decoded <= 11'b0_01_00000000;
                10'b0101010100 : decoded <= 11'b0_10_00000000;
                10'b1010101011 : decoded <= 11'b0_11_00000000;
                
                default : begin
                    tmds_data[8] = ~tmds_data[8];
                    if (tmds_data[9])
                        tmds_data[7:0] = ~tmds_data[7:0];
                    
                    decoded[7] <= tmds_data[7] ^ tmds_data[6] ^ tmds_data[8];
                    decoded[6] <= tmds_data[6] ^ tmds_data[5] ^ tmds_data[8];
                    decoded[5] <= tmds_data[5] ^ tmds_data[4] ^ tmds_data[8];
                    decoded[4] <= tmds_data[4] ^ tmds_data[3] ^ tmds_data[8];
                    decoded[3] <= tmds_data[3] ^ tmds_data[2] ^ tmds_data[8];
                    decoded[2] <= tmds_data[2] ^ tmds_data[1] ^ tmds_data[8];
                    decoded[1] <= tmds_data[1] ^ tmds_data[0] ^ tmds_data[8];
                    decoded[0] <= tmds_data[0];
                    
                    decoded[10:8] <= 3'b1_00;
                end
            endcase
        end
        
        started = 1'b1;
        
        #(L1) tmds_data[0] = tmds_dat;
        #(L2) tmds_data[1] = tmds_dat;
        #(L2) tmds_data[2] = tmds_dat;
        #(L2) tmds_data[3] = tmds_dat;
        #(L2) tmds_data[4] = tmds_dat;
        #(L2) tmds_data[5] = tmds_dat;
        #(L2) tmds_data[6] = tmds_dat;
        #(L2) tmds_data[7] = tmds_dat;
        #(L2) tmds_data[8] = tmds_dat;
        #(L2) tmds_data[9] = tmds_dat;
    end
end

endmodule

