class TestBench_miller(TB_aluEC_prime_ext):

    def add_miller(self, P, Q, n, t):
        self.add_action( "func(" + self.dp.ec2_point_to_vhdl_string(P)   + ",  -- P" )
        self.add_action( "     " + self.dp.ec2_point_to_vhdl_string(Q)   + ",  -- Q" )
        self.add_action( "     " + self.dp.Fp_element_to_vhdl_string(n)  + ",  -- n" )
        self.add_action( "     " + self.dp.Fpm_element_to_vhdl_string(t) + "); -- t")

    def __init__(self, dp, entity):
        TB_aluEC_prime_ext.__init__(self, dp, entity)
        # Build port
        self.add_port( "ecP:   in  ec2_point" )
        self.add_port( "ecQ:   in  ec2_point" )
        self.add_port( "n:     in  std_logic_vector" )
        self.add_port( "t:     out Fpm_element" )
        # Build signal
        self.add_signal( "signal ecP_sti:   ec2_point := EC2_POINT_I" )
        self.add_signal( "signal ecQ_sti:   ec2_point := EC2_POINT_I" )
        self.add_signal( "signal n_sti:     Fp_element := (others=>'0')" )
        self.add_signal( "signal t_obs:     Fpm_element := c_FPM_ZERO" )
        # Build port map
        self.add_port_map( "ecP   => ecP_sti" )
        self.add_port_map( "ecQ   => ecQ_sti" )
        self.add_port_map( "n     => n_sti" )
        self.add_port_map( "t     => t_obs" )
        # Build signal driving
        self.add_drive( "ecP_sti <= ecP;" )
        self.add_drive( "ecQ_sti <= ecQ;" )
        self.add_drive( "n_sti   <= n;" )
        # Build function parameters
        self.add_func_param( "ecP : ec2_point" )
        self.add_func_param( "ecQ : ec2_point" )
        self.add_func_param( "n   : std_logic_vector" )
        self.add_func_param( "t   : Fpm_element" )
        # Build compare
        self.add_compare( "if (t_obs /= t) then" )
        self.add_compare( "    logger.log_error( LF &" )
        self.add_compare( "        \"Error: transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"P        : \" & to_string(ecP_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"Q        : \" & to_string(ecQ_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"n        : \" & to_hstring(n_sti)  & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(t_obs)   & \"<BR>\" & LF &" )
        self.add_compare( "        \"should be: \" & to_string(t) & \"<BR>\" & LF &" )
        self.add_compare( "        \"took \" & integer'image(cycle) & \" cycles\"")
        self.add_compare( "    );" )
        self.add_compare( "else" )
        self.add_compare( "   logger.log_note( LF &" )
        self.add_compare( "       \"Transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "       \"P     : \" & to_string(ecP_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"Q     : \" & to_string(ecQ_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"n     : \" & to_hstring(n_sti)  & \"<BR>\" & LF &" )
        self.add_compare( "       \"yield : \" & to_string(t_obs) & \"<BR>\" & LF &" )
        self.add_compare( "       \"took \" & integer'image(cycle) & \" cycles\"" )
        self.add_compare( "   );" )
        self.add_compare( "end if;" )

        op_count = 10
        self.add_action( "-- Testbench actions" )
        self.add_action( "" )

        self.add_action( "-- " + str(op_count) + " miller alg (" + str(dp.p.nbits())  + " bits elements)" )
        for i in range(op_count):
            P = dp.E2.gen(0)
            Q = 10 * dp.E2.gen(1)
            # FIXME this will take some time with big groups..
            n = P.order()
            t = P._miller_(Q, n)
            self.add_miller(P, Q, n, t)
        self.add_action( "" )
        self.add_action( "-- Testbench actions end" )

class Miller(Entity):
    def __init__(self, dp):
        self.id = "pairing/miller"
        self.src = [ "miller.vhd" ]
        self.dep = [
            "field/fpm_multiplier",
            "field/fpm_divider",
            "ec/efpm_point_inverter",
            "ec/efpm_point_adder_doubler",
            "pairing/miller_line"
        ]

    def is_compatible_with(self, dp):
        if hasattr(dp, 'E2'):
            return True
        else:
            return False

    def get_default_tb(self, dp):
        return TestBench_miller(dp, self)

obj = Miller(dp)
