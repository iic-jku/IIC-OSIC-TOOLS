-- counter.vhdl -- Simple Digital Counter Example in VHDL
--
-- (c) 2024 Harald Pretl (harald.pretl@jku.at)
-- Johannes Kepler University Linz, Institute for Integrated Circuits

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
    generic (
        COUNTER_WIDTH : integer := 32
    );
    Port (
        clk_i   : in  std_logic;
        reset_i : in  std_logic;
        out_o   : out std_logic_vector (COUNTER_WIDTH-1 downto 0)
    );
end counter;

architecture Behavioral of counter is
    signal count : unsigned (COUNTER_WIDTH-1 downto 0);
begin

    process(clk_i, reset_i)
    begin
        if reset_i = '1' then
            count <= (others => '0');  -- asynchronous reset
        elsif rising_edge(clk_i) then
            count <= count + 1;
        end if;
    end process;

    out_o <= std_logic_vector(count);

end Behavioral;
