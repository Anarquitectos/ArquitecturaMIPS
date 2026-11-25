set tb cesar_mips_tb

add wave -divider "Reloj y control"
add wave /$tb/clk /$tb/reset /$tb/cycle

add wave -divider "Fetch y PC"
add wave -radix hex /$tb/dut/pc_out /$tb/dut/instruction /$tb/dut/jump_address
add wave /$tb/dut/branch /$tb/dut/branch_AND /$tb/dut/jump

add wave -divider "Unidad de control"
add wave /$tb/dut/regDst /$tb/dut/aluSrc /$tb/dut/memToReg
add wave /$tb/dut/regWrite /$tb/dut/memRead /$tb/dut/memWrite
add wave -radix binary /$tb/dut/aluOp /$tb/dut/alu_control_signal

add wave -divider "Registros"
add wave -radix hex /$tb/dut/read_data1 /$tb/dut/read_data2
add wave -radix hex /$tb/dut/write_reg /$tb/dut/write_back_data
add wave -radix hex /$tb/dut/register_bank/mem

add wave -divider "ALU"
add wave -radix hex /$tb/dut/sign_ext /$tb/dut/alu_input_b
add wave -radix hex /$tb/dut/alu_result
add wave /$tb/dut/alu_zero_flag

add wave -divider "RAM"
add wave -radix unsigned /$tb/dut/alu_result
add wave /$tb/dut/memWrite
add wave -radix hex /$tb/dut/read_data2 /$tb/dut/mem_read_data
add wave -radix hex /$tb/dut/data_memory/mem

add wave -divider "Resultado"
add wave -radix decimal /$tb/errors
