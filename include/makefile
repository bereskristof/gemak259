CC := gcc
CC_FLAGS := -std=c23 -pedantic -fdiagnostics-color=always -lopencl -Wall -Wextra

.PHONY: default windows unix clean

default: libutils.a

windows: libutils.a

unix: libutils.a

libutils.a: utils.c
	$(CC) -c utils.c -o utils.o $(CC_FLAGS)
	ar rcs libutils.a utils.o

clean:
	rm -f libutils.a utils.o
