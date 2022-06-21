vlib work

vlog -sv ../rtl/bit_population_counter.sv
vlog -sv bit_population_counter_tb.sv

vsim -G/bit_population_counter_tb/WIDTH_TB=5 bit_population_counter_tb

add log -r /*
add wave -r *
run -all