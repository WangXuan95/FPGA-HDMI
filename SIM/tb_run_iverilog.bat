del sim.out dump.vcd
iverilog  -g2001  -o sim.out  tb_*.v  pixel_generate.v  ../RTL/*.v
vvp -n sim.out
del sim.out
pause