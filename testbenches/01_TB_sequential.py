class TB_sequential(TestBench):
    def __init__(self, dp, entity):
        TestBench.__init__(self, dp, entity)
        # Build port
        self.add_port( "clk:   in  std_logic" )
        self.add_port( "reset: in  std_logic" )
        self.add_port( "start: in  std_logic" )
        self.add_port( "done:  out std_logic" )
        # Build signal
        self.add_signal( "signal clk_sti:   std_logic := '1'" )
        self.add_signal( "signal rst_sti:   std_logic := '0'" )
        self.add_signal( "signal start_sti: std_logic := '0'" )
        self.add_signal( "signal done_obs:  std_logic := '1'" )
        # Build port map
        self.add_port_map( "clk   => clk_sti" )
        self.add_port_map( "reset => rst_sti" )
        self.add_port_map( "start => start_sti" )
        self.add_port_map( "done  => done_obs" )