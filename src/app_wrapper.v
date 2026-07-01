/*
Copyright (c) 2026 Julia Desmazes 

This code was written by a human, authorization is explicitly not 
granted to use it to train any model. 
*/

`default_nettype none

/* 
Counting until the heat death of the universe, broadcasting 
counter value over an ethernet frame every 1 second (more of less 1.3 ms).

No need to check tx accept since we will be sending only 1 packet every 
second, clearly no risk of violating the ethernet IPG. 
*/
module app_wrapper #(
	parameter PHY_W = 2,
	localparam FREQ_HZ = 50000000;
	localparam MAC_W = 48, 
	localparam [MAC_W-1:0] BROADCAST_ADDR = 48'hFFFFFFFFFFFF
)(
	input wire clk, 
	input wire rst_n, 

	output wire             mac_tx_v_o,// request and valid
	output wire             mac_tx_last_o,
	output wire [PHY_W-1:0] mac_tx_o,
	output wire [MAC_W-1:0] mac_tx_dst_mac_o// guarantied to not change until packet header has finished sending
);
localparam DD_CNT_BYTES_W = 48; // death of the universe counter width
localparam DD_CNT_W = DD_CNT_BYTES_W * 8; 
localparam INTER_CNT_W = 16;
localparam INTER_CNT_N = DD_CNT_W / INTER_CNT_W; // number of cascading intermediary counters

// 1s update pending trigger
wire send_tx_req; 
wire stream_start; 

broadcast_timer m_1s_timer(
	.clk(clk), 
	.rst_n(rst_n),
	.update_finished_i(stream_start),
	.update_req_o(send_tx_req)
);

/* cold freeze counter */

// TODO 
wire [15:0] mul_res;
assign mul_res = {16{1'b0}};


/* TX 

streamed out packet, no need to add padding to make this a legal ethernet frame: 
[ counter 48 bytes ]
0                383 

[ inter 0 16b ][ inter 1 16b ][ inter 2 16b ]     ... [ inter 23 16b ]
0             15             31             47                     383
 
intermediary counters follow little endian with a granule size of 1 contention, eg with
inter 0:      
[ inter 0 [7:0] 8b ][ inter 0 [15:8] 8b]
0                  7                  15

this is accomplished by the byteswap module
*/
localparam ETH_FRAME_MIN_W = DD_CNT_W;
localparam FRAME_CNT_VAL   = (ETH_FRAME_MIN_W/PHY_W)-1;
localparam FRAME_CNT_W     = $clog2(FRAME_CNT_VAL);
localparam BUF_W           = INTER_CNT_W;
/* verilator lint_off WIDTHTRUNC */
localparam [FRAME_CNT_W-1:0]   FRAME_CNT   = FRAME_CNT_VAL;
/* verilator lint_on WIDTHTRUNC */

// tx fsm 
localparam TX_IDLE    = 2'b00;
localparam TX_PENDING = 2'b01;
localparam TX_STREAM  = 2'b11;

reg  [1:0] tx_fsm_q;
reg  [FRAME_CNT_W-1:0] tx_cnt_q;
wire [BUF_W-1:0] swap_buf_next;
reg  [BUF_W-1:0] buf_q;
 
always @(posedge clk) begin
	if (~rst_n) 
		tx_fsm_q <= TX_IDLE; 
	else begin
		case(tx_fsm_q)
			TX_IDLE   : tx_fsm_q <= (rx_fsm_q == RX_READY) & ~data_err_i? TX_CAPTURE: TX_IDLE;
			TX_CAPTURE: tx_fsm_q <= TX_REQ;
			TX_REQ    : tx_fsm_q <= mac_tx_acc_i? TX_STREAM: TX_REQ;
		    TX_STREAM : tx_fsm_q <= (tx_cnt_q == FRAME_CNT) ? TX_IDLE: TX_STREAM;	
		endcase
	end
end

always @(posedge clk) 
	if (tx_fsm_q == TX_REQ) tx_cnt_q <= {FRAME_CNT_W{1'b0}};
	else if (mac_tx_acc_i) tx_cnt_q <= tx_cnt_q + {{FRAME_CNT_W-1{1'b0}}, 1'b1};

byteswap #(.W(BUF_W/8)) m_swap_mul_res(.i(mul_res), .o(swap_buf_next));

always @(posedge clk) 
	if (tx_fsm_q == TX_CAPTURE) buf_q <= swap_buf_next;
	else if (tx_fsm_q == TX_STREAM) buf_q <= {{PHY_W{1'b0}}, buf_q[BUF_W-1:PHY_W]}; // padd with 0s

assign mac_tx_v_o = (tx_fsm_q == TX_REQ) | (tx_fsm_q == TX_STREAM);
assign mac_tx_last_o = (tx_fsm_q == TX_STREAM) & (tx_cnt_q == FRAME_CNT);
assign mac_tx_o = buf_q[PHY_W-1:0];
assign mac_tx_dst_mac_o = BROADCAST_ADDR;

endmodule

