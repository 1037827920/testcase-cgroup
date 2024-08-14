// Time: 2022-04-18 14:07:49
// Desc: C用例基础公共函数库

#include "common.h"
#include <stdio.h>
#include <errno.h>
#include <stdarg.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <limits.h>
#include <string.h>
#include <libgen.h>
#include <stdlib.h>
#include <sys/mman.h>

struct tst_tc_control {
    // 用例名
    char tc_name[PATH_MAX];
    // 用例参数
    int tc_argc;
    char **tc_argv;
    // 用例源文件路径
    char tc_source_path[PATH_MAX];
    // 用例可执行文件路径
    char tc_exec_path[PATH_MAX];
    // 执行用例文件时的目录
    char exec_cwd[PATH_MAX];
    // TST_TC_CWD 测试用例CWD
    char tst_tc_cwd[PATH_MAX];
    // 用例开始执行的时间
    struct tst_time time_start;
    // TST_TC_PID 测试用例主进程pid
    pid_t tst_tc_pid;
    // 标记tc_setup是否被调用
    int tc_setup_called;
    // 用例执行状态
    int tc_stat;
    // TST_TS_TOPDIR 测试套顶层目录
    char tst_ts_topdir[PATH_MAX];
    // TST_COMMON_TOPDIR common顶层目录
    char tst_common_topdir[PATH_MAX];
    // TST_TS_SYSDIR 测试套公共运行目录
    char tst_ts_sysdir[PATH_MAX];
    // TST_TC_SYSDIR 测试用例管理用临时目录
    char tst_tc_sysdir[PATH_MAX];
    // 测试套执行状态标记文件
    char tst_ts_setup_stat[PATH_MAX];
};

struct tst_tc_control *g_tst_tc_control;

void show_tc_control(void) {
    dbg("tc_name: %s", g_tst_tc_control->tc_name);
    dbg("tc_source_path: %s", g_tst_tc_control->tc_source_path);
    dbg("tc_exec_path: %s", g_tst_tc_control->tc_exec_path);
    dbg("exec_cwd: %s", g_tst_tc_control->exec_cwd);
    dbg("tst_tc_cwd: %s", g_tst_tc_control->tst_tc_cwd);
    dbg("tst_tc_pid: %d", g_tst_tc_control->tst_tc_pid);
    dbg("tc_stat: %d", g_tst_tc_control->tc_stat);
    dbg("tst_ts_topdir: %s", g_tst_tc_control->tst_ts_topdir);
    dbg("tst_ts_sysdir: %s", g_tst_tc_control->tst_ts_sysdir);
    dbg("tst_tc_sysdir: %s", g_tst_tc_control->tst_tc_sysdir);
    dbg("tst_ts_setup_stat: %s", g_tst_tc_control->tst_ts_setup_stat);
}

int _print(const char *format, ...) {
    va_list ap;
    int ret;
    char buff[MAX_LOG_LEN] = {0};

    va_start(ap, format);
    ret = vsnprintf(buff, MAX_LOG_LEN - 1, format, ap);
    va_end(ap);

    if (buff[ret - 1] != '\n') {
        buff[ret] = '\n';
        buff[ret + 1] = '\0';
    }
    fprintf(stderr, "%s", buff);

    return ret;
}

static int _is_main_process(void) {
    if (g_tst_tc_control->tst_tc_pid == getpid()) {
        return 1;
    }
    return 0;
}

static void _set_tcstat(int stat) {
    g_tst_tc_control->tc_stat = stat;
}

static int _get_tcstat(void) {
    return g_tst_tc_control->tc_stat;
}

void _tc_pass(void) {
    // 只有初始状态的用例才能置为PASS，其他异常状态的用例不能从异常变为PASS
    if (_get_tcstat() == TST_INIT) {
        _set_tcstat(TST_PASS);
    }
}

void _tc_fail(void) {
    if (_get_tcstat() != TST_FAIL) {
        msg("the testcase first fail here");
    }
    _set_tcstat(TST_FAIL);
}

