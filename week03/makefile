CC := gcc
CC_FLAGS := -std=c23 -pedantic -fdiagnostics-color=always -I../include -L../include -lutils -lopencl -Wall -Wextra

.PHONY: default clean

default: generate_file.c
	$(CC) generate_file.c -o generate_file $(CC_FLAGS) -O3

clean:
	rm -f main.exe main
