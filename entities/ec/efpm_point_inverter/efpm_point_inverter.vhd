--------------------------------------------------------------------------------
-- Constants used:
--   c_FPM_ZERO
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity efpm_point_inverter is
    port (
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        done:  out std_logic;
        ecP:   in  ec2_point;
        ecR:   out ec2_point
    );
end efpm_point_inverter;

architecture rtl of efpm_point_inverter is

    component fpm_subtractor is
        port(
            clk:      in  std_logic;
            reset:    in  std_logic;
            start:    in  std_logic;
            done:     out std_logic;
            x:        in  Fpm_element;
            y:        in  Fpm_element;
            z:        out Fpm_element
        );
    end component;

    signal addsub_start: std_logic;
    signal addsub_done:  std_logic;
    signal addsub_x:     Fpm_element;
    signal addsub_y:     Fpm_element;
    signal addsub_z:     Fpm_element;

    signal temp_Ry:      Fpm_element;

    -- P.y will be registered by adder_subtractor
    signal ecPx_reg:     Fpm_element;
    signal ecPii_reg:    std_logic;

begin

    ----------------------------------------------------------------------------
    -- First modular addition/subtraction entity and input routing
    ----------------------------------------------------------------------------

    fpm_subtractor_i: entity work.fpm_subtractor
    port map (
        clk      => clk,
        reset    => reset,
        start    => start,
        done     => done,
        x        => c_FPM_ZERO,
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
    with ecPii_reg select ecR.y <= c_FPM_ZERO when '1',
                                   temp_Ry    when others;

    ecR.x  <= ecPx_reg;
    ecR.ii <= ecPii_reg;

end rtl;
