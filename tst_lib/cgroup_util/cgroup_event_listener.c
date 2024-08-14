#include <assert.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <libgen.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <sys/eventfd.h>

#define USAGE_STR "Usage: cgroup_event_listener <path-to-control-file> <args>"

int main(int argc, char **argv)
{
	int efd = -1; // eventfd 文件描述符
	int cfd = -1; // 控制文件的文件描述符
	int event_control = -1;// cgroup.event_control 文件的文件描述符
	char event_control_path[4096]; // 存储 cgroup.event_control 文件路径的缓冲区
	char line[256]; // 存储写入 cgroup.event_control 文件的字符串
	int ret;

   	// 检查命令行参数数量是否正确
	if (argc != 3)
		errx(1, "%s", USAGE_STR);

    // 打开控制文件
	cfd = open(argv[1], O_RDONLY);
	if (cfd == -1)
		err(1, "Cannot open %s", argv[1]);

    // 构建 cgroup.event_control 文件的路径
	ret = snprintf(event_control_path, 4096, "%s/cgroup.event_control",
			dirname(argv[1]));
	if (ret >= 256)
		errx(1, "Path to cgroup.event_control is too long");

	// 打开 cgroup.event_control 文件
	event_control = open(event_control_path, O_WRONLY);
	if (event_control == -1)
		err(1, "Cannot open %s", event_control_path);

    // 创建 eventfd
	efd = eventfd(0, 0);
	if (efd == -1)
		err(1, "eventfd() failed");

    // 构建写入 cgroup.event_control 文件的字符串
	ret = snprintf(line, 63, "%d %d %s", efd, cfd, argv[2]);
	if (ret >= 256)
		errx(1, "Arguments string is too long");

    // 将字符串写入 cgroup.event_control 文件
	ret = write(event_control, line, strlen(line) + 1);
	if (ret == -1)
		err(1, "Cannot write to cgroup.event_control");

	while (1) {
		uint64_t result;

		// 从 eventfd 读取事件
		ret = read(efd, &result, sizeof(result));
		if (ret == -1) {
			if (errno == EINTR)
				continue;
			err(1, "Cannot read from eventfd");
		}
		assert(ret == sizeof(result));

        // 检查 cgroup.event_control 文件是否仍然可写
		ret = access(event_control_path, W_OK);
		if ((ret == -1) && (errno == ENOENT)) {
			puts("The cgroup seems to have removed.");
			break;
		}

		if (ret == -1)
			err(1, "cgroup.event_control is not accessible any more");
			
        // 打印事件信息
		printf("%s %s: crossed\n", argv[1], argv[2]);
	}

	return 0;
}