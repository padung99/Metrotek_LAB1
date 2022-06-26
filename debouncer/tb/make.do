vlib work

vlog -sv ../rtl/debouncer.sv
vlog -sv debouncer_tb.sv

vsim debouncer_tb

add log -r /*
add wave -r *
wave zoom full
view -undock wave
run -all
