#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <poll.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
    if (argc != 2)
    {
        printf("用法: %s <file_path>\n", argv[0]);
        return 1;
    }

    const char *file_path = argv[1];
    const char trig[] = "some 500000 1000000";
    struct pollfd fds;
    int n;

    fds.fd = open(file_path, O_RDWR | O_NONBLOCK);
    if (fds.fd < 0)
    {
        printf("%s open 错误: %s\n", file_path, strerror(errno));
        return 1;
    }
    fds.events = POLLPRI;

    if (write(fds.fd, trig, strlen(trig) + 1) < 0)
    {
        printf("%s write 错误: %s\n", file_path, strerror(errno));
        return 1;
    }
    
    while (1)
    {
        n = poll(&fds, 1, -1);
        if (n < 0)
        {
            printf("poll error: %s\n", strerror(errno));
            return 1;
        }
        if (fds.revents & POLLERR)
        {
            printf("got POLLERR, event source is gone\n");
            return 0;
        }
        if (fds.revents & POLLPRI)
        {
            printf("event triggered!\n");
        }
        else
        {
            printf("unknown event received: 0x%x\n", fds.revents);
            return 1;
        }
    }

    return 0;
}