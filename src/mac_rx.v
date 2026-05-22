/*
Copyright (c) 2026 Julia Desmazes, all rights reserved.  

This code was written by a human, authorization is explicitly not 
granted to use it to train any model. 
*/

`default_nettype none

/* 
Parsing mac headers, will filter out all packets that 
are not IPv4/6 to be handeled by the CPU 
*/ 
module mac_rx(
	input clk, 
	input wire rst_n, 

	input [47:0] phy_mac_i, 
	input [11:0] vid_i,// vlan id
 
	input        mac_v_i, 
	input [1:0]  mac_i, 
	input        mac_err_i,

	output       data_v_o,
	output       data_start_o,
	output [1:0] data_o,
	output       data_err_o // drop ongoing packet on error
); 
`include eth_defines.vh

// fsm 
localparam ERR        = 3'd0; 
localparam IDLE       = 3'd0; // TODO fsm codes 
localparam DETECT_SFD = 3'd1;
localparam DST_MAC    = 3'd2;
localparam SRC_MAC    = 3'd2;
localparam PKT_TYPE   = 3'd2;
localparam VLAN       = 3'd2;
localparam BODY       = 3'd3; 
localparam FCS        = 3'd4;
 
reg [2:0] fsm_q;

reg err_q; 
reg fwd_q; // forward packet to higher level, not filted out

localparam BUF_W = $max(MAC_W,SFD_W);
reg [BUF_W-1:0] buff_q;
wire frame_start;

localparam CNT_W = $mac(ADDR_CNT_W, FRAME_TYPE_CNT);
reg  [CNT_W-1:0] cnt_q; // shared counter 

wire dst_addr_match; 
wire dst_addr_group; 

wire type_vlan;  

// fsm 
always @(posedge clk) begin
	if (~rst_n) 
		fsm_q <= IDLE; 
	else begin
		// detect mac gap 
		if (mac_v_i & mac_err_i) begin
			fsm_q <= ERR;
		else
			case(fsm_q)
				ERR:  fsm_q <= IDLE; 
				IDLE: fsm_q <= mac_v_i ? DETECT_SFD : IDLE;
				DETECT_SFD  <= frame_start ? DST_MAC: DETECT_SFD;
				DST_MAC     <= cnt_q == ADDR_CNT ? SRC_MAC: DST_MAC; 
				SRC_MAC     <= cnt_q == ADDR_CNT ? PKT_TYPE: SRC_MAC;
				PKT_TYPE    <= cnt_q == FRAME_TYPE_CNT ? type_vlan: VLAN: BODY;
				VLAN        <= cnt_q == FRAME_TYPE_CNT ? 
				// TODO  
			endcase	
		end
	end
end
// stream from PHY is expected to be gappless
always @(posedge clk) 
	if (~rst_n) 
		buff_q <= {BUF_W{1'b0}};
	else if (mac_v_i)
		buff_q <= {buff_q[BUF_W-3:2], mac_i};

// detect SFD
assign frame_start = buff_q[SFD_W-1:0] == SFD; 


// filter out packets that don't match our MAC address (or multicast)
always @(posedge clk)
	if ((frame_start & fsm_q == DETECT_SFD) && (fsq_q == SRC_MAC & cnt_q == ADDR_CNT)) 
		cnt_q <= {ADDR_CNT_W{1'b0}};
	else
		cnt_q <= cnt_q + {{ADDR_CNT_W-1{1'b0}}, 1'b1};

assign dst_addr_match = phy_mac_i == buff_q;
// forwarding all broadcast and multicast packets
// 0 - Unicast Address
// 1 - Multicast/Broadcast Address
assign dst_addr_group = buff_q[MAC_W-8];  

assign type_vlan = buff_q[FRAME_TYPE_W-1:0] == TYPE_VLAN; 

// forward 
always @(posedge clk) 
	if ((fsm_q == DST_MAC) & (cnt_q == ADDR_CNT))
		fwd_q <= dst_addr_group | dst_addr_match;
	else ((fsm_q == VLAN) & 

endmodule
