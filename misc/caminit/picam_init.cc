// Simple I2C using MPSSE bitbang implementation (passed thru FPGA) to initialise a PiCam2
// Some code taken from iceprog
#include <ftdi.h>
#include <stdint.h>
#include <stdio.h>

static struct ftdi_context ftdic;
static bool ftdic_open = false;
static bool verbose = false;
static bool ftdic_latency_set = false;
static unsigned char ftdi_latency;


/* MPSSE engine command definitions */
enum mpsse_cmd
{
	/* Mode commands */
	MC_SETB_LOW = 0x80, /* Set Data bits LowByte */
	MC_READB_LOW = 0x81, /* Read Data bits LowByte */
	MC_SETB_HIGH = 0x82, /* Set Data bits HighByte */
	MC_READB_HIGH = 0x83, /* Read data bits HighByte */
	MC_LOOPBACK_EN = 0x84, /* Enable loopback */
	MC_LOOPBACK_DIS = 0x85, /* Disable loopback */
	MC_SET_CLK_DIV = 0x86, /* Set clock divisor */
	MC_FLUSH = 0x87, /* Flush buffer fifos to the PC. */
	MC_WAIT_H = 0x88, /* Wait on GPIOL1 to go high. */
	MC_WAIT_L = 0x89, /* Wait on GPIOL1 to go low. */
	MC_TCK_X5 = 0x8A, /* Disable /5 div, enables 60MHz master clock */
	MC_TCK_D5 = 0x8B, /* Enable /5 div, backward compat to FT2232D */
	MC_EN_3PH_CLK = 0x8C, /* Enable 3 phase clk, DDR I2C */
	MC_DIS_3PH_CLK = 0x8D, /* Disable 3 phase clk */
	MC_CLK_N = 0x8E, /* Clock every bit, used for JTAG */
	MC_CLK_N8 = 0x8F, /* Clock every byte, used for JTAG */
	MC_CLK_TO_H = 0x94, /* Clock until GPIOL1 goes high */
	MC_CLK_TO_L = 0x95, /* Clock until GPIOL1 goes low */
	MC_EN_ADPT_CLK = 0x96, /* Enable adaptive clocking */
	MC_DIS_ADPT_CLK = 0x97, /* Disable adaptive clocking */
	MC_CLK8_TO_H = 0x9C, /* Clock until GPIOL1 goes high, count bytes */
	MC_CLK8_TO_L = 0x9D, /* Clock until GPIOL1 goes low, count bytes */
	MC_TRI = 0x9E, /* Set IO to only drive on 0 and tristate on 1 */
	/* CPU mode commands */
	MC_CPU_RS = 0x90, /* CPUMode read short address */
	MC_CPU_RE = 0x91, /* CPUMode read extended address */
	MC_CPU_WS = 0x92, /* CPUMode write short address */
	MC_CPU_WE = 0x93, /* CPUMode write extended address */
};


static void check_rx()
{
	while (1) {
		uint8_t data;
		int rc = ftdi_read_data(&ftdic, &data, 1);
		if (rc <= 0)
			break;
		fprintf(stderr, "unexpected rx byte: %02X\n", data);
	}
}

static void error(int status)
{
	check_rx();
	fprintf(stderr, "ABORT.\n");
	if (ftdic_open) {
		if (ftdic_latency_set)
			ftdi_set_latency_timer(&ftdic, ftdi_latency);
		ftdi_usb_close(&ftdic);
	}
	ftdi_deinit(&ftdic);
	exit(status);
}

static uint8_t recv_byte()
{
	uint8_t data;
	while (1) {
		int rc = ftdi_read_data(&ftdic, &data, 1);
		if (rc < 0) {
			fprintf(stderr, "Read error.\n");
			error(2);
		}
		if (rc == 1)
			break;
		usleep(100);
	}
	return data;
}

static void send_byte(uint8_t data)
{
	int rc = ftdi_write_data(&ftdic, &data, 1);
	if (rc != 1) {
		fprintf(stderr, "Write error (single byte, rc=%d, expected %d).\n", rc, 1);
		error(2);
	}
}

static void set_gpio(bool sda, bool scl)
{
	uint8_t gpio = 0;
	if (sda) gpio |= 0x01; //BDBUS0
	if (scl) gpio |= 0x02; //BDBUS1
	send_byte(MC_SETB_LOW);
	send_byte(gpio);
	send_byte(0x03); //both outputs
}

