-------------------------------------------------------------------------------
-- Algorithm
--
-- Constants used:
--   c_P
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity fp_adder_subtractor is
    port (
        clk:      in  std_logic;
        reset:    in  std_logic;
        start:    in  std_logic;
        done:     out std_logic;
        x:        in  Fp_element;
        y:        in  Fp_element;
        z:        out Fp_element;
        addn_sub: in std_logic
    );
end fp_adder_subtractor;

architecture rtl of fp_adder_subtractor is

    -- Pre-compute minus_m = 2**(N)-P
    -- (N = P'length)
    function f_minus_p (
        module : in std_logic_vector
    )
    return unsigned is
        variable power     : unsigned(module'length downto 0);
        variable result    : unsigned(module'length downto 0);
    begin
        power := (others => '0');
        power(power'left) := '1';
        result := power - unsigned(module);
        return result(module'range);
    end;

    constant K:          integer := c_P'length;
    constant MINUS_P:    unsigned(c_P'range) := f_minus_p(c_P);
    -- Adder
    signal add_z1:           Fp_element;
    signal add_z2:           Fp_element;
    signal add_c1:           std_logic;
    signal add_c2:           std_logic;
    signal add_long_x:       std_logic_vector(K downto 0);
    signal add_long_y:       std_logic_vector(K downto 0);
    signal add_long_result1: std_logic_vector(K downto 0);
    signal add_long_z1:      std_logic_vector(K downto 0);
    signal add_long_result2: std_logic_vector(K downto 0);
    signal add_z:            Fp_element;

    -- Subtractor
    signal sub_z1:           Fp_element;
    signal sub_z2:           Fp_element;
    signal sub_inv_y:        Fp_element;
    signal sub_c1:           std_logic;
    signal sub_long_x:       std_logic_vector(K downto 0);
    signal sub_long_inv_y:   std_logic_vector(K downto 0);
    signal sub_long_result1: std_logic_vector(K downto 0);
    signal sub_z:            Fp_element;

    signal z_sig:            Fp_element;
    signal z_reg:            Fp_element;

begin

    -- Adder
    add_long_x       <= '0' & x;
    add_long_y       <= '0' & y;
    add_long_result1 <= std_logic_vector(unsigned(add_long_x) + unsigned(add_long_y));
    add_c1           <= add_long_result1(K);
    add_z1           <= add_long_result1(K-1 downto 0);
    add_long_z1      <= '0' & add_z1;
    add_long_result2 <= std_logic_vector(unsigned(add_long_z1) + MINUS_P);
    add_c2           <= add_long_result2(K);
    add_z2           <= add_long_result2(K-1 downto 0);
    add_z            <= add_z1 when (add_c1 or add_c2)='0' else add_z2;

    -- Subtractor

    sub_long_x <= '0' & x;
    inversion: for i in 0 to K-1 generate
        sub_inv_y(i) <= not( y(i) );
    end generate;
    sub_long_inv_y   <= '0' & sub_inv_y;
    sub_long_result1 <= std_logic_vector(unsigned(sub_long_x) + unsigned(sub_long_inv_y) + 1);
    sub_c1 <= sub_long_result1(K);
    sub_z1 <= sub_long_result1(K-1 downto 0);
    sub_z2 <= std_logic_vector(unsigned(sub_z1) + unsigned(c_P));
    sub_z  <= sub_z1 when sub_c1='1' else sub_z2;

    with addn_sub select z_sig <= add_z when '0', sub_z when others;

    -- always ready
    done <= '1';

    -- assign output
    z <= z_reg;

    registers: process(clk,reset)
    begin
        if reset = '1' then
            z_reg <= (others=>'0');
        elsif rising_edge(clk) then
            if start = '1' then
                z_reg <= z_sig;
            end if;
        end if;
    end process registers;

    done <= '1';

end rtl;
