class TestBench_fpm_exponentiator(TB_aluXNZ_prime_ext):
    def __init__(self, dp, entity):
        TB_aluXNZ_prime_ext.__init__(self, dp, entity)
        op_count = 10
        self.add_action( "-- Testbench actions" )
        self.add_action( "" )

        self.add_action( "-- " + str(op_count) + " Exponentiations of random " + str(2*dp.p.nbits())  + " bits elements" )
        for i in range(op_count):
            x = dp.Fpm.random_element()
            # FIXME check size
            y = randrange(2**(dp.p.nbits()*dp.m)-1)
            z = x**y
            self.add_action( "func(" + dp.Fpm_element_to_vhdl_string(x)                    + ",  -- x_sti" )
            self.add_action( "     " + str(dp.p.nbits()*dp.m)+"X\""+Integer(y).str(base=16) + "\",  -- y_sti" )
            self.add_action( "     " + dp.Fpm_element_to_vhdl_string(z)                    + "); -- z_ref" )
        self.add_action( "" )
        self.add_action( "-- Testbench actions end" )

class Fpm_exponentiator(Entity):
    def __init__(self, dp):
        self.id = "field/fpm_exponentiator"
        self.src = [ "fpm_exponentiator.vhd" ]
        self.dep = [ "field/fpm_multiplier" ]

    def is_compatible_with(self, dp):
        if hasattr(dp, 'Fpm'):
            return True
        else:
            return False

    def get_default_tb(self, dp):
        return TestBench_fpm_exponentiator(dp, self)

obj = Fpm_exponentiator(dp)