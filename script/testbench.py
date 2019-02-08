import os, errno
from subprocess import call
import shutil
import os.path
import sys
import fileinput
import datetime
from sage.all import *

def ident(n, string):
    return " " * n + string

# Base Testbench class, that is derived by actual testbench
class TestBench():
    def __init__(self, dp, entity):
        self.dp          = dp
        self.entity      = entity
        self.header      = []
        self.constant    = []
        self.generic     = []
        self.port        = []
        self.signal      = []
        self.generic_map = []
        self.port_map    = []
        self.func_param  = []
        self.func_var    = []
        self.drive       = []
        self.compare     = []
        self.action      = []
        # Build default header
        self.add_header( "-- Testbench for entity " + self.entity.get_name() )
        self.add_header( "-- Generated on " + str(datetime.datetime.now()) )
        self.add_header( "--" )
        self.add_header( "-- Domain parameters: " + dp.id )
        self.add_header( "--   prime = " + str(dp.p) )
        if hasattr(dp, 'E1'):
            self.add_header( "--   E1 = " + str(dp.E1) )
        if hasattr(dp, 'E2'):
            self.add_header( "--   E2 = " + str(dp.E2) )
        self.add_header( "--" )

    ###########################################################################
    # Methods to add data in testbench object
    def add_header(self, line):
        self.header.append(line)

    def add_constant(self, line):
        self.constant.append(line)

    def add_generic(self, line):
        self.generic.append(line)

    def add_port(self, line):
        self.port.append(line)

    def add_signal(self, line):
        self.signal.append(line)

    def add_generic_map(self, line):
        self.generic_map.append(line)

    def add_port_map(self, line):
        self.port_map.append(line)

    def add_func_param(self, line):
        self.func_param.append(line)

    def add_func_var(self, line):
        self.func_var.append(line)

    def add_drive(self, line):
        self.drive.append(line)

    def add_compare(self, line):
        self.compare.append(line)

    def add_action(self, line):
        self.action.append(line)

    ###########################################################################
    # Methods to create VHDL field to replace in template

    def get_vhdl_entity_name(self):
        return self.entity.get_name()

    def get_vhdl_header(self):
        res = "-" * 80 + "\n"
        for line in self.header:
            res += line + "\n"
        res += "-" * 80
        return res

    def get_vhdl_constant(self):
        res = ""
        if len(self.constant) == 0:
            return res
        for line in self.constant[:-1]:
            res += ident(4, line + ";\n")
        res += ident(4, self.constant[-1] + ";")
        return res

    def get_vhdl_generic(self):
        res = ""
        if len(self.generic) == 0:
            return res
        res += ident(8, "generic (\n")
        for line in self.generic[:-1]:
            res += ident(12, line + ";\n")
        res += ident(12, self.generic[-1] + "\n")
        res += ident(8, ");")
        return res

    def get_vhdl_port(self):
        res = ""
        if len(self.port) == 0:
            return res
        res += ident(8, "port (\n")
        for line in self.port[:-1]:
            res += ident(12, line + ";\n")
        res += ident(12, self.port[-1] + "\n")
        res += ident(8, ");")
        return res

    def get_vhdl_signal(self):
        res = ""
        if len(self.signal) == 0:
            return res
        for line in self.signal:
            res += ident(4, line + ";\n")
        return res

    def get_vhdl_generic_map(self):
        res = ""
        if len(self.generic_map) == 0:
            return res
        res += ident(4, "generic map (\n")
        for line in self.generic_map[:-1]:
            res += ident(8, line + ",\n")
        res += ident(8, self.generic_map[-1] + "\n")
        res += ident(4, ")")
        return res

    def get_vhdl_port_map(self):
        res = ""
        if len(self.port_map) == 0:
            return res
        res += ident(4, "port map (\n")
        for line in self.port_map[:-1]:
            res += ident(8, line + ",\n")
        res += ident(8, self.port_map[-1] + "\n")
        res += ident(4, ");")
        return res

    def get_vhdl_func_param(self):
        res = ""
        if len(self.func_param) == 0:
            return res
        for line in self.func_param[:-1]:
            res += ident(8, line + ";\n")
        res += ident(8, self.func_param[-1])
        return res

    def get_vhdl_func_var(self):
        res = ""
        if len(self.func_var) == 0:
            return res
        for line in self.func_var:
            res += ident(8, line + ";\n")
        return res

    def get_vhdl_drive(self):
        res = ""
        if len(self.drive) == 0:
            return res
        for line in self.drive:
            res += ident(8, line + "\n")
        return res

    def get_vhdl_compare(self):
        res = ""
        if len(self.compare) == 0:
            return res
        for line in self.compare:
            res += ident(8, line + "\n")
        return res

    def get_vhdl_action(self):
        res = ""
        if len(self.action) == 0:
            return res
        for line in self.action:
            res += ident(8, line + "\n")
        return res

    ###########################################################################
    # Generate testbench file
    def generate(self):
        # Create working folder and ignore error if it already exist
        folder = cwd + "/work/" + self.dp.id + "/"
        try:
            os.makedirs(folder)
        except OSError as e:
            if e.errno != errno.EEXIST:
                raise

        self.dp.generate_vhdl_pkg()

        # pre-compute all strings
        cache = {}
        cache[ "%HEADER%"      ] = self.get_vhdl_header()
        cache[ "%ENTITY_NAME%" ] = self.get_vhdl_entity_name()
        cache[ "%CONSTANT%"    ] = self.get_vhdl_constant()
        cache[ "%GENERIC%"     ] = self.get_vhdl_generic()
        cache[ "%PORT%"        ] = self.get_vhdl_port()
        cache[ "%SIGNAL%"      ] = self.get_vhdl_signal()
        cache[ "%GENERIC_MAP%" ] = self.get_vhdl_generic_map()
        cache[ "%PORT_MAP%"    ] = self.get_vhdl_port_map()
        cache[ "%FUNC_PARAM%"  ] = self.get_vhdl_func_param()
        cache[ "%FUNC_VAR%"    ] = self.get_vhdl_func_var()
        cache[ "%DRIVE%"       ] = self.get_vhdl_drive()
        cache[ "%COMPARE%"     ] = self.get_vhdl_compare()
        cache[ "%ACTIONS%"     ] = self.get_vhdl_action()

        # Create file from template and replace needed fields
        filename = folder + self.get_vhdl_entity_name() + "_tb.vhd"
        new_file = open( filename, 'w' )
        for line in fileinput.input( "./script/templates/tb_alu_it_vhdl.template" ):
            for key, value in cache.iteritems():
                line = line.replace( key, value )
            new_file.write( line )
        new_file.close()
        fileinput.close()
        print "  Created: " + filename

    def do_simulation(self):
        cmd_line =  []
        cmd_line += [ "vivado" ]
        cmd_line += [ "-mode", "batch" ]
        cmd_line += [ "-source", "./script/run.tcl" ]
        cmd_line += [ "-notrace" ]
        cmd_line += [ "-tclargs" ]
        # tcl script arguments
        cmd_line += [ self.dp.id ]
        cmd_line += [ self.entity.id ]
        srcs = self.entity.get_src_with_dep(self.dp)
        print "  Sources:"
        for src in srcs:
            print "    " + src
        cmd_line += srcs
        try:
            retcode = call(cmd_line)
            if retcode < 0:
                print >>sys.stderr, "Vivado was terminated by signal", -retcode
            else:
                print >>sys.stderr, "Vivado returned", retcode
        except OSError as e:
            print >>sys.stderr, "Execution failed:", e
            print >>sys.stderr, "Check that vivado binary is in path"

# Load testbenches class extention, in right order
pattern = '*_TB_*.py'
path = cwd + "/testbenches/"
libs = []
for root, dirs, files in os.walk(path):
    for name in files:
        if fnmatch.fnmatch(name, pattern):
            libs.append(name)
for lib in sorted(libs):
    load(cwd + "/testbenches/" + lib)
