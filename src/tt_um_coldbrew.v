/*
Copyright (c) 2026 Julia Desmazes 

This code was written by a human, authorization is explicitly not 
granted to use it to train any model. 
*/

`default_nettype none

module tt_um_coldbrew #(
	parameter  PHY_W = 2,
	localparam MAC_W = 48,
	parameter [MAC_W-1:0] DEFAULT_MAC = 48'h0090CF00BEEF // nortel manifacturer
)(
	input  wire [7:0] ui_in,    
    output wire [7:0] uo_out,   
    input  wire [7:0] uio_in,   
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
// IO
wire [7:0] uio_in_unused;
assign uio_oe        = 8'd0;
assign uio_out       = 8'd0;
assign uio_in_unused = uio_in;

// IN
(* MARK_DEBUG = "true" *) wire             phy_rx_v;
(* MARK_DEBUG = "true" *) wire [PHY_W-1:0] phy_rx;
(* MARK_DEBUG = "true" *) wire             phy_rx_err;

wire [2:0] ui_unused;
wire tx_phase; 

assign phy_rx     = ui_in[1:0];
assign phy_rx_v   = ui_in[2];
assign phy_rx_err = ui_in[3];
assign ui_unused  = ui_in[6:4];
assign tx_phase   = ui_in[7]; 

// OUT 
wire [1:0] phy_tx;
wire       phy_tx_v;

assign uo_out[1:0] = phy_tx;
assign uo_out[2]   = phy_tx_v;
assign uo_out[7:3] = 5'd0;

// misc
wire ena_unused; 
assign ena_unused = ena; 

// wrap coldbrew 
coldbrew #(.PHY_W(PHY_W), .DEFAULT_MAC(DEFAULT_MAC), .HAS_TX_PHASE(1)) m_coldbrew(
	.clk(clk), 
	.rst_n(rst_n),

	.tx_phase_i(tx_phase),
	
	.phy_rx_i(phy_rx), 
	.phy_rx_v_i(phy_rx_v), 
	.phy_rx_err_i(phy_rx_err),
	
	.phy_tx_o(phy_tx),
	.phy_tx_v_o(phy_tx_v)
);

endmodule
