class TestBench_efpm_point_inverter(TB_aluEC_prime_ext):

    def add_invertion(self, P, R):
        self.add_action( "func(" + self.dp.ec2_point_to_vhdl_string(P) +",  -- P" )
        self.add_action( "     " + self.dp.ec2_point_to_vhdl_string(R) +"); -- R" )

    def __init__(self, dp, entity):
        TB_aluEC_prime_ext.__init__(self, dp, entity)
        self.add_port( "ecP:       in  ec2_point" )
        self.add_port( "ecR:       out ec2_point" )
        self.add_signal( "signal ecP_sti:   ec2_point  := EC2_POINT_I" )
        self.add_signal( "signal ecR_obs:   ec2_point  := EC2_POINT_I" )
        self.add_port_map( "ecP      => ecP_sti" )
        self.add_port_map( "ecR      => ecR_obs" )
        self.add_drive( "ecP_sti     <= ecP;" )

        # Build function parameters
        self.add_func_param( "ecP : ec2_point" )
        self.add_func_param( "ecR : ec2_point" )
        # Build compare
        self.add_compare( "if (ecR_obs.ii /= ecR.ii or (ecR.ii = '0' and (ecR_obs.x /= ecR.x or ecR_obs.y /= ecR.y ))) then" )
        self.add_compare( "    logger.log_error( LF &" )
        self.add_compare( "        \"Error: transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"P        : \" & to_string(ecP_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(ecR_obs) & \"<BR>\" & LF &" )
        self.add_compare( "        \"should be: \" & to_string(ecR) & \"<BR>\" & LF &" )
        self.add_compare( "        \"took \" & integer'image(cycle) & \" cycles\"")
        self.add_compare( "    );" )
        self.add_compare( "else" )
        self.add_compare( "   logger.log_note( LF &" )
        self.add_compare( "       \"Transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "       \"P     : \" & to_string(ecP_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"yield : \" & to_string(ecR_obs) & \"<BR>\" & LF &" )
        self.add_compare( "       \"took \" & integer'image(cycle) & \" cycles\"" )
        self.add_compare( "   );" )
        self.add_compare( "end if;" )

        op_count = 10
        self.add_action( "-- Testbench actions" )
        point_at_infinity = dp.E2(0,1,0)
        self.add_action( "" )

        self.add_action( "-- Directed tests" )

        # Infinity check 1
        P = point_at_infinity
        R = -P
        self.add_invertion(P, R)
        self.add_action( "" )

        self.add_action( "-- Random tests" )
        self.add_action( "-- " + str(op_count) + " invertions of random points (" + str(dp.p.nbits())  + " bits elements)" )
        for i in range(op_count):
            P = dp.E2.random_element()
            R = -P
            self.add_invertion(P, R)

        self.add_action( "" )


class Eefpm_point_inverter(Entity):
    def __init__(self, dp):
        self.id = "ec/efpm_point_inverter"
        self.src = [ "efpm_point_inverter.vhd" ]
        self.dep = [
            "field/fpm_subtractor"
            ]

    def is_compatible_with(self, dp):
        if hasattr(dp, 'E2'):
            return True
        else:
            return False

    def get_default_tb(self, dp):
        return TestBench_efpm_point_inverter(dp, self)

obj = Eefpm_point_inverter(dp)
