import binascii
import random

class TestBench_bls_keygen(TB_sequential):

    def add_keygen(self, random, pkey, skey):
        self.add_action( "func(" + self.dp.Fp_element_to_vhdl_string(random) + ", -- random" )
        self.add_action( "     " + self.dp.Fp_element_to_vhdl_string(skey) +", -- Secret key" )
        self.add_action( "     " + self.dp.compr_ec1_point_to_vhdl_string(pkey) +" -- Public key" )
        self.add_action( ");")

    def __init__(self, dp, entity):
        TB_sequential.__init__(self, dp, entity)
        # Build port
        self.add_port( "random:     in  Fp_element" )
        self.add_port( "skey:       out Fp_element" )
        self.add_port( "pkey:       out compr_ec1_point" )
        # Build signal
        self.add_signal( "signal random_sti:    Fp_element" )
        self.add_signal( "signal skey_obs:      Fp_element" )
        self.add_signal( "signal pkey_obs:      compr_ec1_point" )
        # Build port map
        self.add_port_map( "random    => random_sti" )
        self.add_port_map( "skey      => skey_obs" )
        self.add_port_map( "pkey      => pkey_obs" )
        # Build signal driving
        self.add_drive( "random_sti <= random;" )
        # Build function parameters
        self.add_func_param( "random: Fp_element" )
        self.add_func_param( "skey:   Fp_element" )
        self.add_func_param( "pkey:   compr_ec1_point" )
        # Build compare
        self.add_compare( "if (skey_obs /= skey) or (pkey_obs /= pkey) then" )
        self.add_compare( "    logger.log_error( LF &" )
        self.add_compare( "        \"Error: transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"random   : \" & to_hstring(random_sti)    & \"<BR>\"  & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(skey_obs) & \" and \" & to_string(pkey_obs) & \"<BR>\" & LF &" )
        self.add_compare( "        \"should be: \" & to_string(skey)     & \" and \" & to_string(pkey)     & \"<BR>\" & LF &" )
        self.add_compare( "        \"took \" & integer'image(cycle) & \" cycles\"")
        self.add_compare( "    );" )
        self.add_compare( "else" )
        self.add_compare( "   logger.log_note( LF &" )
        self.add_compare( "        \"Transaction number \" & integer'image(op_count) & \" on\" & \"<BR>\" & LF &" )
        self.add_compare( "        \"random   : \" & to_hstring(random_sti)    & \"<BR>\"  & LF &" )
        self.add_compare( "        \"yield    : \" & to_string(skey_obs) & \" and \" & to_string(pkey_obs) & \"<BR>\" & LF &" )
        self.add_compare( "        \"took \" & integer'image(cycle) & \" cycles\"" )
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
            rand = self.dp.Fp.random_element()
            # Generate from specified random
            (pk, sk) = bls.key_gen(rand)
            self.add_keygen(rand, pk, sk)

class BLS_keygen(Entity):
    def __init__(self, dp):
        self.id = "signature/bls_keygen"
        self.src = [ "bls_keygen.vhd" ]
        self.dep = [
            #"field/fp_reducer", FIXME
            "ec/efp_point_multiplier",
            "ec/efp_point_compressor"
        ]

    def is_compatible_with(self, dp):
        # FIXME, check cofactor, etc
        return True

    def get_default_tb(self, dp):
        return TestBench_bls_keygen(dp, self)

obj = BLS_keygen(dp)