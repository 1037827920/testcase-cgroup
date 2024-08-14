# General Purpose Makefile for Linux Kernel module  
# 以下编译适合于在内核代码树之外编译内核模块。
# 整个过程会导致本Makefile文件被加载执行两遍。
# 第一遍执行时，由于`KERNELRELEASE`没有被定义，所以先执行`else`下的逻辑。
# `-C $(KERNEL_DIR)`指明跳转到内核源码目录下读取那里的Makefile；
# `M=$(CURDIR)`表明然后返回到当前目录继续读入当前的Makefile并执行之。此为第二遍执行。
# 第二遍执行时，此时从内核源码目录返回时，KERNELRELEASE已被被定义，
# kbuild也被启动去解析kbuild语法的语句，make将继续读取else之前的内容。
# else之前的内容为kbuild语法的语句, 指明模块源码中各文件的依赖关系，以及要生成的目标模块名。

CURDIR        ?= $(shell pwd)
KERNEL_VER    := $(shell uname -r)
KERNEL_DIR    ?= /lib/modules/$(KERNEL_VER)/build
export ALL_SRC       ?= $(filter-out %.mod.c, $(wildcard *.c))
export ALL_OBJ       ?= $(patsubst %.c,%.o,$(ALL_SRC))
export ALL_MOD       ?= $(patsubst %.o,%.ko,$(ALL_OBJ))

ifneq ($(KERNELRELEASE),)
	obj-m += $(ALL_OBJ)
else
all:
	$(MAKE) -C $(KERNEL_DIR) M=$(CURDIR) modules
endif

clean:                                     
	$(MAKE) -C $(KERNEL_DIR) M=$(CURDIR) clean  

cleanall: clean
