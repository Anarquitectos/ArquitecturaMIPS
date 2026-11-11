onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -divider "Clock and instruction"
add wave sim:/type_r_monocycle_tb/clk
add wave sim:/type_r_monocycle_tb/reset
add wave -radix hexadecimal sim:/type_r_monocycle_tb/dut/pc_out
add wave -radix hexadecimal sim:/type_r_monocycle_tb/dut/instruction
add wave -divider "ALU inputs and control"
add wave -radix decimal sim:/type_r_monocycle_tb/dut/alu/A
add wave -radix decimal sim:/type_r_monocycle_tb/dut/alu/B
add wave -radix binary sim:/type_r_monocycle_tb/dut/alu_control_signal
add wave -divider "ALU outputs"
add wave -radix decimal sim:/type_r_monocycle_tb/dut/alu_result
add wave sim:/type_r_monocycle_tb/dut/alu_zero_flag
add wave -divider "Register write-back"
add wave -radix decimal sim:/type_r_monocycle_tb/dut/write_reg
add wave -radix decimal sim:/type_r_monocycle_tb/dut/write_back_data
run -all
