import os, errno, fnmatch
import os.path
import sys
import fileinput
import datetime
from sage.all import *

class Domain_param:

    def Fp_element_to_vhdl_string(self,elem):
        elem_str = ""
        elem_str += str(self.p.nbits()) + "x\"" + Integer(elem).str(base=16) + "\""
        return  elem_str

    def Fpm_element_to_vhdl_string(self,elem):
        coeff_list = elem.polynomial().list()
        len_list = len(coeff_list)
        coeff_count = self.m
        elem_str = "( "
        for i in reversed(range(coeff_count)):
            if i < len_list:
                elem_str += str(self.p.nbits()) + "x\"" + Integer(coeff_list[i]).str(base=16) + "\""
            else:
                elem_str += str(self.p.nbits()) + "x\"" + Integer(0).str(base=16) + "\""
            if i > 0:
                elem_str += ", "
        elem_str += " )"
        return elem_str

    def Fpm_element_long_to_vhdl_string(self,poly):
        coeff_list = poly.list()
        len_list = len(coeff_list)
        coeff_count = self.m + 1
        assert(len_list > 0)
        poly_str = "( "
        for i in reversed(range(coeff_count)):
            if i < len_list:
                poly_str += str(self.p.nbits()) + "x\"" + Integer(coeff_list[i]).str(base=16) + "\""
            else:
                poly_str += str(self.p.nbits()) + "x\"" + Integer(0).str(base=16) + "\""
            if i > 0:
                poly_str += ", "
        poly_str += " )"
        return poly_str

    def ec1_point_to_vhdl_string(self, P):
        if P != 0:
            (Px, Py) = P.xy()
            Pii = "0"
        else:
            (Px, Py) = (self.Fp(0), self.Fp(0))
            Pii = "1"
        ec_point_str =  "( x => " + self.Fp_element_to_vhdl_string(Px) + ","
        ec_point_str +=  " y => " + self.Fp_element_to_vhdl_string(Py) + ","
        ec_point_str +=  " ii => \'" + Pii + "\' )"
        return ec_point_str

    def compr_ec1_point_to_vhdl_string(self,elem):
        elem_str = ""
        elem_str += str(self.p.nbits()+1) + "x\"" + Integer(elem).str(base=16) + "\""
        return  elem_str

    def ec2_point_to_vhdl_string(self, P):
        if P != 0:
            (Px, Py) = P.xy()
            Pii = "0"
        else:
            (Px, Py) = (self.Fp(0), self.Fp(0))
            Pii = "1"
        ec_point_str =  "( x => " + self.Fpm_element_to_vhdl_string(Px) + ","
        ec_point_str +=  " y => " + self.Fpm_element_to_vhdl_string(Py) + ","
        ec_point_str +=  " ii => \'" + Pii + "\' )"
        return ec_point_str

    def factory(domain_param_id):
        # Check if domain param exists and set name
        # FIXME object for config such as cwd? should not access global like this
        domain_class_file = cwd + "/domain_params/" + domain_param_id + ".sage"
        if not os.path.isfile(domain_class_file):
            raise AssertionError("Domain param class file not found:" + domain_class_file)
        # Create object 'obj'
        load(domain_class_file)
        try:
            if (domain_param_id != obj.id):
                #raise AssertionError("incorrect object created: " + str(obj.__class__.__name__))
                print "Domain param disabled or not correct: " + domain_param_id
                return None
        except (NameError, AttributeError):
            print "Domain param disabled or not correct: " + domain_param_id
            return None
        print "  Found " + domain_param_id
        # FIXME move Checks
        if not obj.Fp.is_field():
            raise AssertionError(type + ".K is not a field: " + str(obj.K))
        return obj

    factory = staticmethod(factory)

    def generate_vhdl_pkg(self):
        # Create working folder and ignore error if it already exist
        folder = cwd + "/work/" + self.id + "/"
        try:
            os.makedirs(folder)
        except OSError as e:
            if e.errno != errno.EEXIST:
                raise
        # Create file from template and replace needed fields
        filename = folder + "domain_param_pkg.vhd"
        new_file = open( filename, 'w' )
        for line in fileinput.input( "./script/templates/domain_param_pkg_vhd.template" ):
            line = line.replace( "%HEADER%", "--temp" )
            line = line.replace( "%K%",             str(self.p.nbits()) )
            line = line.replace( "%P%",             str(self.p.nbits()) + "x\"" + Integer(self.p).str(base=16) + "\"")
            line = line.replace( "%M%",             str(self.m) )
            line = line.replace( "%FP_MIN_ONE%",    self.Fp_element_to_vhdl_string( self.Fp(0)-self.Fp(1)) )
            line = line.replace( "%FP_INV_FOUR%",   self.Fp_element_to_vhdl_string( self.Fp(1)/self.Fp(4)) )
            line = line.replace( "%E1_A1%",         self.Fp_element_to_vhdl_string( self.A1) )
            line = line.replace( "%E1_A2%",         self.Fp_element_to_vhdl_string( self.A2) )
            line = line.replace( "%E1_A3%",         self.Fp_element_to_vhdl_string( self.A3) )
            line = line.replace( "%E1_A4%",         self.Fp_element_to_vhdl_string( self.A4) )
            line = line.replace( "%E1_A6%",         self.Fp_element_to_vhdl_string( self.A6) )
            line = line.replace( "%c_C%",           self.Fp_element_to_vhdl_string( self.c ) )
            (gx,gy) = self.g.xy()
            line = line.replace( "%c_E1_G_x%",      self.Fp_element_to_vhdl_string( gx) )
            line = line.replace( "%c_E1_G_y%",      self.Fp_element_to_vhdl_string( gy) )
            line = line.replace( "%c_E1_G_n%",      self.Fp_element_to_vhdl_string( self.n) )
            line = line.replace( "%MTP_EXP%",       self.Fp_element_to_vhdl_string( (2*self.p-1)/3) )
            line = line.replace( "%E2_A1%",         self.Fpm_element_to_vhdl_string( self.A1) )
            line = line.replace( "%E2_A2%",         self.Fpm_element_to_vhdl_string( self.A2) )
            line = line.replace( "%E2_A3%",         self.Fpm_element_to_vhdl_string( self.A3) )
            line = line.replace( "%E2_A4%",         self.Fpm_element_to_vhdl_string( self.A4) )
            line = line.replace( "%E2_A6%",         self.Fpm_element_to_vhdl_string( self.A6) )
            line = line.replace( "%F%",             self.Fpm_element_long_to_vhdl_string( self.Fpm.modulus()) )
            line = line.replace( "%Z%",             self.Fpm_element_to_vhdl_string( self.z) )

            new_file.write( line )
        new_file.close()
        fileinput.close()
        print "  Created: " + filename

    def lst():
        pattern = '*.sage'
        path = cwd + "/domain_params/"
        result = []
        for root, dirs, files in os.walk(path):
            for name in files:
                if fnmatch.fnmatch(name, pattern):
                    result.append(name[:-5])
        return sorted(result)

    lst = staticmethod(lst)

    def print_lst():
        for dp_id in Domain_param.lst():
            print dp_id

    print_lst = staticmethod(print_lst)