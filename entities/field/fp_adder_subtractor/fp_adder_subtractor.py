class TestBench_fp_adder_subtractor(TB_aluXYZ_prime):

    def add_addition(self, x, y, z):
        self.add_action( "func(" + self.dp.Fp_element_to_vhdl_string(x) +", -- x_sti" )
        self.add_action( "     " + self.dp.Fp_element_to_vhdl_string(y) +", -- y_sti" )
        self.add_action( "     " + self.dp.Fp_element_to_vhdl_string(z) +", -- z_ref" )
        self.add_action( "      '0' ); -- Addition")

    def add_subtraction(self, x, y, z):
        self.add_action( "func(" + self.dp.Fp_element_to_vhdl_string(x) +", -- x_sti" )
        self.add_action( "     " + self.dp.Fp_element_to_vhdl_string(y) +", -- y_sti" )
        self.add_action( "     " + self.dp.Fp_element_to_vhdl_string(z) +", -- z_ref" )
        self.add_action( "      '1' ); -- Subtraction")

    def __init__(self, dp, entity):
        TB_aluXYZ_prime.__init__(self, dp, entity)
        # Build port
        self.add_port( "addn_sub:      in  std_logic" )
        # Build signal
        self.add_signal( "signal addn_sub_sti:  std_logic := '0'" )
        # Build port map
        self.add_port_map( "addn_sub     => addn_sub_sti" )
        # Build signal driving
        self.add_drive( "addn_sub_sti     <= addn_sub;" )
        self.add_func_param( "addn_sub : std_logic" )

        op_count = 10
        self.add_action( "-- Testbench actions" )
        self.add_action( "" )

        self.add_action( "-- " + str(op_count) + " addition of random " + str(dp.m) + "x"+ str(dp.p.nbits())  + " bits elements" )
        for i in range(op_count):
            x = dp.Fp.random_element()
            y = dp.Fp.random_element()
            z = x + y
            self.add_addition(x, y, z)
        self.add_action( "" )

        self.add_action( "-- " + str(op_count) + " subtractions of random " + str(dp.m) + "x"+ str(dp.p.nbits())  + " bits elements" )
        for i in range(op_count):
            x = dp.Fp.random_element()
            y = dp.Fp.random_element()
            z = x - y
            self.add_subtraction(x, y, z)
        self.add_action( "" )
        self.add_action( "-- Testbench actions end" )

class Fp_adder_subtractor(Entity):
    def __init__(self, dp):
        self.id = "field/fp_adder_subtractor"
        self.src = [ "fp_adder_subtractor.vhd" ]

    def is_compatible_with(self, dp):
        if hasattr(dp, 'Fp'):
            return True
        else:
            return False

    def get_default_tb(self, dp):
        return TestBench_fp_adder_subtractor(dp, self)

obj = Fp_adder_subtractor(dp)