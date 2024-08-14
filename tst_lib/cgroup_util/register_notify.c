#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/inotify.h>
#include <errno.h>
#include <string.h>
#include <poll.h>

int prepare_for_wait(const char *filepath) {
    int fd, ret;

    fd = inotify_init1(0); 
    if (fd == -1) {
        return -1;
    }

    ret = inotify_add_watch(fd, filepath, IN_MODIFY);
    if (ret == -1) {
        perror("inotify_add_watch");
        close(fd);
        return -1;
    }

    return fd;
}

int monitor_file(int fd) {
    int ret = -1;
    struct pollfd pfd = {
        .fd = fd,
        .events = POLLIN,
    };

    while (1) {
        // 最多等待10s来检测事件
        ret = poll(&pfd, 1, 10000);

        if (ret == -1) {
            if (errno == EINTR) {
                continue;
            }
            perror("poll");
            break;
        }
        
        if (ret > 0 && pfd.revents & POLLIN) {
            ret = 0;
            break;
        }
    }
    return ret;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "用法: %s <file_path>\n", argv[0]);
        return EXIT_FAILURE;
    }

    const char *filepath = argv[1];
    int fd;

    fd = prepare_for_wait(filepath);
    if (fd == -1) {
        fprintf(stderr, "开启inotify失败.\n");
        return EXIT_FAILURE;
    }

    sleep(1);
    printf("正在监听文件: %s\n", filepath);
    monitor_file(fd);

    close(fd);
    return EXIT_SUCCESS;
}
