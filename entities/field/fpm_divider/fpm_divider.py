class TestBench_fpm_divider(TB_aluXYZ_prime_ext):

    def __init__(self, dp, entity):
        TB_aluXYZ_prime_ext.__init__(self, dp, entity)
        op_count = 10

        self.add_action( "-- Testbench actions" )
        self.add_action( "" )

        self.add_action( "-- Directed test" )
        #G(1) := 1; G(5) := 47; G(9) := 230; G(15) := 117;
        #x = dp.Fpm("117*a^15+230*a^9+47*a^5+1*a^0")
        #print x
        #H(3) := 211; H(9) := 123; H(11) := 7; H(15) := 13;
        #y = dp.Fpm("13*a^15+7*a^11+123*a^9+211*a^3")
        #z = x / y
        #self.add_action( "func(" + dp.Fpm_element_to_vhdl_string(x) + ",  -- x_sti" )
        #self.add_action( "     " + dp.Fpm_element_to_vhdl_string(y) + ",  -- y_sti" )
        #self.add_action( "     " + dp.Fpm_element_to_vhdl_string(z) + "); -- z_ref" )

        #x = dp.Fpm("233*a+29")
        #y = dp.Fpm("49*a+227")
        #z = x / y
        #self.add_action( "func(" + dp.Fpm_element_to_vhdl_string(x) + ",  -- x_sti" )
        #self.add_action( "     " + dp.Fpm_element_to_vhdl_string(y) + ",  -- y_sti" )
        #self.add_action( "     " + dp.Fpm_element_to_vhdl_string(z) + "); -- z_ref" )
        #x = dp.Fpm("a+1")
        #y = dp.Fpm("a")
        #z = x / y
        #self.add_action( "func(" + dp.Fpm_element_to_vhdl_string(x) + ",  -- x_sti" )
        #self.add_action( "     " + dp.Fpm_element_to_vhdl_string(y) + ",  -- y_sti" )
        #self.add_action( "     " + dp.Fpm_element_to_vhdl_string(z) + "); -- z_ref" )
        #self.add_action( "" )
        #x = dp.Fpm("a")
        #y = dp.Fpm("a")
        #z = x / y
        #self.add_action( "func(" + dp.Fpm_element_to_vhdl_string(x) + ",  -- x_sti" )
        #self.add_action( "     " + dp.Fpm_element_to_vhdl_string(y) + ",  -- y_sti" )
        #self.add_action( "     " + dp.Fpm_element_to_vhdl_string(z) + "); -- z_ref" )
        #self.add_action( "" )

        self.add_action( "-- " + str(op_count) + " divisions of random " + str(dp.m) + "x"+ str(dp.p.nbits())  + " bits elements" )
        zero = dp.Fpm(0)
        for i in range(op_count):
            x = dp.Fpm.random_element()
            while True:
                y = dp.Fpm.random_element()
                if y != zero:
                    break
            z = x / y
            self.add_action( "func(" + dp.Fpm_element_to_vhdl_string(x) + ",  -- x_sti" )
            self.add_action( "     " + dp.Fpm_element_to_vhdl_string(y) + ",  -- y_sti" )
            self.add_action( "     " + dp.Fpm_element_to_vhdl_string(z) + "); -- z_ref" )

        self.add_action( "" )
        self.add_action( "-- Testbench actions end" )

class Fpm_divider(Entity):
    def __init__(self, dp):
        self.id = "field/fpm_divider"
        self.src = [ "fpm_divider.vhd" ]
        self.dep = [
            "field/fp_divider",
            "field/fp_multiplier",
            "field/fp_subtractor"
        ]

    def is_compatible_with(self, dp):
        if hasattr(dp, 'Fpm'):
            return True
        else:
            return False

    def get_default_tb(self, dp):
        return TestBench_fpm_divider(dp, self)

obj = Fpm_divider(dp)