class TestBench_efpm_point_adder_doubler(TB_aluEC_prime_ext):

    def add_addition(self, P, Q, R):
        self.add_action( "func(" + self.dp.ec2_point_to_vhdl_string(P) +", -- P" )
        self.add_action( "     " + self.dp.ec2_point_to_vhdl_string(Q) +", -- Q" )
        self.add_action( "     " + self.dp.ec2_point_to_vhdl_string(R) +", -- R" )
        self.add_action( "      '0' ); -- Addition")

    def add_doubling(self, P, Q, R):
        self.add_action( "func(" + self.dp.ec2_point_to_vhdl_string(P) +", -- P" )
        self.add_action( "     " + self.dp.ec2_point_to_vhdl_string(Q) +", -- Q (unused in doubling)" )
        self.add_action( "     " + self.dp.ec2_point_to_vhdl_string(R) +", -- R" )
        self.add_action( "      '1' ); -- Doubling")

    def __init__(self, dp, entity):
        TB_aluEC_prime_ext.__init__(self, dp, entity)
        self.add_port( "ecP:       in  ec2_point" )
        self.add_port( "ecQ:       in  ec2_point" )
        self.add_port( "ecR:       out ec2_point" )
        self.add_port( "an_d:      in  std_logic" )
        self.add_signal( "signal ecP_sti:   ec2_point  := EC2_POINT_I" )
        self.add_signal( "signal ecQ_sti:   ec2_point  := EC2_POINT_I" )
        self.add_signal( "signal ecR_obs:   ec2_point  := EC2_POINT_I" )
        self.add_signal( "signal an_d_sti:  std_logic := '0'" )
        self.add_port_map( "ecP      => ecP_sti" )
        self.add_port_map( "ecQ      => ecQ_sti" )
        self.add_port_map( "ecR      => ecR_obs" )
        self.add_port_map( "an_d     => an_d_sti" )
        self.add_drive( "ecP_sti     <= ecP;" )
        self.add_drive( "ecQ_sti     <= ecQ;" )
        self.add_drive( "an_d_sti    <= an_d;" )

        # Build function parameters
        self.add_func_param( "ecP : ec2_point" )
        self.add_func_param( "ecQ : ec2_point" )
        self.add_func_param( "ecR : ec2_point" )
        self.add_func_param( "an_d : std_logic" )
        # Build compare
        self.add_compare( "if (ecR_obs.ii /= ecR.ii or (ecR.ii = '0' and (ecR_obs.x /= ecR.x or ecR_obs.y /= ecR.y ))) then" )
        self.add_compare( "    logger.log_error( LF &" )
        self.add_compare( "        \"Error: transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"P        : \" & to_string(ecP_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"Q        : \" & to_string(ecQ_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(ecR_obs) & \"<BR>\" & LF &" )
        self.add_compare( "        \"should be: \" & to_string(ecR) & \"<BR>\" & LF &" )
        self.add_compare( "        \"took \" & integer'image(cycle) & \" cycles\"")
        self.add_compare( "    );" )
        self.add_compare( "else" )
        self.add_compare( "   logger.log_note( LF &" )
        self.add_compare( "       \"Transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "       \"P     : \" & to_string(ecP_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"Q     : \" & to_string(ecQ_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"yield : \" & to_string(ecR_obs) & \"<BR>\" & LF &" )
        self.add_compare( "       \"took \" & integer'image(cycle) & \" cycles\"" )
        self.add_compare( "   );" )
        self.add_compare( "end if;" )

        op_count = 10
        self.add_action( "-- Testbench actions" )
        point_at_infinity = dp.E2(0,1,0)
        self.add_action( "" )

        self.add_action( "-- Directed tests" )

        # Simple adding
        P = dp.E2.random_element()
        Q = dp.E2.random_element()
        R = P + Q
        self.add_addition(P, Q, R)

        # Simple forced doubling
        P = dp.E2.random_element()
        R = P + P
        self.add_addition(P, P, R)

        # Infinity check 1
        P = dp.E2.random_element()
        Q = point_at_infinity
        R = P + Q
        self.add_addition(P, Q, R)

        # Infinity check 2
        P = point_at_infinity
        Q = dp.E2.random_element()
        R = P + Q
        self.add_addition(P, Q, R)

        # Infinity check 3
        P = point_at_infinity
        Q = point_at_infinity
        R = P + Q
        self.add_addition(P, Q, R)

        self.add_action( "" )

        self.add_action( "-- Random tests" )
        self.add_action( "-- " + str(op_count) + " additions of random points (" + str(dp.p.nbits())  + " bits elements)" )
        for i in range(op_count):
            P = dp.E2.random_element()
            Q = dp.E2.random_element()
            R = P + Q
            self.add_addition(P, Q, R)

        self.add_action( "" )

        ## Random doubling
        self.add_action( "-- " + str(op_count) + " doublings of random points (" + str(dp.p.nbits())  + " bits elements)" )
        for i in range(op_count):
            P = dp.E2.random_element()
            Q = dp.E2.random_element()
            R = 2 * P
            self.add_doubling(P, Q, R)

class Efpm_point_adder_doubler(Entity):
    def __init__(self, dp):
        self.id = "ec/efpm_point_adder_doubler"
        self.src = [ "efpm_point_adder_doubler.vhd" ]
        self.dep = [
            "field/fpm_adder_subtractor",
            "field/fpm_multiplier",
            "field/fpm_divider"
            ]

    def is_compatible_with(self, dp):
        if hasattr(dp, 'E2'):
            return True
        else:
            return False

    def get_default_tb(self, dp):
        return TestBench_efpm_point_adder_doubler(dp, self)

obj = Efpm_point_adder_doubler(dp)
