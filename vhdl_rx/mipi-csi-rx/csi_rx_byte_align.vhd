library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--MIPI CSI-2 byte aligner
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This receives raw, unaligned bytes (which could contain part of two actual bytes)
--from the SERDES and aligns them by looking for the D-PHY sync pattern

--When wait_for_sync is high the entity will wait until it sees the valid header at some alignment,
--at which point the found alignment is locked until packet_done is asserted

--valid_data is asserted as soon as the sync pattern is found, so the next byte
--contains the CSI packet header

--In reality to avoid false triggers we must look for a valid sync pattern on all 4 lanes,
--if this does not occur the word aligner (a seperate entity) will assert packet_done immediately

entity csi_rx_byte_align is
    port ( clock : in STD_LOGIC; --byte clock in
           reset : in STD_LOGIC; --synchronous active high reset
           enable : in STD_LOGIC; --active high enable
           deser_in : in STD_LOGIC_VECTOR (7 downto 0); --raw data from ISERDES
           wait_for_sync : in STD_LOGIC; --when high will look for a sync pattern if sync not already found
           packet_done : in STD_LOGIC; --assert to reset synchronisation status
           valid_data : out STD_LOGIC; --goes high as soon as sync pattern is found (so data out on next cycle contains header)
           data_out : out STD_LOGIC_VECTOR (7 downto 0)); --aligned data out, typically delayed by 2 cycles
end csi_rx_byte_align;

architecture Behavioral of csi_rx_byte_align is

signal curr_byte : std_logic_vector(7 downto 0);
signal last_byte : std_logic_vector(7 downto 0);
signal shifted_byte : std_logic_vector(7 downto 0);

signal found_hdr : std_logic;
signal valid_data_int : std_logic;
signal hdr_offs : unsigned(2 downto 0);
signal data_offs  : unsigned(2 downto 0);

begin

    process(clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                valid_data_int <= '0';
            elsif enable = '1' then
                last_byte <= curr_byte;
                curr_byte <= deser_in;
					      data_out <= shifted_byte;

                if packet_done = '1' then
                    valid_data_int <= found_hdr;
                elsif wait_for_sync = '1' and found_hdr = '1' and valid_data_int = '0' then
                    valid_data_int <= '1';
                    data_offs <= hdr_offs;
                end if;
            end if;
        end if;
    end process;
    valid_data <= valid_data_int;
    --This assumes that data is arranged correctly (chronologically last bit in MSB)
    --and looks for the "10111000" sync sequence
    process(curr_byte, last_byte)
    constant sync : std_logic_vector(7 downto 0) :=  "10111000";
    variable was_found : boolean := false;
    variable offset : integer range 0 to 7;
    begin
        offset := 0;
        was_found := false;
        for i in 0 to 7 loop
            if (curr_byte(i downto 0) & last_byte(7 downto i + 1) = sync) and (unsigned(last_byte(i downto 0)) = 0) then
                was_found := true;
                offset := i;
            end if;
        end loop;
        if was_found then
            found_hdr <= '1';
            hdr_offs <= to_unsigned(offset, 3);
        else
            found_hdr <= '0';
            hdr_offs <= "000";
        end if;
    end process;

    --This aligns the data correctly
    shifted_byte <= curr_byte when data_offs = 7 else
                    curr_byte(6 downto 0) & last_byte(7 downto 7) when data_offs = 6 else
                    curr_byte(5 downto 0) & last_byte(7 downto 6) when data_offs = 5 else
                    curr_byte(4 downto 0) & last_byte(7 downto 5) when data_offs = 4 else
                    curr_byte(3 downto 0) & last_byte(7 downto 4) when data_offs = 3 else
                    curr_byte(2 downto 0) & last_byte(7 downto 3) when data_offs = 2 else
                    curr_byte(1 downto 0) & last_byte(7 downto 2) when data_offs = 1 else
                    curr_byte(0 downto 0) & last_byte(7 downto 1);


end Behavioral;
