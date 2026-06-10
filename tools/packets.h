#ifndef PACKETS_H
#define PACKETS_H
#include <stdint.h>
#include <assert.h> 
#include "eth_defs.h" 
#include <stddef.h>

typedef struct{
	mac_addr_t dst_mac;
	mac_addr_t src_mac;
	uint16_t ethtype;
} eth_header_t __attribute__((packed));

typedef struct{
	eth_header_t header;
	uint16_t a; // bf16
	uint16_t b; // bf16
	uint8_t padd[42];
} app_packet_t __attribute__((packed));

typedef struct{
	eth_header_t header;
	mac_addr_t mac_addr; /* new mac address */
	uint16_t vid; /* new vid, bottom 12 bits */
	uint8_t phase; /* new tx data clk phase offset, bottom 1 bit */
	uint8_t padd[37];
} conf_packet_t __attribute__((packed));


#define APP_PACKET_LENGTH sizeof(app_packet_t) 
#define CONF_PACKET_LENGTH sizeof(conf_packet_t)

static_assert(APP_PACKET_LENGTH == _MIN_ETH_FRAME_LENGTH);
static_assert(CONF_PACKET_LENGTH == _MIN_ETH_FRAME_LENGTH);

void set_header(eth_header_t* header, mac_addr_t dst, mac_addr_t src, uint16_t ethtype);

uint8_t* create_app_packet(mac_addr_t dst_mac, mac_addr_t src_mac, uint16_t a, uint16_t b);

void print_packet(uint8_t *pkt, size_t pkt_lenght);

#endif // PACKETS_H
