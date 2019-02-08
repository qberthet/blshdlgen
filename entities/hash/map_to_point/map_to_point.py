import binascii
import random

class TestBench_map_to_point(TB_FIFO):

    def add_map_to_point(self, data_hex_str, P):
        self.add_action( "func(" + data_hex_str +", -- Data to be hashed to point P" )
        self.add_action( "     " + self.dp.ec1_point_to_vhdl_string(P) +" -- P" )
        self.add_action( ");")

    def __init__(self, dp, entity):
        TB_FIFO.__init__(self, dp, entity)
        # Build port
        self.add_port( "clk:       in  std_logic" )
        self.add_port( "reset:     in  std_logic" )
        self.add_port( "src_ready: in  std_logic" )
        self.add_port( "src_read:  out std_logic" )
        self.add_port( "din:       in  std_logic_vector(64-1 downto 0)" )
        self.add_port( "done:      out std_logic" )
        self.add_port( "ecR:       out ec2_point" )
        # Build signal
        self.add_signal( "signal clk_sti:       std_logic := '1'" )
        self.add_signal( "signal rst_sti:       std_logic := '0'" )
        self.add_signal( "signal start_sti:     std_logic := '0'" )
        self.add_signal( "signal done_obs:      std_logic := '1'" )
        self.add_signal( "signal src_ready_sti: std_logic := '1'" )
        self.add_signal( "signal src_read_obs:  std_logic := '0'" )
        self.add_signal( "signal din_sti:       std_logic_vector(63 downto 0) := (others => '0')" )
        self.add_signal( "signal ecR_obs:       ec1_point" )
        # Build port map
        self.add_port_map( "clk       => clk_sti" )
        self.add_port_map( "reset     => rst_sti" )
        self.add_port_map( "src_ready => src_ready_sti" )
        self.add_port_map( "src_read  => src_read_obs" )
        self.add_port_map( "din       => din_sti" )
        self.add_port_map( "done      => done_obs" )
        self.add_port_map( "ecR       => ecR_obs" )
        # Build function local variables
        self.add_func_var( "variable size: integer := 0" )
        self.add_func_var( "variable rem_size: integer := 0" )
        self.add_func_var( "variable header_word: std_logic_vector(63 downto 0)" )
        self.add_func_var( "variable data_word: std_logic_vector(63 downto 0)" )
        # Build signal driving
        self.add_drive( "size := data'length;" )
        self.add_drive( "rem_size := size;" )
        self.add_drive( "" )
        self.add_drive( "-- Prepare header: Data bit length" )
        self.add_drive( "header_word := std_logic_vector(to_unsigned(size, header_word'length));" )
        self.add_drive( "-- Set left-most bit to instruct ip that this is the last block," )
        self.add_drive( "-- multi-block hashing not used in this testbench" )
        self.add_drive( "header_word(63) := '1';" )
        self.add_drive( "" )
        self.add_drive( "while done_obs /= '1' loop" )
        self.add_drive( "   wait until rising_edge(clk_sti);" )
        self.add_drive( "end loop;" )
        self.add_drive( "" )
        self.add_drive( "-- First block: header_word" )
        self.add_drive( "din_sti       <=  header_word;" )
        self.add_drive( "src_ready_sti <= '0';" )
        self.add_drive( "" )
        self.add_drive( "-- Wait that the ip request read" )
        self.add_drive( "wait for C_CLOCK_PERIOD * 1;" )
        self.add_drive( "cycle := cycle + 1;" )
        self.add_drive( "while (src_read_obs /= '1') loop" )
        self.add_drive( "   wait for C_CLOCK_PERIOD * 1;" )
        self.add_drive( "    cycle := cycle + 1;" )
        self.add_drive( "end loop;" )
        self.add_drive( "" )
        self.add_drive( "while (rem_size > 0) loop" )
        self.add_drive( "   if rem_size > 64 then" )
        self.add_drive( "       -- Using \"to\" as unconstrained array default to it" )
        self.add_drive( "        data_word := data( size-rem_size to size-rem_size+63 );" )
        self.add_drive( "    else" )
        self.add_drive( "        data_word := (others=>'0');" )
        self.add_drive( "        data_word(data_word'left downto data_word'left-(rem_size-1)) := data( size-rem_size to data'right);" )
        self.add_drive( "    end if;" )
        self.add_drive( "    rem_size := rem_size - 64;" )
        self.add_drive( "" )
        self.add_drive( "    din_sti       <=  data_word;" )
        self.add_drive( "" )
        self.add_drive( "    wait for C_CLOCK_PERIOD * 1;" )
        self.add_drive( "    cycle := cycle + 1;" )
        self.add_drive( "    while (src_read_obs /= '1') loop" )
        self.add_drive( "        wait for C_CLOCK_PERIOD * 1;" )
        self.add_drive( "        cycle := cycle + 1;" )
        self.add_drive( "    end loop; ")
        self.add_drive( "")
        self.add_drive( "end loop; ")
        self.add_drive( "")
        self.add_drive( "-- Set data bus to 0, not needed but make waveforms easier to read" )
        self.add_drive( "din_sti       <=  x\"0000000000000000\";" )
        self.add_drive( "src_ready_sti <= '1';" )
        # Build function parameters
        self.add_func_param( "data: std_logic_vector" )
        self.add_func_param( "ecR:  ec1_point" )
        # Build compare
        self.add_compare( "if (ecR_obs.ii /= ecR.ii or (ecR.ii = '0' and (ecR_obs.x /= ecR.x or ecR_obs.y /= ecR.y ))) then" )
        self.add_compare( "    logger.log_error( LF &" )
        self.add_compare( "        \"Error: transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"data     : 0x\" & to_hstring(data)   & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(ecR_obs) & \"<BR>\" & LF &" )
        self.add_compare( "        \"should be: \" & to_string(ecR) & \"<BR>\" & LF &" )
        self.add_compare( "        \"took \" & integer'image(cycle) & \" cycles\"")
        self.add_compare( "    );" )
        self.add_compare( "else" )
        self.add_compare( "   logger.log_note( LF &" )
        self.add_compare( "       \"Transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"data     : 0x\" & to_hstring(data)   & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(ecR_obs) & \"<BR>\" & LF &" )
        self.add_compare( "       \"took \" & integer'image(cycle) & \" cycles\"" )
        self.add_compare( "   );" )
        self.add_compare( "end if;" )

        op_count = 10
        self.add_action( "-- Testbench actions" )
        self.add_action( "" )

        self.add_action( "-- Directed tests" )
        self.add_action( "    -- none yet" )

        self.add_action( "-- Random tests" )
        self.add_action( "-- " + str(op_count) + " mapping to point" )
        bls = BLS(self.dp)
        for i in range(op_count):
            data_hex_str = ""
            for j in range(8*(i+1)):
                data_hex_str += '%02x' % random.randint(0, 255)
            message = bytearray.fromhex(data_hex_str)
            P = bls.map_to_point(message)
            vhdl_hex_string = str(64*(i+1)) + "x\"" + data_hex_str + "\""
            self.add_map_to_point( vhdl_hex_string , P)

