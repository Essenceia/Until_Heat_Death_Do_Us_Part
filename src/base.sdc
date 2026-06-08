# read librelane base sdc before overwritting it
read_sdc $::env(SCRIPTS_DIR)/base.sdc

proc get_first_output_pin { instance } {
  set dir "output" 
  puts "pin iter [$instance pin_iterator]"
  set iter [$instance pin_iterator]
  while {[$iter has_next]} {
    set pin [$iter next]
    set pin_dir [get_property $pin "direction"]
    if { [lsearch $dir $pin_dir] !=  -1 } {
	  puts "found pin dir $pin_dir on pin $pin"
      return $pin
    }
  }
}

set mux_clk_cell [get_cells -hierarchical -regexp ".*m_ref_clk_mux"]
set mux_clk_pin [get_first_output_pin $mux_clk_cell]

#can't use the combinational arg as it causes the drt to seg fault
set ::env(OUTPUT_CLOCK) "dephase_clk"
create_generated_clock -name $::env(OUTPUT_CLOCK) -source [get_ports $clock_port] -divide_by 1 -invert $mux_clk_pin
set_propagated_clock [all_clocks]

read_sdc $::env(DESIGN_DIR)/lan8720a.sdc
