library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--Manual focus controller
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This reads two buttons and outputs a current value for the focus voice
--coil driver

entity manual_focus is
    Port ( clock : in  STD_LOGIC;
           enable : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           i2c_start : out  STD_LOGIC;
           vcm_value : out  STD_LOGIC_VECTOR (9 downto 0);
           btn_inc : in  STD_LOGIC;
           btn_dec : in  STD_LOGIC);
end manual_focus;

architecture Behavioral of manual_focus is
signal int_focus_value : unsigned(22 downto 0);
signal last_focus_value : unsigned(9 downto 0);
signal out_focus_value : std_logic_vector(9 downto 0);
signal i2c_wait_ctr : unsigned(8 downto 0);
begin

	process(reset, clock)
	begin
		if reset = '1' then
			int_focus_value <= (others => '0');
			last_focus_value <= (others => '0');
			out_focus_value <= (others => '0');
			i2c_wait_ctr <= (others => '0');
		elsif rising_edge(clock) then
			if enable = '1' then

				--User side
				if btn_inc = '1' then
					if int_focus_value < 8388607 then
						int_focus_value <= int_focus_value + 1;
					end if;
				elsif btn_dec = '1' then
					if int_focus_value > 0 then
						int_focus_value <= int_focus_value - 1;
					end if;
				end if;

				--I2C side
				if i2c_wait_ctr = 0 then
					if int_focus_value(22 downto 13) /= last_focus_value then
						out_focus_value <= std_logic_vector(int_focus_value(22 downto 13));
						last_focus_value <= int_focus_value(22 downto 13);
						i2c_start <= '1';
					else
						i2c_start <= '0';
					end if;
				else
					i2c_start <= '0';
				end if;

				i2c_wait_ctr <= i2c_wait_ctr + 1;
			end if;
		end if;
	end process;

	vcm_value <= out_focus_value;
end Behavioral;
