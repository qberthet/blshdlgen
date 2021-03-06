-- =====================================================================
-- Copyright © 2010-2012 by Cryptographic Engineering Research Group (CERG),
-- ECE Department, George Mason University
-- Fairfax, VA, U.S.A.
-- =====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all; 
use ieee.numeric_std.all;
use work.sha3_pkg.all;
use work.keccak_pkg.all;

-- Possible generics values: 
-- hs = {HASH_SIZE_256, HASH_SIZE_512} 
-- b = {KECCAK256_CAPACITY, KECCAK512_CAPACITY}
-- possible combinaations of (hs, b) = {(HASH_SIZE_256, KECCAK256_CAPACITY), (HASH_SIZE_512, KECCAK512_CAPACITY)}

entity keccak_datapath is
generic (b : integer := KECCAK256_CAPACITY; hs: integer := HASH_SIZE_256; version:integer:=SHA3_ROUND3);	
port (
		clk 				:in std_logic;
		rst 				:in std_logic;
		din 				:in std_logic_vector(w-1 downto 0);
		dout 				:out std_logic_vector(w-1 downto 0);
		
		-- input
		en_len				:in std_logic;
		en_ctr				:in std_logic; 
		ein 				:in std_logic; 		
		c					:out std_logic_vector(31 downto 0); 
		final_segment		:out std_logic;
		-- process
		sel_xor 			:in std_logic;
		sel_final			:in std_logic;
		wr_state			:in std_logic;
		ld_rdctr			:in std_logic;
		en_rdctr 			:in std_logic;
		
		-- pad
		clr_len	: in std_logic; 							 		
		sel_dec_size : in std_logic; -- select decrement size
		spos : in std_logic_vector(1 downto 0);	 
		last_word : in std_logic;
		
		-- output
		sel_piso			:in std_logic;
		wr_piso				:in std_logic	
		
	);
end keccak_datapath;			   

architecture struct of keccak_datapath is  
	signal din_a, din_b : std_logic_vector(31 downto 0);
	signal from_sipo	:std_logic_vector(b-1 downto 0);																	
																   
	signal from_concat, to_xor, from_round, from_xor, to_register, to_round : std_logic_vector(KECCAK_STATE-1 downto 0);		  
							   
	signal to_piso  	: std_logic_vector(hs-1 downto 0);
	signal rd_ctr	: std_logic_vector(4 downto 0);
	signal rc,  swap_din	:	std_logic_vector(w-1   downto 0);
	
	constant zeros: std_logic_vector (KECCAK_STATE-1-b downto 0) := (others => '0');
	constant state_zero : std_logic_vector (KECCAK_STATE-1 downto 0):=(others => '0'); 
	constant BLOCK_SIZE : integer := b;
 	
	type res_type is array (0 to hs/w-1) of std_logic_vector(w-1 downto 0); 			   
	signal se_result : res_type;   
	
	-- padding signals
	signal din_padded : std_logic_vector(w-1 downto 0);
	signal c_wire, c_wire_in : std_logic_vector(31 downto 0);
	
	signal sel_pad_type_lookup, sel_din_lookup : std_logic_vector( 7 downto 0 ); 	
	signal sel_din, sel_pad_location : std_logic_vector(7 downto 0);
	
	-- debugging signals
	--signal aa, bb, cc : state_table;
begin	
	--aa <= str2table( to_round );
--	bb <= str2table( from_round );		 
--	cc <= str2table( from_concat );
	
	-- last segment flag 	
	rd2_fs_gen: if version=SHA3_ROUND2 generate
		final_segment <= din(0);			   
	end generate;
	
	rd3_fs_gen: if version=SHA3_ROUND3 generate
		final_segment <= din(63);			   
	end generate;
	
	-- segment counter
	segment_cntr_gen : process( clk )
	begin
		if rising_edge( clk ) then	
			if ( clr_len = '1' ) then
				c_wire <= (others => '0');
			elsif ( en_len = '1' ) then
				c_wire <= din(31 downto 0);
			elsif ( en_ctr = '1' ) then
				c_wire <= c_wire_in;
			end if;
		end if;
	end process;
	c_wire_in <= c_wire - BLOCK_SIZE when sel_dec_size = '1' else c_wire - 64;
	c <= c_wire;		
	
	-- padding unit
	sel_pad_type_lookup <= lookup_sel_lvl2_64bit_pad(conv_integer(c_wire(5 downto 3)));
	sel_pad_location <= (others => '0') when spos(0) = '0' else sel_pad_type_lookup;	
	
	sel_din_lookup <= lookup_sel_lvl1_64bit_pad(conv_integer(c_wire(5 downto 3)));	
	sel_din <= (others => '1') when spos(1) = '1' else sel_din_lookup;
	
	pad_unit: entity work.keccak_bytepad(struct) generic map ( w => w )
		port map ( din => din, dout => din_padded, sel_pad_location => sel_pad_location, sel_din =>  sel_din, last_word => last_word );

	
	-- serial input parallel output
	din_a <= din_padded(31 downto 0);
	din_b <= din_padded(63 downto 32);
	swap_din <= switch_endian_byte(din_a,32,32)  &  switch_endian_byte(din_b,32,32);	  
	
	in_buf 		: sipo 
	generic map (N => b, M => w) 
	port map (clk => clk, en => ein, input => swap_din, output => from_sipo );
		
	from_concat <=  from_sipo & zeros;	   			
	to_xor <= state_zero when sel_xor='1' else from_round; 
	from_xor <= from_concat xor to_xor;
	to_register <= from_xor when sel_final='1' else from_round;
		
	-- regsiter for intermediate values	
	state		: regn 
	generic map (N => KECCAK_STATE, init=>state_zero) 
	port map ( clk =>clk, rst=>rst, en =>wr_state, input=>to_register, output=>to_round);	 
   
	-- asynchronous memory for Keccak constants 
	rd_cons 	: entity work.keccak_cons(keccak_cons) 	port map (addr=>rd_ctr, rc=>rc);
	-- Keccak round function with architecture based on Marcin Rogawski implementation
	rd 			: entity work.keccak_round(mrogawski_round)port map (rc=>rc, rin=>to_round, rout=>from_round);

	-- round counter
   	ctr 		: countern 
	generic map ( N => 5, step=>1, style=>COUNTER_STYLE_1 ) 
	port map ( clk => clk, rst=>rst, load => ld_rdctr, en => en_rdctr, input => zeros(4 downto 0), output => rd_ctr);
	
   	-- piso endianess fixing function
	out_gen: for i in 0 to hs/w-1 generate	
		se_result(i) <= to_round(KECCAK_STATE-i*w-1 downto KECCAK_STATE-(i+1)*w); 
		to_piso(hs-i*w-1 downto hs-(i+1)*w) <= switch_endian_word(x=>se_result(i), width=>w, w=>8);	
	end generate;	
		
	-- parallel input serial output	
	out_buf 	: piso 
	generic map (N => hs, M => w) 
	port map (clk => clk, sel => sel_piso, en => wr_piso, input => to_piso,  output => dout );  
end struct;