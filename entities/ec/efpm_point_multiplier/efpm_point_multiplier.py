class TestBench_efpm_point_multiplier(TB_aluEC_prime_ext):

    def add_point_multiplication(self, dp, P, n, R):
        self.add_action( "func(" + dp.ec2_point_to_vhdl_string(P)  + ", -- P" )
        self.add_action( "     " + dp.Fp_element_to_vhdl_string(n) + ", -- n" )
        self.add_action( "     " + dp.ec2_point_to_vhdl_string(R)  + "); -- R" )

    def __init__(self, dp, entity):
        TB_aluEC_prime_ext.__init__(self, dp, entity)
        # Build port
        self.add_port( "ecP:   in  ec2_point" )
        self.add_port( "n:     in  std_logic_vector(c_P'range)" )
        self.add_port( "ecR:   out ec2_point" )
        # Build signal
        self.add_signal( "signal ecP_sti:   ec2_point  := EC2_POINT_I" )
        self.add_signal( "signal n_sti:     std_logic_vector(c_P'range)  := (others =>'0')" )
        self.add_signal( "signal ecR_obs:   ec2_point  := EC2_POINT_I" )
        # Build port map
        self.add_port_map( "ecP      => ecP_sti" )
        self.add_port_map( "n        => n_sti" )
        self.add_port_map( "ecR      => ecR_obs" )
        # Build signal driving
        self.add_drive( "ecP_sti     <= ecP;" )
        self.add_drive( "n_sti       <= n;" )
        # Build function parameters
        self.add_func_param( "ecP : ec2_point" )
        self.add_func_param( "n:    std_logic_vector(c_P'range)" )
        self.add_func_param( "ecR : ec2_point" )
        # Build compare
        self.add_compare( "if (ecR_obs.ii /= ecR.ii or (ecR.ii = '0' and (ecR_obs.x /= ecR.x or ecR_obs.y /= ecR.y ))) then" )
        self.add_compare( "    logger.log_error( LF &" )
        self.add_compare( "        \"Error: transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"P        : \" & to_string(ecP_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"n        : \" & to_string(n_sti)   & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(ecR_obs) & \"<BR>\" & LF &" )
        self.add_compare( "        \"should be: \" & to_string(ecR) & \"<BR>\" & LF &" )
        self.add_compare( "        \"took \" & integer'image(cycle) & \" cycles\"")
        self.add_compare( "    );" )
        self.add_compare( "else" )
        self.add_compare( "   logger.log_note( LF &" )
        self.add_compare( "       \"Transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "       \"P     : \" & to_string(ecP_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"n     :   \" & to_string(n_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"yield : \" & to_string(ecR_obs) & \"<BR>\" & LF &" )
        self.add_compare( "       \"took \" & integer'image(cycle) & \" cycles\"" )
        self.add_compare( "   );" )
        self.add_compare( "end if;" )

        op_count = 10
        self.add_action( "-- Testbench actions" )
        self.add_action( "" )

        self.add_action( "-- Directed tests" )

        # Multiplication by 0
        P = dp.E2.random_element()
        n = Integer(dp.Fp(0))
        R = n * P
        self.add_point_multiplication(dp, P, n, R)
        self.add_action( "" )

        # Multiplication of point at infinity
        P = dp.E2(0,1,0)
        n = randrange(2**(dp.p.nbits())-1)
        R = n * P
        self.add_point_multiplication(dp, P, n, R)
        self.add_action( "" )

        self.add_action( "-- Random tests" )
        self.add_action( "-- " + str(op_count) + " multiplication of random point (" + str(dp.p.nbits())  + " bits elements)" )
        for i in range(op_count):
            P = dp.E2.random_element()
            n = randrange(2**(dp.p.nbits())-1)
            R = n * P
            self.add_point_multiplication(dp, P, n, R)

class Epm_point_multiplier(Entity):
    def __init__(self, dp):
        self.id = "ec/efpm_point_multiplier"
        self.src = [ "efpm_point_multiplier.vhd" ]
        self.dep = [ "ec/efpm_point_adder_doubler" ]

    def is_compatible_with(self, dp):
        if hasattr(dp, 'E2'):
            return True
        else:
            return False

    def get_default_tb(self, dp):
        return TestBench_efpm_point_multiplier(dp, self)

obj = Epm_point_multiplier(dp)