static char *_tcstat_to_str(int tcstat) {
    switch (tcstat) {
        case TST_PASS:
            return "TST_PASS";
        case TST_FAIL:
            return "TST_FAIL";
        case TST_INIT:
            return "TST_INIT";
        case TST_SKIP:
            return "TST_SKIP";
        default:
            return "TST_UNKNOWN";
    }
}

static int _tc_teardown(int argc, char **argv) {
    int ret = 0;

    // 只有用例的主进程才能执行此函数
    if (!_is_main_process()) {
        return 0;
    }
    if (tc_teardown) {
        if (tc_teardown(argc, argv) == 0) {
            msg("call tc_teardown success");
        } else {
            err("call tc_teardown fail");
            ret = 1;
        }
    } else {
        msg("tc_teardown not define");
    }

    return ret;
}

static int _tc_teardown_common(int argc, char **argv) {
    int ret = 0;

    // 只有用例的主进程才能执行此函数
    if (!_is_main_process()) {
        return 0;
    }
    if (tc_teardown_common) {
        if (tc_teardown_common(argc, argv) == 0) {
            msg("call tc_teardown_common success");
        } else {
            err("call tc_teardown_common fail");
            ret = 1;
        }
    } else {
        msg("tc_teardown_common not define");
    }

    return ret;
}

static void _tc_run_complete(int argc, char **argv) {
    int ret = 0;

    // 只有用例的主进程才能执行此函数
    if (!_is_main_process()) {
        return;
    }
    // tc_setup有调用时tc_teardown才会被调用
    if (g_tst_tc_control->tc_setup_called) {
        if (_tc_teardown(argc, argv) == 0) {
            msg("call _tc_teardown success");
        } else {
            msg("call _tc_teardown fail");
            ret = 1;
        }
    } else {
        msg("the tc_setup not called, so tc_teardown ignore");
    }
    if (_tc_teardown_common(argc, argv) == 0) {
        msg("call _tc_teardown_common success");
    } else {
        msg("call _tc_teardown_common fail");
        ret = 1;
    }

    // TCase自动化执行框架需要用这个输出判断用例是否支持完
    msg("Global test environment tear-down");
    switch (_get_tcstat()) {
        case TST_PASS:
            msg("RESULT : %s ==> [  PASSED  ]", g_tst_tc_control->tc_name);
            break;
        case TST_FAIL:
            msg("RESULT : %s ==> [  FAILED  ]", g_tst_tc_control->tc_name);
            ret = 1;
            break;
        case TST_INIT:
            msg("RESULT : %s ==> [  NOTEST  ]", g_tst_tc_control->tc_name);
            ret = 1;
            break;
        case TST_SKIP:
            msg("RESULT : %s ==> [  SKIP  ]", g_tst_tc_control->tc_name);
            ret = 0;
            break;
        default:
            msg("RESULT : %s ==> [  UNKNOWN  ]", g_tst_tc_control->tc_name);
            ret = 1;
            break;
    }
    msg("cost %.9Lf", (long double) tst_time_since_now(&(g_tst_tc_control->time_start)) / NS_PER_SEC);

    exit(ret);
}

void _tst_assert(const char *expr, const char *file, int line, const char *func) {
    msg("%s:%d %s assert '%s' fail", file, line, func, expr);
    _tc_run_complete(g_tst_tc_control->tc_argc, g_tst_tc_control->tc_argv);
}

void _skip_test(const char *message, const char *file, int line, const char *func) {
    int tc_stat = _get_tcstat();

    if ((tc_stat == TST_PASS) || (tc_stat == TST_INIT) || (tc_stat == TST_SKIP)) {
        _set_tcstat(TST_SKIP);
        msg("%s:%d %s: set testcase SKIP: %s", file, line, func, message);
    } else {
        msg("%s:%d %s: set testcase SKIP fail: %s", file, line, func, message);
        err("the testcase stat is %s, can't set to SKIP", _tcstat_to_str(tc_stat));
    }
    _tc_run_complete(g_tst_tc_control->tc_argc, g_tst_tc_control->tc_argv);
}

