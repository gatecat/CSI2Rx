library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;

--MIPI CSI-2 word aligner
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This receives aligned bytes and status signals from the 4 byte aligners
--and compensates for up to 2 clock cycles of skew between channels. It also
--controls the packet_done input to the byte aligner, resetting byte aligners'
--sync status if all 4 byte aligners fail to find the sync pattern

--Similar to the byte aligner, this locks the alignment once a valid alignment
--has been found until packet_done is asserted

entity csi_rx_word_align is
    Port ( word_clock : in STD_LOGIC; --byte/word clock in
           reset : in STD_LOGIC; --active high synchronous reset
           enable : in STD_LOGIC; --active high enable
           packet_done : in STD_LOGIC; --packet done input from packet handler entity
           wait_for_sync : in STD_LOGIC; --whether or not to be looking for an alignment
			     packet_done_out : out STD_LOGIC; --packet done output to byte aligners
           word_in : in STD_LOGIC_VECTOR (31 downto 0); --unaligned word from the 4 byte aligners
           valid_in : in STD_LOGIC_VECTOR (3 downto 0); --valid_out from the byte aligners (MSB is index 3, LSB index 0)
           word_out : out STD_LOGIC_VECTOR (31 downto 0); --aligned word out to packet handler
           valid_out : out STD_LOGIC); --goes high once alignment is valid, such that the first word with it high is the CSI packet header
end csi_rx_word_align;

architecture Behavioral of csi_rx_word_align is
signal word_dly_0 : std_logic_vector(31 downto 0);
signal word_dly_1 : std_logic_vector(31 downto 0);
signal word_dly_2 : std_logic_vector(31 downto 0);

signal valid_dly_0 : std_logic_vector (3 downto 0);
signal valid_dly_1 : std_logic_vector (3 downto 0);
signal valid_dly_2 : std_logic_vector (3 downto 0);

type taps_t is array(0 to 3) of  std_logic_vector(1 downto 0);

signal taps : taps_t;
signal next_taps : taps_t;

signal valid : std_logic := '0';
signal next_valid : std_logic;
signal invalid_start : std_logic := '0';
signal aligned_word : std_logic_vector(31 downto 0);

begin
    process(word_clock)
    begin
        if rising_edge(word_clock) then
            if reset = '1' then
                valid <= '0';
                taps <= ("00", "00", "00", "00");
            elsif enable = '1' then
                word_dly_0 <= word_in;
                valid_dly_0 <= valid_in;
                word_dly_1 <= word_dly_0;
                valid_dly_1 <= valid_dly_0;
                word_dly_2 <= word_dly_1;
                valid_dly_2 <= valid_dly_1;
                valid_out <= valid;
                word_out <= aligned_word;
                if next_valid = '1' and valid = '0' and wait_for_sync = '1' then
                    valid <= '1';
                    taps <= next_taps;
                elsif packet_done = '1' then
                    valid <= '0';
                end if;
            end if;
        end if;
    end process;

    process(valid_dly_0, valid_dly_1, valid_dly_2)
    variable next_valid_int : std_logic;
    variable is_triggered : std_logic := '0';
	 begin
        next_valid_int := and_reduce(valid_dly_0);
		  --Reset if all channels fail to sync
		  is_triggered := '0';
		  for i in 0 to 3 loop
			if valid_dly_0(i) = '1' and valid_dly_1(i) = '1' and valid_dly_2(i) = '1' then
				is_triggered := '1';
			end if;
		  end loop;
		  invalid_start <= (not next_valid_int) and is_triggered;
		  next_valid <= next_valid_int;
        for i in 0 to 3 loop
            if valid_dly_2(i) = '1' then
                next_taps(i) <= "10";
            elsif valid_dly_1(i) = '1' then
                next_taps(i) <= "01";
            else
                next_taps(i) <= "00";
            end if;
        end loop;
    end process;

	 packet_done_out <= packet_done or invalid_start;

    process(word_dly_0, word_dly_1, word_dly_2, taps)
    begin
        for i in 0 to 3 loop
            if taps(i) = "10" then
                aligned_word((8*i) + 7 downto 8 * i) <= word_dly_2((8*i) + 7 downto 8 * i);
            elsif taps(i) = "01" then
                aligned_word((8*i) + 7 downto 8 * i) <= word_dly_1((8*i) + 7 downto 8 * i);
            else
                aligned_word((8*i) + 7 downto 8 * i) <= word_dly_0((8*i) + 7 downto 8 * i);
            end if;
        end loop;
    end process;
end Behavioral;
