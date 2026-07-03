BIN_NAME=packet_receiver
DEFAULT_ETH=wlp3s0

SRC_C := $(wildcard *.c)

OBJ:=$(SRC_C:.c=.c.o)

$(info obj $(OBJ))

.PHONY: build clean trace run

# implicit rules 
# all c objects 
%.c.o: %.c
	gcc $(C_FLAGS) -o $@ -c $<

$(BIN_NAME): $(OBJ) 
	gcc -o $@ $(OBJ)

build: $(BIN_NAME) 

#debug network socket/connection failures
trace: build 
	strace ${BIN_NAME} ${ARGS}

run: build
	sudo ./${BIN_NAME} ${DEFAULT_ETH}
 
clean:
	rm -f ./${BIN_NAME}
	rm -f ./vgcore*
	rm -f ./*.o
