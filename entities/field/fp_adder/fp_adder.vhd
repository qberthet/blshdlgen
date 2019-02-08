-------------------------------------------------------------------------------
-- Algorithm 3.2: Binary mod m addition
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

entity fp_adder is
    port (
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        done:  out std_logic;
        x:     in  Fp_element;
        y:     in  Fp_element;
        z:     out Fp_element
    );
end fp_adder;

architecture circuit of fp_adder is

    -- Pre-compute minus_m = 2**(K)-P
    -- (K = P'length)
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
    constant MINUS_P:    unsigned(c_P'range) := f_minus_p(c_p);

    signal z_sig:        Fp_element;
    signal z_reg:        Fp_element;

    signal z1:           Fp_element;
    signal z2:           Fp_element;
    signal c1:           std_logic;
    signal c2:           std_logic;
    signal long_x:       std_logic_vector(K downto 0);
    signal long_y:       std_logic_vector(K downto 0);
    signal long_result1: std_logic_vector(K downto 0);
    signal long_z1:      std_logic_vector(K downto 0);
    signal long_result2: std_logic_vector(K downto 0);

begin
    long_x       <= '0' & x;
    long_y       <= '0' & y;
    long_result1 <= std_logic_vector(unsigned(long_x) + unsigned(long_y));
    c1           <= long_result1(K);
    z1           <= long_result1(K-1 downto 0);
    long_z1      <= '0' & z1;
    long_result2 <= std_logic_vector(unsigned(long_z1) + MINUS_P);
    c2           <= long_result2(K);
    z2           <= long_result2(K-1 downto 0);
    z_sig        <= z1 when (c1 or c2)='0' else z2;

    -- always ready
    done <= '1';

    -- assign output
    z <= z_reg;

    registers: process(clk, reset)
    begin
        if reset = '1' then
            z_reg <= (others => '0');
        elsif rising_edge(clk) then
            z_reg <= z_reg;
            if start = '1' then
                z_reg <= z_sig;
            end if;
        end if;
    end process registers;

end circuit;