static int _tc_setup_common(int argc, char **argv) {
    int ret = 0;

    if (tc_setup_common) {
        if (tc_setup_common(argc, argv) == 0) {
            msg("call tc_setup_common success");
        } else {
            err("call tc_setup_common fail");
            ret = 1;
        }
    } else {
        msg("tc_setup_common not define");
    }

    return ret;
}

static int _tc_setup(int argc, char **argv) {
    int ret = 0;

    // 只有用例的主进程才能执行此函数
    if (!_is_main_process()) {
        return 0;
    }
    g_tst_tc_control->tc_setup_called = 1;
    if (tc_setup) {
        if (tc_setup(argc, argv) == 0) {
            msg("call tc_setup success");
        } else {
            err("call tc_setup fail");
            ret = 1;
        }
    } else {
        msg("tc_setup not define");
    }

    return ret;
}

static int _do_test(int argc, char **argv) {
    int ret = 0;

    // 只有用例的主进程才能执行此函数
    if (!_is_main_process()) {
        return 0;
    }
    if (do_test) {
        if (do_test(argc, argv) == 0) {
            msg("call do_test success");
        } else {
            err("call do_test fail");
            ret = 1;
        }
    } else {
        err("do_test not define");
        ret = 1;
    }

    return ret;
}

static int _is_ts_setup_called(void) {
    if (is_file(g_tst_tc_control->tst_ts_setup_stat)) {
        return 1;
    }
    return 0;
}

static int _get_ts_setup_stat(void) {
    char buff[PAGE_SIZE];
    int read_size = read_line(g_tst_tc_control->tst_ts_setup_stat, 1, buff, PAGE_SIZE);
    if (read_size <= 0) {
        return TST_INIT;
    }
    return (int) strtol(buff, NULL, 0);
}

// 功能：判断路径是否为文件并且存在
// 参数：
//   path -- 文件路径
// 返回值：
//   0 -- 文件不存在
//   1 -- 文件存在
int is_file(const char *path) {
    struct stat sb;

    if (stat(path, &sb) != 0) {
        return 0;
    }
    if (S_ISDIR(sb.st_mode)) {
        return 0;
    }
    return 1;
}

// 功能：判断路径是否为目录并且存在
// 参数：
//   path -- 文件路径
// 返回值：
//   0 -- 文件不存在
//   1 -- 文件存在
int is_dir(const char *path) {
    struct stat sb;

    if (stat(path, &sb) != 0) {
        return 0;
    }
    if (S_ISDIR(sb.st_mode)) {
        return 1;
    }
    return 0;
}

// 功能：判断路径是否存在
// 参数：
//   path -- 文件路径
// 返回值：
//   0 -- 文件不存在
//   1 -- 文件存在
int is_exist(const char *path) {
    if (access(path, F_OK) == 0) {
        return 1;
    } else {
        return 0;
    }
}

// 功能：读文件内容到buff中
// 参数：
//   path -- 文件路径
//   buff -- 接收文件内容
//   size -- buff大小
// 返回值：
//   -1 -- 文件读取失败
//   其他 -- 读取到的文件内容长度
size_t read_file(const char *path, char *buff, size_t size) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        return -1;
    }
    int ret = read(fd, buff, size) < 0;
    if (ret < 0) {
        close(fd);
        return -1;
    }
    close(fd);
    return ret;
}

