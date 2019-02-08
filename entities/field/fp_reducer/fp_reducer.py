from sage.misc.prandom import randrange
from sage.misc.randstate import current_randstate

class TestBench_fp_reducer(TB_sequential):
    def __init__(self, dp, entity):
        TB_sequential.__init__(self, dp, entity)
        op_count = 10
        self.add_port( "x:     in  std_logic_vector" )
        self.add_port( "y:     in  std_logic_vector" )
        self.add_port( "z:     out std_logic_vector" )
        # Build signal
        self.add_signal( "signal x_sti:     std_logic_vector(c_N-1 downto 0) := (others=>'0')" )
        self.add_signal( "signal y_sti:     std_logic_vector (c_K-1 downto 0) := (others=>'0')" )
        self.add_signal( "signal z_obs:     Fp_element := c_FP_ZERO" )
        # Build port map
        self.add_port_map( "x     => x_sti" )
        self.add_port_map( "y     => y_sti" )
        self.add_port_map( "z     => z_obs" )
        # Build function parameters
        self.add_func_param( "x : std_logic_vector(c_N-1 downto 0)" )
        self.add_func_param( "y : std_logic_vector(c_K-1 downto 0)" )
        self.add_func_param( "z : Fp_element" )
        # Build signal driving
        self.add_drive( "x_sti     <= x;" )
        self.add_drive( "y_sti     <= y;" )
        # Build compare
        self.add_compare( "if (z_obs /= z) then" )
        self.add_compare( "    logger.log_error( LF &" )
        self.add_compare( "        \"Error: transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"x        : \" & to_hstring(x_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"y        : \" & to_hstring(y_sti) & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(z_obs) & \"<BR>\" & LF &" )
        self.add_compare( "        \"should be: \" & to_string(z) & \"<BR>\" & LF &" )
        self.add_compare( "        \"took \" & integer'image(cycle) & \" cycles\"")
        self.add_compare( "    );" )
        self.add_compare( "else" )
        self.add_compare( "   logger.log_note( LF &" )
        self.add_compare( "       \"Transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "       \"x     : \" & to_hstring(x_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"y     : \" & to_hstring(y_sti) & \"<BR>\" & LF &" )
        self.add_compare( "       \"yield : \" & to_string(z_obs) & \"<BR>\" & LF &" )
        self.add_compare( "       \"took \" & integer'image(cycle) & \" cycles\"" )
        self.add_compare( "   );" )
        self.add_compare( "end if;" )

        self.add_action( "-- Testbench actions" )
        self.add_action( "" )
        self.add_action( "-- " + str(op_count) + " reduction of random " + str(2*dp.p.nbits())  + " bits elements" )
        for i in range(op_count):
            x = randrange(2**(2*dp.p.nbits())-1)
            z = mod(x,dp.p)
            self.add_action( "func(" + str(2*dp.p.nbits()) + "X\"" + Integer(x).str(base=16)    + "\",  -- x_sti" )
            self.add_action( "     " + str(dp.p.nbits())   + "X\"" + Integer(dp.p).str(base=16) + "\",  -- y_sti (modulus)" )
            self.add_action( "     " + str(dp.p.nbits())   + "X\"" + Integer(z).str(base=16)    + "\"); -- z_ref" )
        self.add_action( "" )
        self.add_action( "-- Testbench actions end" )

class Fp_reducer(Entity):
    def __init__(self, dp):
        self.id = "field/fp_reducer"
        self.src = [ "fp_reducer.vhd" ]

    def is_compatible_with(self, dp):
        if hasattr(dp, 'Fp'):
            return True
        else:
            return False

    def get_default_tb(self, dp):
        return TestBench_fp_reducer(dp, self)

obj = Fp_reducer(dp)