class Map_to_point(Entity):
    def __init__(self, dp):
        self.id = "hash/map_to_point"
        self.src = [
            "keccak_basic_pad/keccak_pkg.vhd",
            "keccak_basic_pad/sha3_pkg.vhd",
            "keccak_basic_pad/countern.vhd",
            "keccak_basic_pad/piso.vhd",
            "keccak_basic_pad/regn.vhd",
            "keccak_basic_pad/sipo.vhd",
            "keccak_basic_pad/sr_reg.vhd",
            "keccak_basic_pad/keccak_fsm1.vhd",
            "keccak_basic_pad/keccak_fsm2.vhd",
            "keccak_basic_pad/sha3_fsm3.vhd",
            "keccak_basic_pad/keccak_control.vhd",
            "keccak_basic_pad/keccak_bytepad.vhd",
            "keccak_basic_pad/keccak_cons.vhd",
            "keccak_basic_pad/keccak_round.vhd",
            "keccak_basic_pad/keccak_datapath.vhd",
            "keccak_basic_pad/keccak_top.vhd",
            "map_to_point.vhd"
        ]
        self.dep = [
            "field/fp_reducer",
            "field/fp_subtractor",
            "field/fp_multiplier",
            "field/fp_exponentiator",
            "ec/efp_point_multiplier"
        ]

    def is_compatible_with(self, dp):
        # FIXME, check cofactor, etc
        return True

    def get_default_tb(self, dp):
        return TestBench_map_to_point(dp, self)

obj = Map_to_point(dp)