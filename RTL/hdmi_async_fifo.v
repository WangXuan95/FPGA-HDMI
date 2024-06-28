
//--------------------------------------------------------------------------------------------------------
// Module  : hdmi_async_fifo
// Type    : synthesizable, IP's sub module
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: cross TMDS data from user's clock domain to HDMI clock domain.
//--------------------------------------------------------------------------------------------------------

module hdmi_async_fifo #(
    parameter            DW = 8,
    parameter            EA = 10
) (
    //
    input  wire          i_rstn,
    input  wire          i_clk,
    output wire          i_tready,
    input  wire          i_tvalid,
    input  wire [DW-1:0] i_tdata,
    //
    input  wire          o_rstn,
    input  wire          o_clk,
    input  wire          o_tready,
    output reg           o_tvalid,
    output reg  [DW-1:0] o_tdata,
    //
    output wire          w_half_empty
);


reg  [DW-1:0] buffer [(1<<EA)-1:0];  // may automatically synthesize to BRAM

reg  [EA:0] wptr=0, wq_wptr_grey=0, rq1_wptr_grey=0, rq2_wptr_grey=0;
reg  [EA:0] rptr=0, rq_rptr_grey=0, wq1_rptr_grey=0, wq2_rptr_grey=0;
reg  [EA:0] rptr_a1 = {{EA{1'b0}}, 1'b1};                                // rptr_a1 always equal to rptr+1, but using register to optimize timing
wire [EA:0] rptr_next = (o_tvalid & o_tready) ? rptr_a1 : rptr;

wire [EA:0] wptr_grey      = (wptr >> 1)      ^ wptr;
wire [EA:0] rptr_grey      = (rptr >> 1)      ^ rptr;
wire [EA:0] rptr_next_grey = (rptr_next >> 1) ^ rptr_next;

always @ (posedge i_clk or negedge i_rstn)
    if(~i_rstn)
        wq_wptr_grey <= 0;
    else
        wq_wptr_grey <= wptr_grey;

always @ (posedge o_clk or negedge o_rstn)
    if(~o_rstn)
        {rq2_wptr_grey, rq1_wptr_grey} <= 0;
    else
        {rq2_wptr_grey, rq1_wptr_grey} <= {rq1_wptr_grey, wq_wptr_grey};

always @ (posedge o_clk or negedge o_rstn)
    if(~o_rstn)
        rq_rptr_grey <= 0;
    else
        rq_rptr_grey <= rptr_grey;

always @ (posedge i_clk or negedge i_rstn)
    if(~i_rstn)
        {wq2_rptr_grey, wq1_rptr_grey} <= 0;
    else
        {wq2_rptr_grey, wq1_rptr_grey} <= {wq1_rptr_grey, rq_rptr_grey};

wire w_full  = (wq2_rptr_grey == {~wptr_grey[EA:EA-1], wptr_grey[EA-2:0]} );
wire r_empty = (rq2_wptr_grey == rptr_next_grey                           );

assign i_tready = ~w_full;



always @ (posedge i_clk or negedge i_rstn)
    if(~i_rstn) begin
        wptr <= 0;
    end else begin
        if(i_tvalid & ~w_full)
            wptr <= wptr + {{EA{1'b0}}, 1'b1};
    end

always @ (posedge i_clk)
    if(i_tvalid & ~w_full)
        buffer[wptr[EA-1:0]] <= i_tdata;



initial o_tvalid = 1'b0;

always @ (posedge o_clk or negedge o_rstn)
    if (~o_rstn) begin
        rptr     <= 0;
        rptr_a1  <= {{EA{1'b0}}, 1'b1};
        o_tvalid <= 1'b0;
    end else begin
        rptr     <= rptr_next;
        rptr_a1  <= rptr_next + {{EA{1'b0}}, 1'b1};
        o_tvalid <= ~r_empty;
    end

always @ (posedge o_clk)
    o_tdata <= buffer[rptr_next[EA-1:0]];



/////////////////////////////////////////////////////////////////////////////////////////////
// judge half full
/////////////////////////////////////////////////////////////////////////////////////////////

function  [EA:0] gray_to_binary;
    input [EA:0] gray;
    integer i;
begin
    gray_to_binary[EA] = gray[EA];
    for (i = EA-1; i >= 0; i = i - 1) begin
        gray_to_binary[i] = gray_to_binary[i+1] ^ gray[i];
    end
end
endfunction

wire [EA-2:0] TMP = 0;
wire [EA:0] PTR_QUARTER = {2'b01, TMP};

reg  [EA:0] wq2_rptr = 0;

always @ (posedge i_clk or negedge i_rstn)
    if (~i_rstn)
        wq2_rptr <= 0;
    else
        wq2_rptr <= gray_to_binary(wq1_rptr_grey);

wire [EA:0] wr_delta = wptr - wq2_rptr;
assign w_half_empty = (wr_delta < PTR_QUARTER);

endmodule

