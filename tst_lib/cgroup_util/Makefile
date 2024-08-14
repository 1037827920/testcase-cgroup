SRC_DIR := .
BIN_DIR := ./bin
CC := gcc
CFLAGS := -O2

SRC_FILES := $(wildcard $(SRC_DIR)/*.c)
BIN_FILES := $(patsubst $(SRC_DIR)/%.c,$(BIN_DIR)/%,$(SRC_FILES))

# 目标文件
all: $(BIN_FILES)

$(BIN_DIR)/%: $(SRC_DIR)/%.c | $(BIN_DIR)
	$(CC) $(CFLAGS) -o $@ $<

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

clean:
	rm -rf $(BIN_DIR)

.PHONY: all clean