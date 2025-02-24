MAKE := make
PATHS := include/ week01/ week01/task02/ week01/task04/ week01/task08/
MAKE_TARGET = windows

.PHONY: default all clean-all

default: all

all:
	for path in $(PATHS); do\
		$(MAKE) -C $$path;\
	done

clean-all:
	for path in $(PATHS); do\
		$(MAKE) clean -C $$path;\
	done
