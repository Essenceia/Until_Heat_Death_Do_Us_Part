#include "packets.h"
#include <string.h> 
#include <arpa/inet.h>
#include <stdlib.h> 
#include <stdio.h>
#include "eth_intf.h"

void set_header(eth_header_t* header, 
	mac_addr_t dst, mac_addr_t src, uint16_t ethtype)
{
	memcpy(header->dst_mac, dst, MAC_W);
	memcpy(header->src_mac, src, MAC_W);
	header->ethtype = ethtype;
}

void print_raw_packet(uint8_t *pkt, size_t pkt_lenght){
	assert(pkt); 
	for(size_t i=0; i< pkt_lenght; i++){
		printf("%02x", pkt[i]);
	}
}

void print_header(eth_header_t h){
	printf("dst mac ");
	print_mac(h.dst_mac);
	printf("src mac ");
	print_mac(h.src_mac);
	printf("ethtype %04x\n", htons(h.ethtype));
}

#ifdef TESTING
uint64_t debug_cnt = 0; 
#endif

void print_app_packet(app_packet_t *pkt){
	uint64_t cnt; 
	print_header(pkt->header);
	if (pkt->magic_number == MAGIC_NUMBER){
		memcpy(&cnt, pkt->counter, sizeof(uint64_t));
		printf("counter: %lu\n", cnt);
		#ifdef TESTING
		printf("counter debug: 0x%016x\n",cnt);
		assert(debug_cnt < cnt);
		debug_cnt = cnt; 
		#endif
	}else{
		printf("not our packet, missformed magic number %04x, expecting %04x", htons(pkt->magic_number), MAGIC_NUMBER);
	}
	printf("raw pkt: ");
	print_raw_packet((uint8_t*)pkt, APP_PACKET_LENGTH);
	printf("\n\n");
}
