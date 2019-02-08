-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity efp_point_compressor is
    port (
        clk:       in  std_logic;
        reset:     in  std_logic;
        start:     in  std_logic;
        done:      out std_logic;
        ecP:       in  ec1_point;
        comp_ecP:  out compr_ec1_point
    );
end efp_point_compressor;

architecture circuit of efp_point_compressor is

    signal suffix: std_logic;
    signal half_p: Fp_element;

begin

    -- Half P by shifting
    half_p <= "0" & c_P(c_P'length-1 downto 1);

    -- Compare y coordonate with half_p  and set suffix bit accordingly
    p_suffix: process(all)  is
    begin
        if unsigned(ecP.y) > unsigned(half_p) then
            suffix <= '1';
        else
            suffix <= '0';
        end if;
    end process;

    -- Return concatenation of x coordonate and suffix
    comp_ecP <= ecP.x & suffix;

    -- Combinational always ready
    done <= '1';

end circuit;
