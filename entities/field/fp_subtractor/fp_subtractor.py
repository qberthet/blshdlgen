class TestBench_fp_subtractor(TB_aluXYZ_prime):
    def __init__(self, dp, entity):
        TB_aluXYZ_prime.__init__(self, dp, entity)
        op_count = 10
        self.add_action( "-- Testbench actions" )
        self.add_action( "" )
        self.add_action( "-- " + str(op_count) + " subtractions of random " + str(dp.p.nbits())  + " bits elements" )
        for i in range(op_count):
            x = dp.Fp.random_element()
            y = dp.Fp.random_element()
            z = x - y
            self.add_action( "func(" + dp.Fp_element_to_vhdl_string(x) + ",  -- x_sti" )
            self.add_action( "     " + dp.Fp_element_to_vhdl_string(y) + ",  -- y_sti" )
            self.add_action( "     " + dp.Fp_element_to_vhdl_string(z) + "); -- z_ref" )
        self.add_action( "" )
        self.add_action( "-- Testbench actions end" )

class Fp_subtractor(Entity):
    def __init__(self, dp):
        self.id = "field/fp_subtractor"
        self.src = [ "fp_subtractor.vhd" ]

    def is_compatible_with(self, dp):
        if hasattr(dp, 'Fp'):
            return True
        else:
            return False

    def get_default_tb(self, dp):
        return TestBench_fp_subtractor(dp, self)

obj = Fp_subtractor(dp)