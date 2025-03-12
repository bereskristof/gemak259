CC := gcc
CC_FLAGS := -std=c23 -pedantic -fdiagnostics-color=always -I../include -L../include -lutils -lopencl -Wall -Wextra

.PHONY: default clean

default: generate_file main
	./generate_file

generate_file: generate_file.c
	$(CC) generate_file.c -o generate_file $(CC_FLAGS) -O3

main: main.c
	$(CC) main.c -o main $(CC_FLAGS)

clean:
	rm -f main generate_file dummy_file.bin
