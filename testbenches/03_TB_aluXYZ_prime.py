class TB_aluXYZ_prime(TB_sequential):
    def __init__(self, dp, entity):
        TB_sequential.__init__(self, dp, entity)
        # Build port
        self.add_port( "x:     in  std_logic_vector" )
        self.add_port( "y:     in  std_logic_vector" )
        self.add_port( "z:     out std_logic_vector" )
        # Build signal
        self.add_signal( "signal x_sti:     Fp_element := c_FP_ZERO" )
        self.add_signal( "signal y_sti:     Fp_element := c_FP_ZERO" )
        self.add_signal( "signal z_obs:     Fp_element := c_FP_ZERO" )
        # Build port map
        self.add_port_map( "x     => x_sti" )
        self.add_port_map( "y     => y_sti" )
        self.add_port_map( "z     => z_obs" )
        # Build function parameters
        self.add_func_param( "x : Fp_element" )
        self.add_func_param( "y : Fp_element" )
        self.add_func_param( "z : Fp_element" )
        # Build signal driving
        self.add_drive( "x_sti     <= x;" )
        self.add_drive( "y_sti     <= y;" )
        # Build compare
        self.add_compare( "if (z_obs /= z) then" )
        self.add_compare( "    logger.log_error( LF &" )
        self.add_compare( "        \"Error: transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"x        : \" & to_string(x_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"y        : \" & to_string(y_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(z_obs) & \"<BR>\" & LF &" )
        self.add_compare( "        \"should be: \" & to_string(z) & \"<BR>\" & LF &" )
        self.add_compare( "        \"took \" & integer'image(cycle) & \" cycles\"")
        self.add_compare( "    );" )
        self.add_compare( "else" )
        self.add_compare( "   logger.log_note( LF &" )
        self.add_compare( "       \"Transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "       \"x     : \" & to_string(x_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"y     : \" & to_string(y_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"yield : \" & to_string(z_obs) & \"<BR>\" & LF &" )
        self.add_compare( "       \"took \" & integer'image(cycle) & \" cycles\"" )
        self.add_compare( "   );" )
        self.add_compare( "end if;" )

