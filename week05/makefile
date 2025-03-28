CC := gcc
CC_FLAGS := -std=c23 -pedantic -fdiagnostics-color=always -I../include -L../include -lutils -lopencl -Wall -Wextra

.PHONY: default clean

default: main.c
	$(CC) main.c -o main $(CC_FLAGS)

clean:
	rm -f main
