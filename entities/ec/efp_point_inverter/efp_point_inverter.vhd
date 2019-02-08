--------------------------------------------------------------------------------
-- Constants used:
--   c_FP_ZERO
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity efp_point_inverter is
    port (
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        done:  out std_logic;
        ecP:   in  ec1_point;
        ecR:   out ec1_point
    );
end efp_point_inverter;

architecture rtl of efp_point_inverter is

    component fp_subtractor is
        port (
            clk:      in  std_logic;
            reset:    in  std_logic;
            start:    in  std_logic;
            done:     out std_logic;
            x:        in  Fp_element;
            y:        in  Fp_element;
            z:        out Fp_element
        );
    end component;

    signal addsub_start: std_logic;
    signal addsub_done:  std_logic;
    signal addsub_x:     Fp_element;
    signal addsub_y:     Fp_element;
    signal addsub_z:     Fp_element;

    signal temp_Ry:      Fp_element;

    -- P.y will be registered by subtractor
    signal ecPx_reg:     Fp_element;
    signal ecPii_reg:    std_logic;

begin

    ----------------------------------------------------------------------------
    -- Modular addition/subtraction entity and input routing
    ----------------------------------------------------------------------------

    fp_subtractor_i: entity work.fp_subtractor
    port map (
        clk      => clk,
        reset    => reset,
        start    => start,
        done     => done,
        x        => C_FP_ZERO,
        y        => ecP.y,
        z        => temp_Ry
    );

    registers: process(clk)
    begin
        if rising_edge(clk) then
            if start = '1' then
                ecPx_reg  <= ecP.x;
                ecPii_reg <= ecP.ii;
            end if;
        end if;
    end process registers;

    -- To avoid to have bogus y coordinate for point at infinity, could
    -- in theory be removed as ii = '1'
    with ecPii_reg select ecR.y <= C_FP_ZERO when '1',
                                   temp_Ry when others;

    ecR.x  <= ecPx_reg;
    ecR.ii <= ecPii_reg;

end rtl;
