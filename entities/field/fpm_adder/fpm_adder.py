class TestBench_fpm_adder(TB_aluXYZ_prime_ext):
    def __init__(self, dp, entity):
        TB_aluXYZ_prime_ext.__init__(self, dp, entity)
        op_count = 10
        self.add_action( "-- Testbench actions" )
        self.add_action( "" )
        self.add_action( "-- " + str(op_count) + " additions of random " + str(dp.m) + "x"+ str(dp.p.nbits())  + " bits elements" )
        for i in range(op_count):
            x = dp.Fpm.random_element()
            y = dp.Fpm.random_element()
            z = x + y
            self.add_action( "func(" + dp.Fpm_element_to_vhdl_string(x) + ",  -- x_sti" )
            self.add_action( "     " + dp.Fpm_element_to_vhdl_string(y) + ",  -- y_sti" )
            self.add_action( "     " + dp.Fpm_element_to_vhdl_string(z) + "); -- z_ref" )

        self.add_action( "" )
        self.add_action( "-- Testbench actions end" )

class Fpm_adder(Entity):
    def __init__(self, dp):
        self.id = "field/fpm_adder"
        self.src = [ "fpm_adder.vhd" ]
        self.dep = [ "field/fp_adder" ]

    def is_compatible_with(self, dp):
        if hasattr(dp, 'Fpm'):
            return True
        else:
            return False

    def get_default_tb(self, dp):
        return TestBench_fpm_adder(dp, self)

obj = Fpm_adder(dp)
