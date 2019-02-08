set full_project_name   ${project_name}
set projectPath         "${projectsPath}/${full_project_name}"

#******************************************************************************
puts "####################################################################"
puts "Creating simulation project: ${full_project_name}"
#******************************************************************************

# Create project
create_project -f $full_project_name $projectPath/ -part $partName

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [current_project]
if { [info exists ::boardPartName] } {
set_property -name "board_part" -value $boardPartName -objects $obj
}
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "dsa.num_compute_units" -value "60" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_output_repo"                            \
                -value "$proj_dir/${full_project_name}.cache/ip"  \
                -objects $obj
#set_property $dbgl -name "pr_flow" -value "1" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "source_mgmt_mode" -value "None" -objects $obj
set_property -name "target_language" -value "VHDL" -objects $obj
set_property -name "xpm_libraries" -value "XPM_CDC XPM_FIFO XPM_MEMORY"\
            -objects $obj

#******************************************************************************
puts "Adding implementation source files"
#******************************************************************************

## Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets $dbgl sources_1] ""]} {
    create_fileset -srcset sources_1
}

# Add sources to sources_1 fileset as VHDL2008
set impl_file_list {}
lappend impl_file_list "${staticHdlPath}/../work/${ecc_id}/domain_param_pkg.vhd"
set     impl_file_list [concat $impl_file_list $dep_file_list]
foreach file $impl_file_list {
    set file [file normalize $file]
    add_files -fileset sources_1 $file
    set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$file"]]
    set_property -name "file_type" -value "VHDL 2008" -objects $file_obj
    puts "-> file: [lrange [file split $file] end end]"
}

set obj [get_filesets sources_1]
# Set top entity
set_property -name "top" -value "${entity_name}" -objects $obj

#******************************************************************************
puts "Adding simulation source files"
#******************************************************************************

## Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets $dbgl sim_1] ""]} {
    create_fileset -simset sim_1
}

# Add sources to sim_1 fileset as VHDL2008
set sim_file_list {}
lappend sim_file_list "${staticHdlPath}/../work/${ecc_id}/domain_param_pkg.vhd"
lappend sim_file_list "${staticHdlPath}/../tools/logger/html_report_pkg.vhd"
lappend sim_file_list "${staticHdlPath}/../tools/logger/logger_pkg.vhd"
lappend sim_file_list "${staticHdlPath}/../tools/logger/project_logger_pkg.vhd"
set     sim_file_list [concat $sim_file_list $dep_file_list]
lappend sim_file_list "${staticHdlPath}/../work/${ecc_id}/${entity_name}_tb.vhd"
foreach file $sim_file_list {
    set file [file normalize $file]
    add_files -fileset sim_1 $file
    set file_obj [get_files -of_objects [get_filesets sim_1] [list "*$file"]]
    set_property -name "file_type" -value "VHDL 2008" -objects $file_obj
    puts "-> file: [lrange [file split $file] end end]"
}

set obj [get_filesets sim_1]
# Set top entity
set_property -name "top" -value "${entity_name}_tb" -objects $obj
# Set simulation time
set_property -name {xsim.simulate.runtime} -value {-all} -objects $obj

#******************************************************************************
puts "Running simulation"
#******************************************************************************

# launch_simulation always return success when run with -quiet
if { [catch {launch_simulation -step all -simset sim_1 -mode behavioral} fid] } {
    puts stderr "Testbench failed: $fid"
    close_project $dbgl
    exit 1
}

# FIXME check if -force is needed here, and if we want to save
# simulation project before closing it
close_sim $dbgl

#******************************************************************************
puts "Running synthesis"
#******************************************************************************

launch_runs -quiet synth_1
wait_on_run -quiet synth_1

#******************************************************************************
puts "Closing project: $full_project_name"
#******************************************************************************
close_project $dbgl
