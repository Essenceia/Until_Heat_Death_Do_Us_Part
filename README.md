# Teapot Project


## Assumptions 

This ASIC will be supporting 100Mbps ethernet using the following assumptions: 
- PHY will be implemented used the microchip LAN8720A(I) chips
- External network is full duplex 
		- dropping CRS support in asic 
- No 10Mbps support
	- dissabling auto-negociation
- clk is provided to the ASIC AND the LAN8720A by a 50MHz oscillator
	- clk is not driven by the rpi