static void i2c_start() {
	set_gpio(1, 1);
	set_gpio(0, 1);
	set_gpio(0, 0);
}

static void i2c_send(uint8_t data) {
	for (int i = 7; i >= 0; i--) {
		bool bit = (data >> i) & 0x1;
		set_gpio(bit, 0);
		set_gpio(bit, 1);
		set_gpio(bit, 0);
	}
	set_gpio(1, 0);
	set_gpio(1, 1);
	set_gpio(1, 0);
}

static void i2c_stop() {
	set_gpio(0, 0);
	set_gpio(0, 1);
	set_gpio(1, 1);
}

static void write_cmos_sensor(uint16_t addr, uint8_t value) {
	fprintf(stderr, "cam[0x%04X] <= 0x%02X\n", addr, value);
	i2c_start();
	i2c_send(0x10 << 1);
	i2c_send((addr >> 8) & 0xFF);
	i2c_send(addr & 0xFF);
	i2c_send(value);
	i2c_stop();
}

const int framelength = 666;
const int linelength = 3448;

static void cam_init() {
	// Based on "Preview Setting" from a Linux driver
	write_cmos_sensor(0x0100,  0x00); //standby mode
	write_cmos_sensor(0x30EB,  0x05); //mfg specific access begin
	write_cmos_sensor(0x30EB,  0x0C); //
	write_cmos_sensor(0x300A,  0xFF); //
	write_cmos_sensor(0x300B,  0xFF); //
	write_cmos_sensor(0x30EB,  0x05); //
	write_cmos_sensor(0x30EB,  0x09); //mfg specific access end
	write_cmos_sensor(0x0114,  0x01); //CSI_LANE_MODE: 2-lane
	write_cmos_sensor(0x0128,  0x00); //DPHY_CTRL: auto mode (?)
	write_cmos_sensor(0x012A,  0x18); //EXCK_FREQ[15:8] = 24MHz
	write_cmos_sensor(0x012B,  0x00); //EXCK_FREQ[7:0]
	write_cmos_sensor(0x0160,  ((framelength >> 8) & 0xFF)); //framelength
	write_cmos_sensor(0x0161,  (framelength & 0xFF));
	write_cmos_sensor(0x0162,  ((linelength >> 8) & 0xFF));
	write_cmos_sensor(0x0163,  (linelength & 0xFF));
	write_cmos_sensor(0x0164,  0x00); //X_ADD_STA_A[11:8]
	write_cmos_sensor(0x0165,  0x00); //X_ADD_STA_A[7:0]
	write_cmos_sensor(0x0166,  0x0A); //X_ADD_END_A[11:8]
	write_cmos_sensor(0x0167,  0x00); //X_ADD_END_A[7:0]
	write_cmos_sensor(0x0168,  0x00); //Y_ADD_STA_A[11:8]
	write_cmos_sensor(0x0169,  0x00); //Y_ADD_STA_A[7:0]
	write_cmos_sensor(0x016A,  0x07); //Y_ADD_END_A[11:8]
	write_cmos_sensor(0x016B,  0x80); //Y_ADD_END_A[7:0]
	write_cmos_sensor(0x016C,  0x02); //x_output_size[11:8] = 640
	write_cmos_sensor(0x016D,  0x80); //x_output_size[7:0]
	write_cmos_sensor(0x016E,  0x01); //y_output_size[11:8] = 480
	write_cmos_sensor(0x016F,  0xE0); //y_output_size[7:0]
	write_cmos_sensor(0x0170,  0x01); //X_ODD_INC_A
	write_cmos_sensor(0x0171,  0x01); //Y_ODD_INC_A
	write_cmos_sensor(0x0174,  0x02); //BINNING_MODE_H_A = x4-binning
	write_cmos_sensor(0x0175,  0x02); //BINNING_MODE_V_A = x4-binning
	write_cmos_sensor(0x018C,  0x08); //CSI_DATA_FORMAT_A[15:8]
	write_cmos_sensor(0x018D,  0x08); //CSI_DATA_FORMAT_A[7:0]
	write_cmos_sensor(0x0301,  0x08); //VTPXCK_DIV
	write_cmos_sensor(0x0303,  0x01); //VTSYCK_DIV
	write_cmos_sensor(0x0304,  0x03); //PREPLLCK_VT_DIV
	write_cmos_sensor(0x0305,  0x03); //PREPLLCK_OP_DIV
	write_cmos_sensor(0x0306,  0x00); //PLL_VT_MPY[10:8]
	write_cmos_sensor(0x0307,  0x14); //PLL_VT_MPY[7:0]
	write_cmos_sensor(0x0309,  0x08); //OPPXCK_DIV
	write_cmos_sensor(0x030B,  0x02); //OPSYCK_DIV
	write_cmos_sensor(0x030C,  0x00); //PLL_OP_MPY[10:8]
	write_cmos_sensor(0x030D,  0x0A); //PLL_OP_MPY[7:0]
	write_cmos_sensor(0x455E,  0x00); //??
	write_cmos_sensor(0x471E,  0x4B); //??
	write_cmos_sensor(0x4767,  0x0F); //??
	write_cmos_sensor(0x4750,  0x14); //??
	write_cmos_sensor(0x4540,  0x00); //??
	write_cmos_sensor(0x47B4,  0x14); //??
	write_cmos_sensor(0x4713,  0x30); //??
	write_cmos_sensor(0x478B,  0x10); //??
	write_cmos_sensor(0x478F,  0x10); //??
	write_cmos_sensor(0x4793,  0x10); //??
	write_cmos_sensor(0x4797,  0x0E); //??
	write_cmos_sensor(0x479B,  0x0E); //??
	
	//write_cmos_sensor(0x0157,  232); // ANA_GAIN_GLOBAL_A
	//write_cmos_sensor(0x0257,  232); // ANA_GAIN_GLOBAL_B

	
	//write_cmos_sensor(0x0600,  0x00); // Test pattern: disable
	//write_cmos_sensor(0x0601,  0x00); // Test pattern: disable

#if 0
	write_cmos_sensor(0x0600,  0x00); // Test pattern: solid colour
	write_cmos_sensor(0x0601,  0x01); //

	write_cmos_sensor(0x0602,  0x02); // Test pattern: red
	write_cmos_sensor(0x0603,  0xAA); //

	write_cmos_sensor(0x0604,  0x02); // Test pattern: greenR
	write_cmos_sensor(0x0605,  0xAA); //

	write_cmos_sensor(0x0606,  0x02); // Test pattern: blue
	write_cmos_sensor(0x0607,  0xAA); //

	write_cmos_sensor(0x0608,  0x02); // Test pattern: greenB
	write_cmos_sensor(0x0609,  0xAA); //


	write_cmos_sensor(0x0624,  0x0A); // Test pattern width
	write_cmos_sensor(0x0625,  0x00); //
	
	write_cmos_sensor(0x0626,  0x07); // Test pattern height
	write_cmos_sensor(0x0627,  0x80); //


#endif
	
	write_cmos_sensor(0x0100, 0x01);
}

