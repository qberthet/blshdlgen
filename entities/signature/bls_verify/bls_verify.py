import binascii
import random

class TestBench_bls_verify(TB_FIFO):

    def add_verification(self, pkey, data_hex_str, signature, valid):
        self.add_action( "func(" + self.dp.compr_ec1_point_to_vhdl_string(pkey) +", -- public key" )
        self.add_action( "     " + self.dp.compr_ec1_point_to_vhdl_string(signature) +", -- signature" )
        self.add_action( "     " + data_hex_str + ", -- Data to be signed" )
        self.add_action( "     '" + str(valid) + "' -- valid" )
        self.add_action( ");")

    def __init__(self, dp, entity):
        TB_FIFO.__init__(self, dp, entity)
        # Build port
        self.add_port( "clk:        in  std_logic" )
        self.add_port( "reset:      in  std_logic" )
        self.add_port( "src_ready:  in  std_logic" )
        self.add_port( "src_read:   out std_logic" )
        self.add_port( "signature:  in  compr_ec1_point" )
        self.add_port( "pkey:       in  compr_ec1_point" )
        self.add_port( "din:        in  std_logic_vector(64-1 downto 0)" )
        self.add_port( "done:       out std_logic" )
        self.add_port( "sign_valid: out std_logic" )
        # Build signal
        self.add_signal( "signal clk_sti:        std_logic := '1'" )
        self.add_signal( "signal rst_sti:        std_logic := '0'" )
        self.add_signal( "signal start_sti:      std_logic := '0'" )
        self.add_signal( "signal done_obs:       std_logic := '1'" )
        self.add_signal( "signal src_ready_sti:  std_logic := '1'" )
        self.add_signal( "signal src_read_obs:   std_logic := '0'" )
        self.add_signal( "signal din_sti:        std_logic_vector(63 downto 0) := (others => '0')" )
        self.add_signal( "signal signature_sti:  compr_ec1_point" )
        self.add_signal( "signal pkey_sti:       compr_ec1_point" )
        self.add_signal( "signal sign_valid_obs: std_logic := '0'" )
        # Build port map
        self.add_port_map( "clk        => clk_sti" )
        self.add_port_map( "reset      => rst_sti" )
        self.add_port_map( "src_ready  => src_ready_sti" )
        self.add_port_map( "src_read   => src_read_obs" )
        self.add_port_map( "signature  => signature_sti" )
        self.add_port_map( "pkey       => pkey_sti" )
        self.add_port_map( "din        => din_sti" )
        self.add_port_map( "done       => done_obs" )
        self.add_port_map( "sign_valid => sign_valid_obs" )
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
        self.add_drive( "-- Set public key and signature" )
        self.add_drive( "signature_sti <= signature;" )
        self.add_drive( "pkey_sti <= pkey;" )
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
        self.add_func_param( "pkey: compr_ec1_point" )
        self.add_func_param( "signature: compr_ec1_point" )
        self.add_func_param( "data: std_logic_vector" )
        self.add_func_param( "sign_valid:  std_logic" )
        # Build compare
        self.add_compare( "if (sign_valid_obs /= sign_valid) then" )
        self.add_compare( "    logger.log_error( LF &" )
        self.add_compare( "        \"Error: transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"pkey     : 0x\" & to_hstring(pkey)              & \"<BR>\" & LF &" )
        self.add_compare( "        \"signature: 0x\" & to_hstring(signature)         & \"<BR>\" & LF &" )
        self.add_compare( "        \"data     : 0x\" & to_hstring(data)              & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & std_logic'image(sign_valid_obs) & \"<BR>\" & LF &" )
        self.add_compare( "        \"should be: \" & std_logic'image(sign_valid)     & \"<BR>\" & LF &" )
        self.add_compare( "        \"took \" & integer'image(cycle) & \" cycles\"")
        self.add_compare( "    );" )
        self.add_compare( "else" )
        self.add_compare( "   logger.log_note( LF &" )
        self.add_compare( "       \"Transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"pkey     : 0x\" & to_hstring(pkey)              & \"<BR>\" & LF &" )
        self.add_compare( "        \"signature: 0x\" & to_hstring(signature)         & \"<BR>\" & LF &" )
        self.add_compare( "        \"data     : 0x\" & to_hstring(data)              & \"<BR>\" & LF &" )
        self.add_compare( "        \"yield    : \" & std_logic'image(sign_valid_obs) & \"<BR>\" & LF &" )
        self.add_compare( "       \"took \" & integer'image(cycle) & \" cycles\"" )
        self.add_compare( "   );" )
        self.add_compare( "end if;" )

        op_count = 10
        self.add_action( "-- Testbench actions" )
        self.add_action( "" )

        self.add_action( "-- Directed tests" )
        self.add_action( "    -- none yet" )

        self.add_action( "-- Random tests" )
        self.add_action( "-- " + str(op_count) + " varification of random data with signed with random key" )
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
            self.add_verification( pk, vhdl_hex_string , signature, 1)
            # Invalidate signature
            signature = signature - 1
            self.add_verification( pk, vhdl_hex_string , signature, 0)

class BLS_verify(Entity):
    def __init__(self, dp):
        self.id = "signature/bls_verify"
        self.src = [ "bls_verify.vhd" ]
        self.dep = [
            "hash/map_to_point",
            "pairing/twisted_weil",
            "ec/efp_point_decompressor"
        ]

    def is_compatible_with(self, dp):
        # FIXME, check cofactor, etc
        return True

    def get_default_tb(self, dp):
        return TestBench_bls_verify(dp, self)

obj = BLS_verify(dp)