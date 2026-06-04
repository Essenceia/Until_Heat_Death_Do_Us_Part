# ASIC software interface

Comunicated with the ASIC over ethernet frames, POSIX compatible. 

## Payload layouts 


### Configuration

Header : 
- dst mac: current ASIC dst mac 
- vid: none or currentl ASIC vid
- ethtype: `CONF_ETHTYPE` (`x88B6`)

```
[ mac_addr [47:0] (48b) ][ padding (4b) ][ vid [11:0] ][ padding (7b) ][ phase (1b) ][ padding ]
0
```

### Application

#### Request 

Header : 
- dst mac: current ASIC dst mac
- src mac: sender mac 
- vid: none or currentl ASIC vid
- ethtype: `APP_ETHTYPE` (`x88B5`)

```
[ A [15:0] (16b) ][ B [15:0] (16b) ][ padding ]
0
```

#### Response 


```
C = A*B 
```

Header : 
- dst mac: send mac 
- src mac: current ASIC dst mac
- vid: none 
- ethtype: `APP_ETHTYPE` (`x88B5`)

```
[ C [15:0] (16b) ][ padding ]
0
```


