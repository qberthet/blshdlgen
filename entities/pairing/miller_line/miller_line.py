class TestBench_miller_line(TB_aluEC_prime_ext):

    def add_miller_line(self, P, Q, R, l):
        self.add_action( "func(" + self.dp.ec2_point_to_vhdl_string(P)  + ",  -- P" )
        self.add_action( "     " + self.dp.ec2_point_to_vhdl_string(Q)  + ",  -- R" )
        self.add_action( "     " + self.dp.ec2_point_to_vhdl_string(R)  + ",  -- Q" )
        self.add_action( "     " + self.dp.Fpm_element_to_vhdl_string(l) + "); -- l")

    def __init__(self, dp, entity):
        TB_aluEC_prime_ext.__init__(self, dp, entity)
        # Build port
        self.add_port( "ecP:   in  ec2_point" )
        self.add_port( "ecR:   in  ec2_point" )
        self.add_port( "ecQ:   in  ec2_point" )
        self.add_port( "l:     out Fpm_element" )
        # Build signal
        self.add_signal( "signal ecP_sti:   ec2_point := EC2_POINT_I" )
        self.add_signal( "signal ecR_sti:   ec2_point := EC2_POINT_I" )
        self.add_signal( "signal ecQ_sti:   ec2_point := EC2_POINT_I" )
        self.add_signal( "signal l_obs:     Fpm_element := c_FPM_ZERO" )
        # Build port map
        self.add_port_map( "ecP   => ecP_sti" )
        self.add_port_map( "ecR   => ecR_sti" )
        self.add_port_map( "ecQ   => ecQ_sti" )
        self.add_port_map( "l     => l_obs" )
        # Build signal driving
        self.add_drive( "ecP_sti <= ecP;" )
        self.add_drive( "ecR_sti <= ecR;" )
        self.add_drive( "ecQ_sti <= ecQ;" )
        # Build function parameters
        self.add_func_param( "ecP : ec2_point" )
        self.add_func_param( "ecR : ec2_point" )
        self.add_func_param( "ecQ : ec2_point" )
        self.add_func_param( "l   : Fpm_element" )
        # Build compare
        self.add_compare( "if (l_obs /= l) then" )
        self.add_compare( "    logger.log_error( LF &" )
        self.add_compare( "        \"Error: transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"P        : \" & to_string(ecP_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"R        : \" & to_string(ecR_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"Q        : \" & to_string(ecQ_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(l_obs) & \"<BR>\" & LF &" )
        self.add_compare( "        \"should be: \" & to_string(l) & \"<BR>\" & LF &" )
        self.add_compare( "        \"took \" & integer'image(cycle) & \" cycles\"")
        self.add_compare( "    );" )
        self.add_compare( "else" )
        self.add_compare( "   logger.log_note( LF &" )
        self.add_compare( "       \"Transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "       \"P     : \" & to_string(ecP_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"R     : \" & to_string(ecR_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"Q     : \" & to_string(ecQ_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"yield : \" & to_string(l_obs) & \"<BR>\" & LF &" )
        self.add_compare( "       \"took \" & integer'image(cycle) & \" cycles\"" )
        self.add_compare( "   );" )
        self.add_compare( "end if;" )

        op_count = 10
        self.add_action( "-- Testbench actions" )
        self.add_action( "" )

        self.add_action( "-- Directed tests" )
        self.add_action( "" )

        self.add_action( "-- Directed tests" )

        P = dp.E2(0)
        R = dp.E2(0)
        Q = dp.E2.random_element()
        l = P._line_(R, Q)
        self.add_miller_line(P, R, Q, l)
        self.add_action( "" )

        P = dp.E2.random_element()
        R = dp.E2(0)
        Q = dp.E2.random_element()
        l = P._line_(R, Q)
        self.add_miller_line(P, R, Q, l)
        self.add_action( "" )

        P = dp.E2(0)
        R = dp.E2.random_element()
        Q = dp.E2.random_element()
        l = P._line_(R, Q)
        self.add_miller_line(P, R, Q, l)
        self.add_action( "" )

        self.add_action( "-- " + str(op_count) + " miller_line on random point (" + str(dp.p.nbits())  + " bits elements)" )
        for i in range(op_count):
            P = dp.E2.random_element()
            R = dp.E2.random_element()
            Q = dp.E2.random_element()
            l = P._line_(R, Q)
            self.add_miller_line(P, R, Q, l)
        self.add_action( "" )

        self.add_action( "-- " + str(op_count) + " miller_line on random point with R == P (" + str(dp.p.nbits())  + " bits elements)" )
        for i in range(op_count):
            P = dp.E2.random_element()
            R = P
            Q = dp.E2.random_element()
            l = P._line_(R, Q)
            self.add_miller_line(P, R, Q, l)
        self.add_action( "" )
        self.add_action( "-- Testbench actions end" )

class Miller_line(Entity):
    def __init__(self, dp):
        self.id = "pairing/miller_line"
        self.tb = TestBench_miller_line(dp, self)
        self.src = [ "miller_line.vhd" ]
        self.dep = [
            "field/fpm_divider",
            "field/fpm_multiplier",
            "field/fpm_adder_subtractor"
        ]

    def is_compatible_with(self, dp):
        if hasattr(dp, 'E2'):
            return True
        else:
            return False

    def get_default_tb(self, dp):
        return TestBench_miller_line(dp, self)

obj = Miller_line(dp)
