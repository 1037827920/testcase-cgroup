#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>

#define FILE_NAME "/mnt/huge/hugepagefile"
#define PROTECTION (PROT_READ | PROT_WRITE)
#define ADDR (void *)(0x0UL)
#define FLAGS (MAP_SHARED)

size_t size = 0;

static void write_bytes(char *addr)
{
    unsigned long i;

    for (i = 0; i < size; i++)
        *(addr + i) = (char)i;
}

static int read_bytes(char *addr)
{
    unsigned long i;

    for (i = 0; i < size; i++)
        if (*(addr + i) != (char)i) {
            printf("Mismatch at %lu\n", i);
            return 1;
        }
    return 0;
}

int main(int argc, char *argv[])
{
    if (argc != 3) {
        fprintf(stderr, "用法: %s <hugepage_count> <hugepage_size>\n", argv[0]);
        exit(1);
    }

    int hugepage_count = atoi(argv[1]);
    int hugepage_size = atoi(argv[2]);
    size = hugepage_count * hugepage_size * 1024 * 1024UL;

    void *addr;
    int fd, ret;
    fd = open(FILE_NAME, O_CREAT | O_RDWR, 0755);
    if (fd < 0) {
        perror("打开文件失败");
        exit(1);
    }

    // 申请hugepage内存
    addr = mmap(ADDR, size, PROTECTION, FLAGS, fd, 0);
    if (addr == MAP_FAILED) {
        perror("mmap");
        unlink(FILE_NAME);
        exit(1);
    }

    printf("内存映射起始地址: %p\n", addr);
    write_bytes(addr);
    ret = read_bytes(addr);

    sleep(5);

    // 释放hugepage内存
    munmap(addr, size);
    close(fd);
    unlink(FILE_NAME);

    return ret;
}