/*
Copyright (c) 2026 Julia Desmazes 

This code was written by a human, authorization is explicitly not 
granted to use it to train any model. 
*/

`default_nettype none

// FCC hold my beer 
module tt_um_teapot (
    input  wire [7:0] ui_in,    
    output wire [7:0] uo_out,   
    input  wire [7:0] uio_in,   
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

// rmii 
rmii m_rmii(
	.clk(clk),
	.rst_n(rst_n),

	.phy_rst_n_o(),
	.rx_v_dir_o(),
	.rx_dir_o(),
	.rx_v_o(),
	.rx_o(),

	.tx_en_o(),
	.tx_o(),

	.rx_v_i(),
	.rx_i(),
	.rx_err_i(),

	.mac_rx_v_o(),
	.mac_rx_o(),
	.mac_rx_err_o(),

	.mac_tx_v_i(),
	.mac_tx_i()
);

// mac config 

// rx mac 
mac_rx m_mac_rx(
	.clk(clk),
	.rst_n(rst_n),

	.phy_mac_i(),
	.vid_i(),

	.rx_v_i(),
	.rx_i(),
	.rx_err_i(),

	.mcu_cmd_o(),
	.mcu_o()
);

// rx rpi

// tx mac

// tx rpi


endmodule
