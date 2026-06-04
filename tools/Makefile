BIN_NAME=test
SRC=$(wildcard *.cpp) $(wildcard *.hpp)

.PHONY: build clean 

build: ${SRC}
	g++ -std=c++23 -o ${BIN_NAME} ${SRC}

clean:
	rm -f ./${BIN_NAME}
