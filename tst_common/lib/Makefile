export TST_COMMON_TOPDIR  ?= $(shell pwd)/..
include $(TST_COMMON_TOPDIR)/Makefile.common
ALL_SRC       := $(wildcard *.c)
ALL_OBJ       := $(patsubst %.c,%.o,$(ALL_SRC))
LIB_STATIC    := libcommon.a
CFLAGS        +=

all: $(LIB_STATIC)

$(LIB_STATIC): $(ALL_OBJ)
	ar -rc $(LIB_STATIC) $(ALL_OBJ)

$(ALL_OBJ):%.o:%.c
	$(CC) $(CFLAGS) -c $^ -o $@

clean:
	rm -rfv $(LIB_STATIC) $(ALL_OBJ)

cleanall: clean
	rm -rfv __pycache__
