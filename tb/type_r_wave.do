set tb type_r_monocycle_tb
add wave -divider Reloj
add wave /$tb/clk /$tb/reset
add wave -divider Fetch
add wave -radix hex /$tb/dut/pc_out /$tb/dut/instruction
add wave -divider Control
add wave /$tb/dut/regDst /$tb/dut/aluSrc /$tb/dut/memToReg /$tb/dut/regWrite /$tb/dut/memRead /$tb/dut/memWrite /$tb/dut/extOp
add wave -radix binary /$tb/dut/aluOp
add wave -divider Datos
add wave -radix hex /$tb/dut/read_data1 /$tb/dut/read_data2 /$tb/dut/sign_ext /$tb/dut/alu_input_b
add wave -radix binary /$tb/dut/alu_control_signal
add wave -radix hex /$tb/dut/alu_result
add wave /$tb/dut/alu_zero_flag
add wave -radix unsigned /$tb/dut/write_reg
add wave -radix hex /$tb/dut/write_back_data /$tb/dut/mem_read_data
