vlib work

set source_file {
  "../rtl/traffic_lights.sv"
  "traffic_lights_tb.sv"
}

foreach files $source_file {
  vlog -sv $files
}

#Return the name of last file (without extension .sv)
set fbasename [file rootname [file tail [lindex $source_file end]]]

vsim $fbasename

add log -r /*s
add wave -r *
view -undock wave
run -all


