#include "packets.h"
#include <string.h> 
#include <arpa/inet.h>
#include <stdlib.h> 
#include <stdio.h>

void set_header(eth_header_t* header, 
	mac_addr_t dst, mac_addr_t src, uint16_t ethtype)
{
	memcpy(header->dst_mac, dst, MAC_W);
	memcpy(header->src_mac, src, MAC_W);
	header->ethtype = ethtype;
}

uint8_t* create_app_packet(
	mac_addr_t dst_mac, mac_addr_t src_mac, 
	uint16_t a, uint16_t b)
{
	app_packet_t pkt; 
	memset(&pkt, 0, APP_PACKET_LENGTH);// set padding to 0, cleaner to read pcaps, no functional value
	set_header(&pkt.header, dst_mac, src_mac, htons(APP_ETHTYPE));
	pkt.a = htons(a);
	pkt.b = htons(b); 
	uint8_t *raw = (uint8_t*)malloc(APP_PACKET_LENGTH);
	memcpy(raw, &pkt, APP_PACKET_LENGTH);
	return raw; 
}

void print_packet(uint8_t *pkt, size_t pkt_lenght){
	assert(pkt); 
	printf("print packet: 0x");
	for(size_t i=0; i< pkt_lenght; i++){
		printf("%02x", pkt[i]);
	}
}
