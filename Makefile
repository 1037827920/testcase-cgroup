export TST_TS_TOPDIR  := $(shell pwd)
DIRS := cmd testcase kmod
LIBS := tst_common tst_lib

all: libs
	@for d in $(DIRS); do \
		echo try make $$d; \
		make -C $$d all; \
		done

libs:
	@for d in $(LIBS); do \
		echo try make $$d; \
		make -C $$d all; \
		done

clean:
	@for d in $(DIRS) $(LIBS); do \
		echo try clean $$d; \
		make -C $$d clean; \
		done

cleanall:
	@for d in $(DIRS) $(LIBS); do \
		echo try cleanall $$d; \
		make -C $$d cleanall; \
		done
