MAKE := make
PATHS := include/ week01/ week01/task02/ week01/task04/ week01/task08/ week02/ week03/

.PHONY: default all clean

default: all

all:
	for path in $(PATHS); do\
		$(MAKE) -C $$path;\
	done

clean:
	for path in $(PATHS); do\
		$(MAKE) clean -C $$path;\
	done
