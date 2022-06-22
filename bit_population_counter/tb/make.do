vlib work

vlog -sv ../rtl/bit_population_counter.sv
vlog -sv bit_population_counter_tb.sv
vlog -sv top_tb.sv

vsim top_tb -t us
#vsim -G/bit_population_counter_tb/WIDTH_TB=5 bit_population_counter_tb -t us

add log -r /*

add wave -group dut1 /top_tb/dut1/dut/*
add wave -group dut1 -group dut1_tb /top_tb/dut1/*

add wave -group dut2 /top_tb/dut2/dut/*
add wave -group dut2 -group dut2_tb /top_tb/dut2/*

add wave -group dut3 /top_tb/dut3/dut/*
add wave -group dut3 -group dut3_tb /top_tb/dut3/*

run 1 ms
