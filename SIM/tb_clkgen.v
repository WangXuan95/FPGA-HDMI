
//--------------------------------------------------------------------------------------------------------
// Module  : tb_clkgen
// Type    : simulation, sub module
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: Generate clock with jitter (non-synthesizable!!!, only for simulation)
//--------------------------------------------------------------------------------------------------------

module tb_clkgen #(
    parameter OFFSET = 0,
    parameter PERIOD = 10000,
    parameter JITTER = 0
) (
    output reg clk
);

integer T = PERIOD / 2;
integer t0 = 0;
integer t1 = 0;

initial begin
    clk = 1'b0;
    # (OFFSET);
    while (1) begin
        t1 = $random;
        t1 = (t1 < 0) ? -t1 : t1;
        t1 = (t1 % (2 * JITTER + 1)) - JITTER;
        # (T - t0 + t1);
        clk = ~clk;
        t0 = t1;
    end
end

endmodule