// 功能：读文本文件指定行的内容到buff中
// 参数：
//   path -- 文件路径
//   line -- 要读取内容的行号（从1开始）
//   buff -- 接收文件内容
//   size -- buff大小
// 返回值：
//   -1 -- 文件读取失败
//   其他 -- 读取到的文件内容长度
size_t read_line(const char *path, int line, char *buff, size_t size) {
    int i = 0;
    FILE *file = NULL;
    if (line <= 0) {
        dbg("the line less then 0: %d", line);
        return -1;
    }
    file = fopen(path, "r");
    if (file == NULL) {
        dbg("open file %s fail, errno %d, error: %s", path, errno, strerror(errno));
        return -1;
    }
    while (i < line) {
        i++;
        if (fgets(buff, size, file) == NULL) {
            if (i == line) {
                // 刚好读到指定行的时候文件结束
                break;
            }
            // 文件读完了，但是行号还没有读到
            dbg("get line %d fail, buff: %s, errno %d, error: %s", i, buff, errno, strerror(errno));
            fclose(file);
            return -1;
        }
    }
    fclose(file);
    return strlen(buff);
}

// 功能：创建多层目录
// 参数：
//   dir -- 目录
//   mode -- 目录权限
// 返回值：
//   -1 -- 创建失败
//    0 -- 创建成功
int mkdirs(const char *dir, mode_t mode) {
    int i;
    char now_path[PATH_MAX];

    for (i = 0; i < min(strlen(dir), PATH_MAX - 1); i++) {
        if (dir[i] != '/') {
            continue;
        }
        strncpy(now_path, dir, i + 1);
        if (is_exist(now_path)) {
            if (is_dir(now_path)) {
                continue;
            } else {
                dbg("the path %s exist but not dir", now_path);
                return -1;
            }
        }
        if (mkdir(now_path, mode) != 0) {
            dbg("mkdir %s fail, errno %d, error: %s", now_path, errno, strerror(errno));
            return -1;
        }
    }
    if (mkdir(dir, mode) != 0) {
        dbg("mkdir %s fail, errno %d, error: %s", dir, errno, strerror(errno));
        return -1;
    }
    if (!is_dir(dir)) {
        dbg("mkdirs %s fail", dir);
        return -1;
    }
    return 0;
}

// 功能：执行命令
// 参数：
//   command_format -- 命令内容
// 返回值：同system函数
int command(const char *command_format, ...) {
    va_list ap;
    char cmd[MAX_CMD_LEN] = {0};

    va_start(ap, command_format);
    (void) vsnprintf(cmd, MAX_CMD_LEN, command_format, ap);
    va_end(ap);

    return system(cmd);
}

