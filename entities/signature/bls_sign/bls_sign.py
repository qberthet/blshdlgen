import binascii
import random

class TestBench_bls_sign(TB_FIFO):

    def add_signature(self, skey, data_hex_str, signature):
        self.add_action( "func(" + self.dp.Fp_element_to_vhdl_string(skey) +", -- Secret key" )
        self.add_action( "     " + data_hex_str +", -- Data to be signed" )
        self.add_action( "     " + self.dp.compr_ec1_point_to_vhdl_string(signature) +" -- signature" )
        self.add_action( ");")

    def __init__(self, dp, entity):
        TB_FIFO.__init__(self, dp, entity)
        # Build port
        self.add_port( "clk:        in  std_logic" )
        self.add_port( "reset:      in  std_logic" )
        self.add_port( "src_ready:  in  std_logic" )
        self.add_port( "src_read:   out std_logic" )
        self.add_port( "skey:       in  Fp_element" )
        self.add_port( "din:        in  std_logic_vector(64-1 downto 0)" )
        self.add_port( "done:       out std_logic" )
        self.add_port( "comp_ecP:   out compr_ec1_point" )
        # Build signal
        self.add_signal( "signal clk_sti:       std_logic := '1'" )
        self.add_signal( "signal rst_sti:       std_logic := '0'" )
        self.add_signal( "signal start_sti:     std_logic := '0'" )
        self.add_signal( "signal done_obs:      std_logic := '1'" )
        self.add_signal( "signal src_ready_sti: std_logic := '1'" )
        self.add_signal( "signal src_read_obs:  std_logic := '0'" )
        self.add_signal( "signal din_sti:       std_logic_vector(63 downto 0) := (others => '0')" )
        self.add_signal( "signal skey_sti:      Fp_element" )
        self.add_signal( "signal comp_ecP_obs:  compr_ec1_point" )
        # Build port map
        self.add_port_map( "clk       => clk_sti" )
        self.add_port_map( "reset     => rst_sti" )
        self.add_port_map( "src_ready => src_ready_sti" )
        self.add_port_map( "src_read  => src_read_obs" )
        self.add_port_map( "skey      => skey_sti" )
        self.add_port_map( "din       => din_sti" )
        self.add_port_map( "done      => done_obs" )
        self.add_port_map( "comp_ecP  => comp_ecP_obs" )
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

        self.add_drive( "-- Set secret key" )
        self.add_drive( "skey_sti <= skey;" )
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
        self.add_func_param( "skey: Fp_element" )
        self.add_func_param( "data: std_logic_vector" )
        self.add_func_param( "comp_ecP:  compr_ec1_point" )
        # Build compare
        self.add_compare( "if (comp_ecP_obs /= comp_ecP) then" )
        self.add_compare( "    logger.log_error( LF &" )
        self.add_compare( "        \"Error: transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"skey     : 0x\" & to_hstring(skey)      & \"<BR>\" & LF &" )
        self.add_compare( "        \"data     : 0x\" & to_hstring(data)      & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(comp_ecP_obs) & \"<BR>\" & LF &" )
        self.add_compare( "        \"should be: \" & to_string(comp_ecP)     & \"<BR>\" & LF &" )
        self.add_compare( "        \"took \" & integer'image(cycle) & \" cycles\"")
        self.add_compare( "    );" )
        self.add_compare( "else" )
        self.add_compare( "   logger.log_note( LF &" )
        self.add_compare( "       \"Transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"skey     : 0x\" & to_hstring(skey)      & \"<BR>\" & LF &" )
        self.add_compare( "        \"data     : 0x\" & to_hstring(data)      & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(comp_ecP_obs) & \"<BR>\" & LF &" )
        self.add_compare( "       \"took \" & integer'image(cycle) & \" cycles\"" )
        self.add_compare( "   );" )
        self.add_compare( "end if;" )

        op_count = 10
        self.add_action( "-- Testbench actions" )
        self.add_action( "" )

        self.add_action( "-- Directed tests" )
        self.add_action( "    -- none yet" )

        self.add_action( "-- Random tests" )
        self.add_action( "-- " + str(op_count) + " signature of random data with random key" )
        # Initialize BLS reference with current domain parameters
        bls = BLS(self.dp)
        for i in range(op_count):
            # Generate a new key for each transaction
            (pk, sk) = bls.key_gen()
            # Generate random data of increasing size
            data_hex_str = ""
            for j in range(8*(i+1)):
                data_hex_str += '%02x' % random.randint(0, 255)
            message = bytearray.fromhex(data_hex_str)
            # Sign data with reference
            signature = bls.sign(sk, message)
            vhdl_hex_string = str(64*(i+1)) + "x\"" + data_hex_str + "\""
            self.add_signature( sk, vhdl_hex_string , signature)

class BLS_sign(Entity):
    def __init__(self, dp):
        self.id = "signature/bls_sign"
        self.src = [ "bls_sign.vhd" ]
        self.dep = [
            "hash/map_to_point",
            "ec/efp_point_multiplier",
            "ec/efp_point_compressor"
        ]

    def is_compatible_with(self, dp):
        # FIXME, check cofactor, etc
        return True

    def get_default_tb(self, dp):
        return TestBench_bls_sign(dp, self)

obj = BLS_sign(dp)