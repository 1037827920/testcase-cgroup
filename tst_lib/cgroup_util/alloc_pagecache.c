// 启用GNU扩展
#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>

#define PAGE_SIZE 4096  // 页大小

// 通过调整文件大小和读取文件来分配页面缓存
int alloc_pagecache(int fd, size_t size) {
    char buf[PAGE_SIZE];
    struct stat st;
    int i;

    // 获取文件装填
    if (fstat(fd, &st)) {
        perror("fstat 失败");
        return -1;
    }

    // 增加文件大小
    size += st.st_size;
    if (ftruncate(fd, size)) {
        perror("ftruncate 失败");
        return -1;
    }

    // 读取文件分配页缓存
    for (i = 0; i < size; i += sizeof(buf)) {
        if (read(fd, buf, sizeof(buf)) < 0) {
            perror("read 失败");
            return -1;
        }
    }

    return 0;
}

// 创建临时文件并分配页面缓存
int create_temp_file_and_allocate(size_t size_mb) {
    int fd;

    // 创建临时我呢见
    fd = open(".", O_TMPFILE | O_RDWR | O_EXCL, 0644);
    if (fd < 0) {
        perror("open 失败");
        return -1;
    }

    // 分配页缓存
    if (alloc_pagecache(fd, size_mb * 1024 * 1024)) {
        close(fd);
        return -1;
    }

    printf("成功分配 %zu MB 页缓存.\n", size_mb);

    sleep(10);

    // 释放文件
    close(fd);
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "用法: %s <size_in_MB>\n", argv[0]);
        return EXIT_FAILURE;
    }

    size_t size_mb = atoi(argv[1]);
    if (size_mb == 0) {
        fprintf(stderr, "无效的内存大小: %s\n", argv[1]);
        return EXIT_FAILURE;
    }

    if (create_temp_file_and_allocate(size_mb)) {
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
