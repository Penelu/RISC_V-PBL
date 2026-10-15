# riscv_timing.xdc - clock constraint for synthesis
# Only the clock period: enough for Vivado to report timing. Pin locations
# and I/O standards depend on the board and go in a separate file.
#
# 50 MHz: in the single-cycle core one instruction crosses imem, regfile,
# ALU and dmem in a single clock, about 15 ns after synthesis, so 100 MHz
# (10 ns) does not fit.
create_clock -name clk -period 20.000 [get_ports clk]
