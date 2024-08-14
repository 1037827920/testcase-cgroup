export TST_COMMON_TOPDIR  ?= $(shell pwd)/..
include $(TST_COMMON_TOPDIR)/Makefile.common
ALL_SRC       := $(wildcard *.c)
ALL_OBJ       := $(patsubst %.c,%.o,$(ALL_SRC))
ALL_BIN       := $(patsubst %.o,%.cmd,$(ALL_OBJ))
CFLAGS        +=
LDFLAGS       +=

all: $(ALL_BIN)

$(ALL_BIN):%.cmd:%.o
	$(CC) $^ -o $@ $(LDFLAGS)

$(ALL_OBJ):%.o:%.c
	$(CC) $(CFLAGS) -c $^ -o $@

clean:
	rm -rfv $(ALL_OBJ) $(ALL_BIN)

cleanall: clean
