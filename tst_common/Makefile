export TST_COMMON_TOPDIR  := $(shell pwd)
DIRS := cmd testcase kmod
LIBS := lib

all: libs
	@for d in $(DIRS); do \
		echo try make common $$d; \
		make -C $$d all; \
		done

libs:
	@for d in $(LIBS); do \
		echo try make common $$d; \
		make -C $$d all; \
		done

clean:
	@for d in $(DIRS) $(LIBS); do \
		echo try clean common $$d; \
		make -C $$d clean; \
		done

cleanall:
	@for d in $(DIRS) $(LIBS); do \
		echo try cleanall common $$d; \
		make -C $$d cleanall; \
		done
