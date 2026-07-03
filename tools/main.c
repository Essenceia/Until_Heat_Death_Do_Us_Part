#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <stdint.h> 
#include <arpa/inet.h>
#include <sys/ioctl.h>
#include <net/if.h> 
#include <string.h> 
#include <linux/if_packet.h> 
#include <net/if.h> 
#include <unistd.h> 

#include "eth_intf.h"
#include "packets.h" 

int main(int argc, char * argv[]){
	int sock; 
	int eth_intf_idx;
	char eth_intf_name[IFNAMSIZ] = {0};
	mac_addr_t device_mac_addr;
	mac_addr_t asic_mac_addr = DEFAULT_ASIC_MAC;

	if (argc < 2 || argc > 3){
		printf("Usage: %s eth_intf [asic_mac_addr]\nGot %d(%d) arguments\n", argv[0],argc - 1, argc);
		return -1;
	}
	printf("ethernet interface: %s\n", argv[1]);
	if (strlen(argv[1]) > IFNAMSIZ -1){
		printf("Missformed ethernet interface argument: %s", argv[1]);
	}
	strncpy(eth_intf_name, argv[1], IFNAMSIZ); 

	/* open raw socket */
	sock = socket(AF_PACKET, SOCK_RAW, htons(APP_ETHTYPE));
	if (sock < 0 ){
		printf("Socket creation failed, do you have the sufficent permissions ?\n");
		return -1;
	}
	/* resolve device mac addr */
	if (get_eth_intf_info(sock, eth_intf_name, &eth_intf_idx, device_mac_addr) < 0){ 
		printf("interface questing failed\n");
		return -1;
	}

	printf("%s mac address ", eth_intf_name);
	print_mac(device_mac_addr);

	/* validate command line argument for asic dst mac */
	if (argc > 2){
		if(parse_mac(argv[2], (uint8_t*)asic_mac_addr) < 0){
			printf("malformed mac address argument, got %s", argv[2]);
		}
	}
	printf("asic mac address ");
	print_mac(asic_mac_addr);
	printf("\n");

	/* receeive app packet */
	size_t rx_len; 	
	uint8_t rx_buff[APP_PACKET_LENGTH];
	app_packet_t rx_app_pkt;
	bool is_bcast;

	while(1){
		rx_len = recv(sock, rx_buff, APP_PACKET_LENGTH, 0);
        if (rx_len < 0) {
			printf("error no response received");
            break;
        }

		if (rx_len != sizeof(app_packet_t))printf("Error: unexpected packet length received, got %d expected %d", rx_len, sizeof(app_packet_t));
	
		memcpy(&rx_app_pkt, rx_buff, sizeof(app_packet_t));
		is_bcast = (rx_app_pkt.header.dst_mac[0] == 0xFF
					 && rx_app_pkt.header.dst_mac[1] == 0xFF
					 && rx_app_pkt.header.dst_mac[2] == 0xFF
					 && rx_app_pkt.header.dst_mac[3] == 0xFF
					 && rx_app_pkt.header.dst_mac[4] == 0xFF
					 && rx_app_pkt.header.dst_mac[5] == 0xFF);

		if(is_bcast) print_app_packet(&rx_app_pkt);	
	}
	//close(sock);
	return 0;
}
