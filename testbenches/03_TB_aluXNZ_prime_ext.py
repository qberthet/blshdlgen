class TB_aluXNZ_prime_ext(TB_sequential):
    def __init__(self, dp, entity):
        TB_sequential.__init__(self, dp, entity)
        # Build port
        self.add_port( "x:     in  Fpm_element" )
        self.add_port( "y:     in  std_logic_vector" )
        self.add_port( "z:     out Fpm_element" )
        # Build signal
        self.add_signal( "signal x_sti:     Fpm_element := c_FPM_ZERO" )
        self.add_signal( "signal y_sti:     std_logic_vector (c_N-1 downto 0) := (others=>'0')" )
        self.add_signal( "signal z_obs:     Fpm_element := c_FPM_ZERO" )
        # Build port map
        self.add_port_map( "x     => x_sti" )
        self.add_port_map( "y     => y_sti" )
        self.add_port_map( "z     => z_obs" )
        # Build function parameters
        self.add_func_param( "x : Fpm_element" )
        self.add_func_param( "y : std_logic_vector(c_N-1 downto 0)" )
        self.add_func_param( "z : Fpm_element" )
        # Build signal driving
        self.add_drive( "x_sti     <= x;" )
        self.add_drive( "y_sti     <= y;" )
        # Build compare
        self.add_compare( "if (z_obs /= z) then" )
        self.add_compare( "    logger.log_error( LF &" )
        self.add_compare( "        \"Error: operation on\"            & \"<BR>\" & LF &" )
        self.add_compare( "        \"x        : \" & to_string(x_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"y        : \" & to_hstring(y_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(z_obs) & \"<BR>\" & LF &" )
        self.add_compare( "        \"should be: \" & to_string(z)" )
        self.add_compare( "    );" )
        self.add_compare( "else" )
        self.add_compare( "   logger.log_note( LF &" )
        self.add_compare( "       \"x     : \" & to_string(x_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"y     : \" & to_hstring(y_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"yield : \" & to_string(z_obs)" )
        self.add_compare( "   );" )
        self.add_compare( "end if;" )