static int _tc_init(int argc, char **argv) {
    size_t control_size = ((sizeof(struct tst_tc_control) / PAGE_SIZE) + 1) * PAGE_SIZE;
    g_tst_tc_control = (struct tst_tc_control *) mmap(NULL, control_size, PROT_READ | PROT_WRITE,
                                                      MAP_SHARED | MAP_ANONYMOUS, -1, 0);
    if (g_tst_tc_control == NULL) {
        msg("mmap g_tst_tc_control fail, errno: %d, %s", errno, strerror(errno));
        return 1;
    }
    memset(g_tst_tc_control, 0, control_size);
    if (tst_get_time(&(g_tst_tc_control->time_start)) != 0) {
        msg("tst_get_time fail, errno: %d, %s", errno, strerror(errno));
        return 1;
    }
    strncpy(g_tst_tc_control->tc_name, basename(argv[0]), PATH_MAX);
    g_tst_tc_control->tc_argc = argc;
    g_tst_tc_control->tc_argv = argv;

    if (realpath(argv[0], g_tst_tc_control->tc_exec_path) == NULL) {
        msg("get the realpath fail, errno: %d, %s", errno, strerror(errno));
        return 1;
    }

    strncpy(g_tst_tc_control->tc_source_path, g_tst_tc_control->tc_exec_path, PATH_MAX);
    strncat(g_tst_tc_control->tc_source_path, ".c", PATH_MAX);

    if (getcwd(g_tst_tc_control->exec_cwd, PATH_MAX) == NULL) {
        msg("get cwd fail, errno: %d, %s", errno, strerror(errno));
        return 1;
    }

    strncpy(g_tst_tc_control->tst_tc_cwd, g_tst_tc_control->tc_exec_path, PATH_MAX);
    dirname(g_tst_tc_control->tst_tc_cwd);

    g_tst_tc_control->tst_tc_pid = getpid();
    g_tst_tc_control->tc_stat = TST_INIT;

    // 尝试获取TST_TS_TOPDIR
    strncpy(g_tst_tc_control->tst_ts_topdir, g_tst_tc_control->tc_exec_path, PATH_MAX);
    char path_tst_common[PATH_MAX];
    char path_cmd[PATH_MAX];
    char path_testcase[PATH_MAX];
    char path_tsuite[PATH_MAX];
    while (g_tst_tc_control->tst_ts_topdir[1] != '\0') {
        snprintf(path_tst_common, PATH_MAX, "%s/tst_common", g_tst_tc_control->tst_ts_topdir);
        snprintf(path_cmd, PATH_MAX, "%s/cmd", g_tst_tc_control->tst_ts_topdir);
        snprintf(path_testcase, PATH_MAX, "%s/testcase", g_tst_tc_control->tst_ts_topdir);
        snprintf(path_tsuite, PATH_MAX, "%s/tsuite", g_tst_tc_control->tst_ts_topdir);
        if (is_dir(path_cmd) && is_dir(path_testcase) && is_file(path_tsuite)) {
            if (is_dir(path_tst_common)) {
                strncpy(g_tst_tc_control->tst_common_topdir, path_tst_common, PATH_MAX);
            } else {
                strncpy(g_tst_tc_control->tst_common_topdir, g_tst_tc_control->tst_ts_topdir, PATH_MAX);
            }
            break;
        }
        if (g_tst_tc_control->tst_ts_topdir[1] == '\0') {
            memset(g_tst_tc_control->tst_ts_topdir, 0, PATH_MAX);
            memset(g_tst_tc_control->tst_common_topdir, 0, PATH_MAX);
            break;
        }
        dirname(g_tst_tc_control->tst_ts_topdir);
    }
    // TST_TS_TOPDIR成功获取后，TST_TS_SYSDIR和TST_TC_SYSDIR可以生成了
    if (g_tst_tc_control->tst_ts_topdir[0] != '\0') {
        snprintf(g_tst_tc_control->tst_ts_sysdir, PATH_MAX, "%s/logs/.ts.sysdir", g_tst_tc_control->tst_ts_topdir);
        snprintf(g_tst_tc_control->tst_tc_sysdir, PATH_MAX, "%s/logs/testcase/.tc.%d.sysdir",
                 g_tst_tc_control->tst_ts_topdir, g_tst_tc_control->tst_tc_pid);
        snprintf(g_tst_tc_control->tst_ts_setup_stat, PATH_MAX, "%s/ts.setup.stat", g_tst_tc_control->tst_ts_sysdir);
    }

    return 0;
}

int tst_main(int argc, char **argv) {
    int ret = 0;

    if (_tc_init(argc, argv) != 0) {
        return 1;
    }
    if (chdir(g_tst_tc_control->tst_tc_cwd) != 0) {
        msg("chdir to %s fail, errno: %d, %s", g_tst_tc_control->tst_tc_cwd, errno, strerror(errno));
        return 1;
    }

    if (_is_ts_setup_called()) {
        msg("tsuite setup executed, stat is %d", _get_ts_setup_stat());
    } else {
        msg("tsuite setup may not executed");
    }

    _set_tcstat(TST_INIT);

    if (_tc_setup_common(argc, argv) == 0) {
        if (_tc_setup(argc, argv) == 0) {
            msg("call _tc_setup success");
            if (_do_test(argc, argv) == 0) {
                msg("call _do_test success");
            } else {
                err("call _do_test fail");
                ret = 1;
            }
        } else {
            err("call _tc_setup success");
            ret = 1;
        }
    } else {
        err("call _tc_setup_common success");
        ret = 1;
    }

    _tc_run_complete(argc, argv);

    return ret;
}
