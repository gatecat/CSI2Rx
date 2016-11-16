	
library ieee ;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

--VGA Proof-of-Concept with alphanumeric printing
--Somewhat beta, this is designed for another setup, not the DE0
--Output format: 1920x1080x60
entity test_pattern_1080p is
port(clock : in std_logic;
 vsync : out std_logic;
 hsync : out std_logic;
 den : out std_logic;
 pixel_data : out std_logic_vector(23 downto 0) --RRRRGGGGBBBB
 

 );
 
end test_pattern_1080p;

architecture behv_vga of test_pattern_1080p is

signal sysck : std_logic;

signal odd_frame : std_logic := '0';

signal hpos : std_logic_vector(11 downto 0) := (others => '0');
signal vpos : std_logic_vector(10 downto 0) := (others => '0');

signal pixel_x : std_logic_vector(10 downto 0) := (others => '0');
signal pixel_y : std_logic_vector(10 downto 0) := (others => '0');

signal h_blank : std_logic := '0';
signal v_blank : std_logic := '0';

constant hlength : integer := 2200;
constant vlength : integer := 1125;

constant h_a_end : integer := 44;
constant h_b_end : integer := 132;
constant h_c_end : integer := 2052;

constant v_a_end : integer := 5;
constant v_b_end : integer := 9;
constant v_c_end : integer := 1089;

signal cur_char : std_logic_vector(5 downto 0); --value (0-F) of current char
signal cur_char_pix : std_logic_vector(63 downto 0); --all 64 pixels (8x8) corresponding to current char
signal pixel_data_int : std_logic_vector(23 downto 0); --output from test pattern generator


begin
sysck <= clock;

--Horizontal counter
process(sysck)
begin
    if sysck = '1' and sysck'event then
        if hpos = hlength - 1 then
            hpos <= (others => '0');
            odd_frame <= NOT odd_frame;
        else
            hpos <= hpos + 1;
        end if;
    end if;
end process;
--Vertical counter
process(sysck)
begin
    if sysck = '1' and sysck'event then
        if hpos = hlength - 1 then --if horizontal is about to wrap around
            if vpos = vlength - 1 then
                vpos <= (others => '0');
            else
                vpos <= vpos + 1;
            end if;
        end if;
    end if;
end process;
--Horizontal sync 
process(hpos)
begin
    if hpos < h_a_end then
        hsync <= '1';
    else
        hsync <= '0';
    end if;
end process;
--Vertical sync
process(vpos)
begin
    if vpos < v_a_end then
        vsync <= '1';
    else
        vsync <= '0';
    end if;
end process;
--Horizontal blanking
process(hpos)
begin
    if hpos >= h_b_end and hpos < h_c_end then
        h_blank <= '0';
    else
        h_blank <= '1';
    end if;
end process;
--Vertical blanking
process(vpos)
begin
    if vpos >= v_b_end and vpos < v_c_end then
        v_blank <= '0';
    else
        v_blank <= '1';
    end if;
end process;

den <= (not h_blank) and (not v_blank);

--Pixel X counter
process(sysck)
begin
    if sysck = '1' and sysck'event then
        if h_blank = '1' then
            pixel_x <= (others => '0');
        else
            pixel_x <= pixel_x + 1;
        end if;
    end if;
end process;
--Pixel Y counter
process(sysck)
begin
    if sysck = '1' and sysck'event then
        if hpos = hlength - 1 then --if horizontal is about to wrap around
                if v_blank = '1' then
                    pixel_y <= (others => '0');
                else
                    pixel_y <= pixel_y + 1;
                end if;
        end if;
    end if;
end process;
--Test pattern generator
process(pixel_x, pixel_y, h_blank, v_blank, odd_frame)
        variable h_mul : std_logic_vector(15 downto 0);
        variable v_mul : std_logic_vector(14 downto 0);

begin
    h_mul := pixel_x * "10001"; --Implementing divide by constant using multiply by inverse
    v_mul := pixel_y * "1111";
    if h_blank = '0' and v_blank = '0' then
        pixel_data_int <= x"000000";
        pixel_data_int(23 downto 22) <= h_mul(14 downto 13) ;
        pixel_data_int(15 downto 14) <= h_mul(12 downto 11);
        pixel_data_int(7 downto 6) <= v_mul(13 downto 12);

    else
        pixel_data_int <= x"000000";
    end if;
end process;

