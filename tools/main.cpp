#include <linux/if_ether.h>
#define ETH_P_802_EX2	0x88B6 // second experimental ethtype missing from linux headers

#include "packets.hpp"

#include <iostream>

using namespace std;

int main(int argc, char * argv[]){
	if (argc != 3){
		cout << "Usage: " + string(argv[0]) + " <eth_intf> <asic_mac_addr>" << endl;
		exit(EXIT_FAILURE);
	}
}
