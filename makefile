MAKE := make
PATHS := include/ week01/task02/ week01/task04/ week01/task08/
MAKE_TARGET = windows

.PHONY: default all-windows all-unix all-clean

default: all-windows

all-windows:
	for path in $(PATHS); do\
		$(MAKE) windows -C $$path;\
	done

all-unix:
	for path in $(PATHS); do\
		$(MAKE) unix -C $$path;\
	done

all-clean:
	for path in $(PATHS); do\
		$(MAKE) clean -C $$path;\
	done
