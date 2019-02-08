class TestBench_efp_point_decompressor(TB_aluEC_prime):

    def compress_point(self, P):
        (x, y) = P.xy()
        if Integer(y) > Integer(dp.p)/2:
            suf = 0b1
        else:
            suf = 0b0
        comprP = (Integer(x) << 1) | suf
        return comprP

    def add_point_decompression(self, compP, P):
        self.add_action( "func(" + self.dp.compr_ec1_point_to_vhdl_string(compP) +", -- compP" )
        self.add_action( "     " + self.dp.ec1_point_to_vhdl_string(P) +"); -- P" )

    def __init__(self, dp, entity):
        TB_aluEC_prime.__init__(self, dp, entity)
        self.add_port( "comp_ecP:  in  compr_ec1_point" )
        self.add_port( "ecP:       out ec1_point" )
        self.add_signal( "signal comp_ecP_sti:       compr_ec1_point := (others=>'0')" )
        self.add_signal( "signal ecP_obs:            ec1_point  := EC1_POINT_I" )
        self.add_port_map( "comp_ecP => comp_ecP_sti" )
        self.add_port_map( "ecP      => ecP_obs" )
        self.add_drive( "comp_ecP_sti     <= comp_ecP;" )

        # Build function parameters
        self.add_func_param( "comp_ecP : compr_ec1_point" )
        self.add_func_param( "ecP      : ec1_point" )
        # Build compare
        self.add_compare( "if (ecP_obs.ii /= ecP.ii or (ecP.ii = '0' and (ecP_obs.x /= ecP.x or ecP_obs.y /= ecP.y ))) then" )
        self.add_compare( "    logger.log_error( LF &" )
        self.add_compare( "        \"Error: transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"compP    : \" & to_string(comp_ecP) & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(ecP_obs) & \"<BR>\" & LF &" )
        self.add_compare( "        \"should be: \" & to_string(ecP) & \"<BR>\" & LF &" )
        self.add_compare( "        \"took \" & integer'image(cycle) & \" cycles\"")
        self.add_compare( "    );" )
        self.add_compare( "else" )
        self.add_compare( "   logger.log_note( LF &" )
        self.add_compare( "       \"Transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "       \"compP : \" & to_string(comp_ecP) & \"<BR>\" & LF &" )
        self.add_compare( "       \"yield : \" & to_string(ecP_obs) & \"<BR>\" & LF &" )
        self.add_compare( "       \"took \" & integer'image(cycle) & \" cycles\"" )
        self.add_compare( "   );" )
        self.add_compare( "end if;" )

        op_count = 10

        self.add_action( "-- Testbench actions" )

        self.add_action( "-- Directed tests" )
        # FIXME add directed test
        self.add_action( "" )

        self.add_action( "-- Random tests" )
        self.add_action( "-- " + str(op_count) + " decompression of random compressed points" )
        for i in range(op_count):
            while True:
                P = dp.E1.random_element()
                if P != 0:
                    break
            comp_P = self.compress_point(P)
            self.add_point_decompression(comp_P, P)

        self.add_action( "" )


class Eefp_point_decompressor(Entity):
    def __init__(self, dp):
        self.id = "ec/efp_point_decompressor"
        self.src = [ "efp_point_decompressor.vhd" ]
        self.dep = [
            "field/fp_adder",
            "field/fp_multiplier",
            "field/fp_square_rooter"
        ]

    def is_compatible_with(self, dp):
        return True

    def get_default_tb(self, dp):
        return TestBench_efp_point_decompressor(dp, self)

obj = Eefp_point_decompressor(dp)
