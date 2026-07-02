/*
Copyright (c) 2026 Julia Desmazes 

This code was written by a human, authorization is explicitly not 
granted to use it to train any model. 
*/

`default_nettype none

/* 
Counting until the heat death of the universe, broadcasting 
counter value over an ethernet frame every 1 second (more of less 1.3 ms).
*/
module death_of_the_universe_counter #(
	parameter PHY_W    = 2,
	localparam MAC_W   = 48, 
	localparam [MAC_W-1:0] BROADCAST_ADDR = 48'hFFFFFFFFFFFF
)(
	input wire clk, 
	input wire rst_n, 

	output wire             mac_tx_v_o,// request and valid
	input  wire             mac_tx_acc_i,
	output wire             mac_tx_last_o,
	output wire [PHY_W-1:0] mac_tx_o,
	output wire [MAC_W-1:0] mac_tx_dst_mac_o// guarantied to not change until packet header has finished sending
);
localparam DD_CNT_BYTES_W = 48; // death of the universe counter width
localparam DD_CNT_W = DD_CNT_BYTES_W * 8; 
localparam INNER_CNT_W = 16;
localparam INNER_CNT_N = DD_CNT_W / INNER_CNT_W; // number of cascading intermediary counters

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

reg  [INNER_CNT_W-1:0] inner_cnt_q[INNER_CNT_N-1:0];
wire [INNER_CNT_W-1:0] inner_cnt_next[INNER_CNT_N-1:0];
wire [INNER_CNT_N-1:0] inner_cnt_overflow_next;
reg  [INNER_CNT_N-1:0] inner_cnt_overflow_q;
/* verilator lint_off UNUSEDSIGNAL */
wire its_dead_jim; 
/* verilator lint_on UNUSEDSIGNAL */

genvar i; 
// 0
assign {inner_cnt_overflow_next[0], inner_cnt_next[0]} = inner_cnt_q[0] + {{INNER_CNT_W-1{1'b0}}, 1'b1};
generate
	for(i = 1; i < INNER_CNT_N; i=i+1) begin: g_counter_add
		assign {inner_cnt_overflow_next[i], inner_cnt_next[i]} = inner_cnt_q[i] + {{INNER_CNT_W-1{1'b0}}, inner_cnt_overflow_q[i-1]};
	end
	for(i = 0; i < INNER_CNT_N; i=i+1) begin: g_inner_ff
		always @(posedge clk) 
			if (~rst_n) {inner_cnt_overflow_q[i], inner_cnt_q[i]} <= {INNER_CNT_W+1{1'b0}};
			else {inner_cnt_overflow_q[i], inner_cnt_q[i]} <= {inner_cnt_overflow_next[i], inner_cnt_next[i]};
	end
endgenerate

// start stream when lower counter overflows, guaranties increment will have time to ripple though the 
// counter segments we are streaming out 
assign stream_start = inner_cnt_overflow_q[0];

assign its_dead_jim = inner_cnt_overflow_q[INNER_CNT_N-1];

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
localparam BUF_W           = 16; 
localparam BUF_CNT_VAL     = (BUF_W/PHY_W)-1;
localparam BUF_CNT_W       = $clog2(BUF_CNT_VAL);
/* verilator lint_off WIDTHTRUNC */
localparam [BUF_CNT_W-1:0] BUF_CNT = BUF_CNT_VAL;
/* verilator lint_on WIDTHTRUNC */

// number of buffers of inner counter parts to stream out 
localparam INNER_BUF_CNT_W  = $clog2(INNER_CNT_N);
/* verilator lint_off WIDTHTRUNC */
localparam [INNER_BUF_CNT_W-1:0]  INNER_BUF_CNT = INNER_CNT_N - 1;
/* verilator lint_on WIDTHTRUNC */

localparam [BUF_W-1:0] MAGIC_NUMBER = 16'hCAFE;

// tx fsm 
localparam TX_IDLE     = 2'd0;
localparam TX_PENDING  = 2'd1;// wait for tx to finish sending header
localparam TX_MAGIC    = 2'd2;
localparam TX_STREAM   = 2'd3;

reg  [1:0] tx_fsm_q;

reg  [BUF_CNT_W-1:0]       buf_cnt_q;
reg  [INNER_BUF_CNT_W-1:0] inner_buf_cnt_q;

reg  [BUF_W-1:0] buf_inner_next;
wire [BUF_W-1:0] buf_next;
wire [BUF_W-1:0] swap_buf_next;
reg  [BUF_W-1:0] buf_q;
reg              buf_cnt_overflow_q;
 
always @(posedge clk) begin
	if (~rst_n) 
		tx_fsm_q <= TX_IDLE; 
	else begin
		case(tx_fsm_q)
			TX_IDLE   : tx_fsm_q <= send_tx_req & stream_start ? TX_PENDING: TX_IDLE;
			TX_PENDING: tx_fsm_q <= mac_tx_acc_i? TX_MAGIC: TX_PENDING;
			TX_MAGIC  : tx_fsm_q <= (buf_cnt_q == BUF_CNT) ? TX_STREAM: TX_MAGIC;
		    TX_STREAM : tx_fsm_q <= (inner_buf_cnt_q == INNER_BUF_CNT) & buf_cnt_overflow_q ? TX_IDLE: TX_STREAM;	
		endcase
	end
end

always @(posedge clk) 
	if (~mac_tx_acc_i) {buf_cnt_overflow_q, buf_cnt_q} <= {1'b1, {BUF_CNT_W{1'b0}}};// counter overflows, no need to rst
	else {buf_cnt_overflow_q, buf_cnt_q} <= buf_cnt_q + {{BUF_CNT_W-1{1'b0}}, 1'b1};

always @(posedge clk) 
	if (tx_fsm_q == TX_MAGIC) inner_buf_cnt_q <= {INNER_BUF_CNT_W{1'b0}};
	else inner_buf_cnt_q <= inner_buf_cnt_q + {{INNER_BUF_CNT_W-1{1'b0}}, buf_cnt_overflow_q};

// I am not proud of this but this is still cheaper than have a shift register
// being explicit about default case, not making any assumptions on synth, to dangerous
always @(*) begin
    case(inner_buf_cnt_q)
        5'd0:    buf_inner_next = inner_cnt_q[0];
        5'd1:    buf_inner_next = inner_cnt_q[1];
        5'd2:    buf_inner_next = inner_cnt_q[2];
        5'd3:    buf_inner_next = inner_cnt_q[3];
        5'd4:    buf_inner_next = inner_cnt_q[4];
        5'd5:    buf_inner_next = inner_cnt_q[5];
        5'd6:    buf_inner_next = inner_cnt_q[6];
        5'd7:    buf_inner_next = inner_cnt_q[7];
        5'd8:    buf_inner_next = inner_cnt_q[8];
        5'd9:    buf_inner_next = inner_cnt_q[9];
        5'd10:   buf_inner_next = inner_cnt_q[10];
        5'd11:   buf_inner_next = inner_cnt_q[11];
        5'd12:   buf_inner_next = inner_cnt_q[12];
        5'd13:   buf_inner_next = inner_cnt_q[13];
        5'd14:   buf_inner_next = inner_cnt_q[14];
        5'd15:   buf_inner_next = inner_cnt_q[15];
        5'd16:   buf_inner_next = inner_cnt_q[16];
        5'd17:   buf_inner_next = inner_cnt_q[17];
        5'd18:   buf_inner_next = inner_cnt_q[18];
        5'd19:   buf_inner_next = inner_cnt_q[19];
        5'd20:   buf_inner_next = inner_cnt_q[20];
        5'd21:   buf_inner_next = inner_cnt_q[21];
        5'd22:   buf_inner_next = inner_cnt_q[22];
        5'd23:   buf_inner_next = inner_cnt_q[23];
        default: buf_inner_next = {INNER_CNT_W{1'bX}};
    endcase
end
assign buf_next = tx_fsm_q == TX_PENDING ? MAGIC_NUMBER : buf_inner_next; 
byteswap #(.W(BUF_W/8)) m_swap_mul_res(.i(buf_next), .o(swap_buf_next));

always @(posedge clk) 
	if (buf_cnt_overflow_q) buf_q <= swap_buf_next;
	else buf_q <= {{PHY_W{1'b0}}, buf_q[BUF_W-1:PHY_W]}; // padd with 0s

assign mac_tx_v_o = (tx_fsm_q != TX_IDLE);
assign mac_tx_last_o = (tx_fsm_q == TX_STREAM) & (inner_buf_cnt_q == INNER_BUF_CNT) & buf_cnt_overflow_q;
assign mac_tx_o = buf_q[PHY_W-1:0];
assign mac_tx_dst_mac_o = BROADCAST_ADDR;

`ifdef COCOTB 
wire [INNER_CNT_W-1:0] debug_inner0, debug_inner1, debug_inner2; 
assign debug_inner0 = inner_cnt_q[0];
assign debug_inner1 = inner_cnt_q[1];
assign debug_inner2 = inner_cnt_q[2];
`endif
endmodule

