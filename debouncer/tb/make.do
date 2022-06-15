vlib work

vlog -sv ../rtl/debouncer.sv
vlog -sv debouncer_tb.sv

vsim debouncer_tb

add log -r /*
add wave -r *
run -all
