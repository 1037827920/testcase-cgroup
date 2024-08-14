#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define PAGE_SIZE 4096  // 页大小

// 分配匿名内存并初始化
int alloc_anon(size_t mb) {
    size_t size = mb * 1024 * 1024; 
    char *buf;
    char *ptr;

    // 分配内存
    buf = malloc(size);
    if (buf == NULL) {
        perror("malloc 失败");
        return -1;
    }

    // 初始化分配的内存
    memset(buf, 0, size);

    // 访问内存以确保它正在被使用
    for (ptr = buf; ptr < buf + size; ptr += PAGE_SIZE) {
        *ptr = 0;
    }
    
    printf("成功分配 %zu MB内存.\n", mb);

    sleep(10);

    // 释放内存
    free(buf);
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "用法: %s <size_in_MB>\n", argv[0]);
        return EXIT_FAILURE;
    }

    size_t mb = atoi(argv[1]);
    if (mb == 0) {
        fprintf(stderr, "无效的内存大小: %s\n", argv[1]);
        return EXIT_FAILURE;
    }

    // 分配内存
    if (alloc_anon(mb) != 0) {
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
