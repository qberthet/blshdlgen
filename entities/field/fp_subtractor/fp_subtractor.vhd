-------------------------------------------------------------------------------
-- Algorithm 3.4: Binary mod m subtraction
--
-- Constants used:
--   c_P
--
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity fp_subtractor is
    port (
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        done:  out std_logic;
        x:     in  Fp_element;
        y:     in  Fp_element;
        z:     out Fp_element
    );
end fp_subtractor;

architecture circuit of fp_subtractor is
    constant K:          positive := c_P'length;

    signal z_sig:        Fp_element;
    signal z_reg:        Fp_element;

    signal z1:           Fp_element;
    signal z2:           Fp_element;
    signal inv_y:        Fp_element;
    signal c1:           std_logic;
    signal long_x:       std_logic_vector(K downto 0);
    signal long_inv_y:   std_logic_vector(K downto 0);
    signal long_result1: std_logic_vector(K downto 0);

begin
    long_x <= '0' & x;
    inversion: for i in 0 to K-1 generate
        inv_y(i) <= not( y(i) );
    end generate;
    long_inv_y   <= '0' & inv_y;
    long_result1 <= std_logic_vector(unsigned(long_x) + unsigned(long_inv_y) + 1);
    c1 <= long_result1(K);
    z1 <= long_result1(K-1 downto 0);
    z2 <= std_logic_vector(unsigned(z1) + unsigned(c_P));
    z_sig  <= z1 when c1='1' else z2;

    -- always ready
    done <= '1';

    -- assign output
    z <= z_reg;

    registers: process(clk, reset)
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

end circuit;
