class TestBench_fp_square_rooter(TB_sequential):
    def __init__(self, dp, entity):
        TB_sequential.__init__(self, dp, entity)
        # Build port
        self.add_port( "x:     in  std_logic_vector" )
        self.add_port( "z1:    out std_logic_vector" )
        self.add_port( "z2:    out std_logic_vector" )
        # Build signal
        self.add_signal( "signal x_sti:     Fp_element := c_FP_ZERO" )
        self.add_signal( "signal z1_obs:    Fp_element := c_FP_ZERO" )
        self.add_signal( "signal z2_obs:    Fp_element := c_FP_ZERO" )
        # Build port map
        self.add_port_map( "x     => x_sti" )
        self.add_port_map( "z1    => z1_obs" )
        self.add_port_map( "z2    => z2_obs" )
        # Build function parameters
        self.add_func_param( "x:  Fp_element" )
        self.add_func_param( "z1: Fp_element" )
        self.add_func_param( "z2: Fp_element" )
        # Build signal driving
        self.add_drive( "x_sti     <= x;" )
        # Build compare
        self.add_compare( "if ((z1_obs /= z1) and (z2_obs /= z2)) and ((z1_obs /= z2) and (z2_obs /= z1)) then" )
        self.add_compare( "    logger.log_error( LF &" )
        self.add_compare( "        \"Error: transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"x        : \" & to_string(x_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(z1_obs) & \" and \" & to_string(z2_obs) & \"<BR>\" & LF &" )
        self.add_compare( "        \"should be: \" & to_string(z1) & \" and \" & to_string(z2) & \"<BR>\" & LF &" )
        self.add_compare( "        \"took \" & integer'image(cycle) & \" cycles\"")
        self.add_compare( "    );" )
        self.add_compare( "else" )
        self.add_compare( "   logger.log_note( LF &" )
        self.add_compare( "       \"Transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "       \"x     : \" & to_string(x_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"yield : \" & to_string(z1_obs) & \" and \" & to_string(z2_obs) & \"<BR>\" & LF &" )
        self.add_compare( "       \"took \" & integer'image(cycle) & \" cycles\"" )
        self.add_compare( "   );" )
        self.add_compare( "end if;" )

        op_count = 10
        self.add_action( "-- Testbench actions" )
        self.add_action( "" )
        self.add_action( "-- " + str(op_count) + " Square root of random " + str(dp.p.nbits())  + " bits elements" )
        for i in range(op_count):
            z1 = dp.Fp.random_element()
            z2 = -z1
            x = z1 ** 2
            self.add_action( "func(" + dp.Fp_element_to_vhdl_string(x)  + ",  -- x_sti" )
            self.add_action( "     " + dp.Fp_element_to_vhdl_string(z1) + ",  -- z1_sti" )
            self.add_action( "     " + dp.Fp_element_to_vhdl_string(z2) + "); -- z2_ref" )
        self.add_action( "" )
        self.add_action( "-- Testbench actions end" )

class Fp_square_rooter(Entity):
    def __init__(self, dp):
        self.id = "field/fp_square_rooter"
        self.src = [ "fp_square_rooter.vhd" ]
        self.dep = [
            "field/fp_exponentiator",
            "field/fp_subtractor"
        ]

    def is_compatible_with(self, dp):
        if hasattr(dp, 'p'):
            if dp.p % 4 == 3 and dp.p % 3 == 2:
                return True
        return False

    def get_default_tb(self, dp):
        return TestBench_fp_square_rooter(dp, self)

obj = Fp_square_rooter(dp)