int main() {
	enum ftdi_interface ifnum = INTERFACE_B;
	fprintf(stderr, "init..\n");
	ftdi_init(&ftdic);
	ftdi_set_interface(&ftdic, ifnum);

	if (ftdi_usb_open(&ftdic, 0x0403, 0x6010) && ftdi_usb_open(&ftdic, 0x0403, 0x6014)) {
		fprintf(stderr, "Can't find FTDI USB device (vendor_id 0x0403, device_id 0x6010 or 0x6014).\n");
		error(2);
	}

	if (ftdi_usb_reset(&ftdic)) {
		fprintf(stderr, "Failed to reset FTDI USB device.\n");
		error(2);
	}

	if (ftdi_usb_purge_buffers(&ftdic)) {
		fprintf(stderr, "Failed to purge buffers on FTDI USB device.\n");
		error(2);
	}

	if (ftdi_get_latency_timer(&ftdic, &ftdi_latency) < 0) {
		fprintf(stderr, "Failed to get latency timer (%s).\n", ftdi_get_error_string(&ftdic));
		error(2);
	}

	/* 1 is the fastest polling, it means 1 kHz polling */
	if (ftdi_set_latency_timer(&ftdic, 1) < 0) {
		fprintf(stderr, "Failed to set latency timer (%s).\n", ftdi_get_error_string(&ftdic));
		error(2);
	}

	if (ftdi_set_bitmode(&ftdic, 0xff, BITMODE_MPSSE) < 0) {
		fprintf(stderr, "Failed to set BITMODE_MPSSE on iCE FTDI USB device.\n");
		error(2);
	}

	// enable clock divide by 5
	send_byte(MC_TCK_D5);

	// set 6 MHz clock
	send_byte(MC_SET_CLK_DIV);
	send_byte(0x00);
	send_byte(0x00);

	cam_init();
}
