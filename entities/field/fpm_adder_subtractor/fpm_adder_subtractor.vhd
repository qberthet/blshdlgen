----------------------------------------------------------------------------
-- Adder/Subtractor (fpm_adder_subtractor.vhd)
--
-- Adds or subtract mod p in Zp[x] / f(x)
-- The hardware is genenerate for a specific p.
--
-- Constants used:
--   c_P
--   c_M
--
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity fpm_adder_subtractor is
    port(
        clk:      in  std_logic;
        reset:    in  std_logic;
        start:    in  std_logic;
        done:     out std_logic;
        x:        in  Fpm_element;
        y:        in  Fpm_element;
        z:        out Fpm_element;
        addn_sub: in  std_logic
    );
end fpm_adder_subtractor;

architecture circuit of fpm_adder_subtractor is

    component fp_adder_subtractor is
        port (
            clk:      in  std_logic;
            reset:    in  std_logic;
            start:    in  std_logic;
            done:     out std_logic;
            x:        in  Fp_element;
            y:        in  Fp_element;
            z:        out Fp_element;
            addn_sub: in  std_logic
        );
    end component;

    signal done_v: std_logic_vector(c_M-1 downto 0);

begin

    main_component: for i in 0 to c_M-1 generate
        add_sub_i: fp_adder_subtractor
        port map(
            clk      => clk,
            reset    => reset,
            start    => start,
            done     => done_v(i),
            x        => x(i),
            y        => y(i),
            z        => z(i),
            addn_sub => addn_sub
        );
    end generate;

    done <= and done_v;

end circuit;
