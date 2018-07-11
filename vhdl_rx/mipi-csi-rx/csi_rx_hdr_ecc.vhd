library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

--MIPI CSI-2 Header ECC calculation
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

entity csi_rx_hdr_ecc is
    Port ( data : in STD_LOGIC_VECTOR (23 downto 0);
           ecc : out STD_LOGIC_VECTOR (7 downto 0));
end csi_rx_hdr_ecc;

architecture Behavioral of csi_rx_hdr_ecc is

begin
    ecc(7) <= '0';
    ecc(6) <= '0';
    ecc(5) <= data(10) xor data(11) xor data(12) xor data(13) xor data(14) xor data(15) xor data(16) xor data(17) xor data(18) xor data(19) xor data(21) xor data(22) xor data(23);
    ecc(4) <= data(4) xor data(5) xor data(6) xor data(7) xor data(8) xor data(9) xor data(16) xor data(17) xor data(18) xor data(19) xor data(20) xor data(22) xor data(23);
    ecc(3) <= data(1) xor data(2) xor data(3) xor data(7) xor data(8) xor data(9) xor data(13) xor data(14) xor data(15) xor data(19) xor data(20) xor data(21) xor data(23);
    ecc(2) <= data(0) xor data(2) xor data(3) xor data(5) xor data(6) xor data(9) xor data(11) xor data(12) xor data(15) xor data(18) xor data(20) xor data(21) xor data(22);
    ecc(1) <= data(0) xor data(1) xor data(3) xor data(4) xor data(6) xor data(8) xor data(10) xor data(12) xor data(14) xor data(17) xor data(20) xor data(21) xor data(22) xor data(23);
    ecc(0) <= data(0) xor data(1) xor data(2) xor data(4) xor data(5) xor data(7) xor data(10) xor data(11) xor data(13) xor data(16) xor data(20) xor data(21) xor data(22) xor data(23);
end Behavioral;
