vlib work

set source_file {
  "../rtl/serializer.sv"
  "serializer_tb.sv"
}

foreach files $source_file {
  vlog -sv $files
}

#Return the name of last file (without extension .sv)
set fbasename [file rootname [file tail [lindex $source_file end]]]

vsim $fbasename

add log -r /*

#add wave "sim:/serializer_tb/data_o"
#add wave "sim:/serializer_tb/data_test_i" 

add wave -r *
view -undock wave
run -all
