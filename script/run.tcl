# Notes and references :
# http://www.fpgadeveloper.com/2014/08/version-control-for-vivado-projects.html
# http://xillybus.com/tutorials/vivado-version-control-packaging
# http://www.fpgadeveloper.com/2016/11/tcl-automation-tips-for-vivado-xilinx-sdk.html

#******************************************************************************
# Project configuration
#******************************************************************************

# Part name
set partName            xczu3eg-sfva625-1-i

# Board name            (optional, can be commented out)
set boardPartName       "em.avnet.com:ultrazed_eg_iocc_production:part0:1.0"

# Synthesis flow and strategy
set synthFlow           {Vivado Synthesis 2017}
set synthStrategy       "Vivado Synthesis Defaults"

# Implementation flow and strategy
set implFlow            {Vivado Implementation 2017}
set implStrategy        "Vivado Implementation Defaults"

# Debug Level           set to either -quiet or -verbose
set dbgl                -quiet

#******************************************************************************
# End project configuration
#******************************************************************************

#******************************************************************************
# Script paths origin
#******************************************************************************
# Set the reference directory for source file relative paths to the current
# run_config.tcl script location
set origin_dir          [file dirname [info script]]

#******************************************************************************
# Sanity check
#******************************************************************************

# Check that we got the correct argument count
if { [llength $argv] < 2} {
    puts "Error: not enough argument"
    exit 2
}

set ecc_id [lindex $argv 0]
set entity_id [lindex $argv 1]
set entity_name [lindex [split $entity_id /] end]

set dep_file_list {}

set remaining_arg [lreplace ${argv} 0 1]
foreach temp_src $remaining_arg {
    puts $temp_src
    set temp_src "${origin_dir}/../entities/${temp_src}"
    if { [file exists $temp_src] == 0} {
        puts "Error: file not found: ${temp_src}"
        exit 2
    } else {
        lappend dep_file_list "${temp_src}"
    }
}

# Check that testbench source exist
set tb_src "${origin_dir}/../work/${ecc_id}/${entity_name}_tb.vhd"
if { [file exists $tb_src] == 0} {
    puts "Error: file not found: ${tb_src}"
    exit 2
}

# Check that entity source exist
set entity_src "${origin_dir}/../entities/${entity_id}.vhd"
if { [file exists $tb_src] == 0} {
    puts "Error: file not found: ${entity_src}"
    exit 2
}

#******************************************************************************
# Script paths configuration
#******************************************************************************

# Project name
set project_name        "${entity_name}_tb"

# TCL scripts folder
set script_dir          "${origin_dir}"

# Projects folder
set projectsPath        "${origin_dir}/../work/${ecc_id}"

# Reports folder
set reportsPath         "${origin_dir}/../work/${ecc_id}"

# Report name
set reportFilename      "global_timming_report.txt"

# Static HDL path
set staticHdlPath       "${origin_dir}/../entities"

# Global constraints path
set constraintsPath     "${origin_dir}/sources/constraints"

#******************************************************************************
# End script paths configuration
#******************************************************************************

#******************************************************************************
#puts "Starting flow"
#******************************************************************************

source ${script_dir}/create_tb_projects.tcl

#******************************************************************************
#puts "Script end"
#puts "####################################################################"
#******************************************************************************