--Character generation
process(pixel_data_int, cur_char_pix, h_blank, v_blank, pixel_x, pixel_y)
begin
    if h_blank = '0' and v_blank = '0' then
        --If font specifies pixel as '1', then invert current pixel, otherwise leave it as is
        if cur_char_pix(8 * (7 - to_integer(unsigned(pixel_y(2 downto 0)))) + (7 - to_integer(unsigned(pixel_x(2 downto 0))))) = '1' then
            pixel_data <= NOT pixel_data_int;
        else
            pixel_data <= pixel_data_int;
        end if;
    else
        pixel_data <= x"000000";
    end if;
end process;
--Font look up table
--Based on data from http://opengameart.org/content/8x8-ascii-bitmap-font-with-c-source
process(cur_char)
begin
    case cur_char is
        when "000000" => --0-9
            cur_char_pix <= x"1824424224180000";
        when "000001" =>
            cur_char_pix <= x"08180808081C0000";
        when "000010" =>
            cur_char_pix <= x"3C420418207E0000";
        when "000011" =>
            cur_char_pix <= x"3C420418423C0000";
        when "000100" =>
            cur_char_pix <= x"081828487C080000";
        when "000101" =>
            cur_char_pix <= x"7E407C02423C0000";
        when "000110" =>
            cur_char_pix <= x"3C407C42423C0000";
        when "000111" =>
            cur_char_pix <= x"7E04081020400000";
        when "001000" =>
            cur_char_pix <= x"3C423C42423C0000";
        when "001001" =>
            cur_char_pix <= x"3C42423E023C0000";
        when "001010" => --A-Z
            cur_char_pix <= x"1818243C42420000";
        when "001011" =>
            cur_char_pix <= x"7844784444780000";
        when "001100" =>
            cur_char_pix <= x"3844808044380000";
        when "001101" =>
            cur_char_pix <= x"7844444444780000";
        when "001110" =>
            cur_char_pix <= x"7C407840407C0000";
        when "001111" =>
            cur_char_pix <= x"7C40784040400000";
        when "010000" =>
            cur_char_pix <= x"3844809C44380000";
        when "010001" =>
            cur_char_pix <= x"42427E4242420000";
        when "010010" =>
            cur_char_pix <= x"3E080808083E0000";
        when "010011" =>
            cur_char_pix <= x"1C04040444380000";
        when "010100" =>
            cur_char_pix <= x"4448507048440000";
        when "010101" =>
            cur_char_pix <= x"40404040407E0000";
        when "010110" =>
            cur_char_pix <= x"4163554941410000";
        when "010111" =>
            cur_char_pix <= x"4262524A46420000";
        when "011000" =>
            cur_char_pix <= x"1C222222221C0000";
        when "011001" =>
            cur_char_pix <= x"7844784040400000";
        when "011010" =>
            cur_char_pix <= x"1C222222221C0200";
        when "011011" =>
            cur_char_pix <= x"7844785048440000";
        when "011100" =>
            cur_char_pix <= x"1C22100C221C0000";
        when "011101" =>
            cur_char_pix <= x"7F08080808080000";
        when "011110" =>
            cur_char_pix <= x"42424242423C0000";
        when "011111" =>
            cur_char_pix <= x"8142422424180000";
        when "100000" =>
            cur_char_pix <= x"4141495563410000";
        when "100001" =>
            cur_char_pix <= x"4224181824420000";
        when "100010" =>
            cur_char_pix <= x"4122140808080000";
        when "100011" =>
            cur_char_pix <= x"7E040810207E0000";
        when others =>
            cur_char_pix <= x"0000000000000000";
    end case;
end process;

--Message LUT
--Current char to output
process(pixel_x)
begin
    if pixel_x(10 downto 7) = 0 then
        case pixel_x(6 downto 3) is
        when "0000" =>
            cur_char <= "111111"; --
        when "0001" =>
            cur_char <= "010001"; --H
        when "0010" =>
            cur_char <= "001110"; --E
        when "0011" =>
            cur_char <= "010101"; --L
        when "0100" =>
            cur_char <= "010101"; --L
        when "0101" =>
            cur_char <= "011000"; --O
        when "0110" =>
            cur_char <= "111111"; -- 
        when "0111" =>
            cur_char <= "100000"; --W
        when "1000" =>
            cur_char <= "011000"; --O
        when "1001" =>
            cur_char <= "011011"; --R
        when "1010" =>
            cur_char <= "010101"; --L
        when "1011" =>
            cur_char <= "001101"; --D
        when others =>
            cur_char <= "111111";
        end case;
    elsif pixel_x(10 downto 9) = 1 then
        cur_char <= pixel_x(8 downto 3);
    else
        cur_char <= "111111";
    end if;
end process;
end behv_vga;

 
