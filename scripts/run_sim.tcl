if {$argc < 1} { puts "usage: vsim -c -do {do scripts/run_sim.tcl <config>}"; quit -code 2 }
set cfg [lindex $argv 0]
file mkdir "results/$cfg"
if {[file exists work]} { vdel -all -lib work }
vlib work
vlog -sv rtl/conv_top.v tb/tb_conv.v
vsim -c work.tb_conv -do "run -all; quit -f"
