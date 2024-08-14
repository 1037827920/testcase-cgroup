// 启用GNU扩展
#define _GNU_SOURCE

#include <stdio.h>  
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>

#define PAGE_SIZE 4096  // 页大小

// 单次分配大量匿名内存 
int alloc_anon_mlock(size_t mb) {
    size_t size = mb * 1024 * 1024; 
    void *buf;

    // 使用mmap分配内存
    buf = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (buf == MAP_FAILED) {
        perror("mmap 失败");
        return -1;
    }

    if (mlock(buf, size) != 0) {
        perror("mlock 失败");
        return -1;
    }

    sleep(1);

    if (munmap(buf, size) != 0) {
        perror("munmap 失败");
        return -1;
    }

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
    if (alloc_anon_mlock(mb) != 0) {
        return EXIT_FAILURE;
    }

    printf("成功分配 %zu MB内存.\n", mb);
    return EXIT_SUCCESS;
}