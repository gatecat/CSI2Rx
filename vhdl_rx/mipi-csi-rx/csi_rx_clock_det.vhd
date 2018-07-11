library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--Simple Clock Detector for CSI-2 Rx
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This is designed to hold the ISERDES in reset until at least 3 byte clock
--cycles have been detected; to ensure proper ISERDES behaviour
--It will reassert reset once the byte clock has not toggled compared to the reference clock
--for at least 200 reference clock cycles

entity csi_rx_clock_det is
  port (  ref_clock : in std_logic; --reference clock in; must not be synchronised to ext_clock
          ext_clock : in STD_LOGIC; --external byte clock input for detection
          enable : in STD_LOGIC; --active high enable
          reset_in : in STD_LOGIC; --active high asynchronous reset in
          reset_out : out STD_LOGIC); --active high reset out to ISERDESs
end csi_rx_clock_det;

architecture Behavioral of csi_rx_clock_det is
signal count_value : unsigned(3 downto 0);
signal clk_fail : std_logic;
signal ext_clk_lat : std_logic;
signal last_ext_clk : std_logic;
signal clk_fail_count : unsigned(7 downto 0);
begin
    process(ext_clock, reset_in, clk_fail)
    begin
        if reset_in = '1' or clk_fail = '1' then
            count_value <= x"0";
        elsif rising_edge(ext_clock) then
				if enable = '1' then
					if count_value < 3 then
						 count_value <= count_value + 1;
					end if;
				end if;
        end if;
    end process;
	 --Reset in between frames, by detecting the loss of the high speed clock
	 process(ref_clock)
	 begin
		if rising_edge(ref_clock) then
			ext_clk_lat <= ext_clock;
			last_ext_clk <= ext_clk_lat;
			if last_ext_clk /= ext_clk_lat then
				clk_fail_count <= (others => '0');
			else
				if clk_fail_count < 250 then
					clk_fail_count <= clk_fail_count + 1;
				end if;
			end if;
		end if;
	 end process;

	 clk_fail <= '1' when clk_fail_count >= 200 else '0';
  reset_out <= '0' when count_value >= 2	 else '1';
end Behavioral;
