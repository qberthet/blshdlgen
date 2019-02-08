class TestBench_fpm_multiplier(TB_aluXYZ_prime_ext):

    def __init__(self, dp, entity):
        TB_aluXYZ_prime_ext.__init__(self, dp, entity)
        op_count = 10
        self.add_action( "-- Testbench actions" )
        self.add_action( "" )

        #self.add_action( "-- Directed test" )
        #x = dp.Fpm("a+1")
        #y = dp.Fpm("1")
        #z = x * y
        #self.add_action( "func(" + dp.Fpm_element_to_vhdl_string(x) + ",  -- x_sti" )
        #self.add_action( "     " + dp.Fpm_element_to_vhdl_string(y) + ",  -- y_sti" )
        #self.add_action( "     " + dp.Fpm_element_to_vhdl_string(z) + "); -- z_ref" )
        #x = dp.Fpm("a+1")
        #y = dp.Fpm("a")
        #z = x * y
        #self.add_action( "func(" + dp.Fpm_element_to_vhdl_string(x) + ",  -- x_sti" )
        #self.add_action( "     " + dp.Fpm_element_to_vhdl_string(y) + ",  -- y_sti" )
        #self.add_action( "     " + dp.Fpm_element_to_vhdl_string(z) + "); -- z_ref" )
        #self.add_action( "" )
        #x = dp.Fpm("a")
        #y = dp.Fpm("a")
        #z = x * y
        #self.add_action( "func(" + dp.Fpm_element_to_vhdl_string(x) + ",  -- x_sti" )
        #self.add_action( "     " + dp.Fpm_element_to_vhdl_string(y) + ",  -- y_sti" )
        #self.add_action( "     " + dp.Fpm_element_to_vhdl_string(z) + "); -- z_ref" )
        #self.add_action( "" )


        self.add_action( "-- " + str(op_count) + " multiplications of random " + str(dp.m) + "x"+ str(dp.p.nbits())  + " bits elements" )
        for i in range(op_count):
            x = dp.Fpm.random_element()
            y = dp.Fpm.random_element()
            z = x * y
            self.add_action( "func(" + dp.Fpm_element_to_vhdl_string(x) + ",  -- x_sti" )
            self.add_action( "     " + dp.Fpm_element_to_vhdl_string(y) + ",  -- y_sti" )
            self.add_action( "     " + dp.Fpm_element_to_vhdl_string(z) + "); -- z_ref" )

        self.add_action( "" )
        self.add_action( "-- Testbench actions end" )

class Fpm_multiplier(Entity):
    def __init__(self, dp):
        self.id = "field/fpm_multiplier"
        self.src = [ "fpm_multiplier.vhd" ]
        self.dep = [
            "field/fp_reducer",
            "field/fp_subtractor"
        ]

    def is_compatible_with(self, dp):
        if hasattr(dp, 'Fpm'):
            return True
        else:
            return False

    def get_default_tb(self, dp):
        return TestBench_fpm_multiplier(dp, self)

obj = Fpm_multiplier(dp)
