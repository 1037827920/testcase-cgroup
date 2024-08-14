#ifndef __COMMON_H__
#define __COMMON_H__

#include <stdio.h>
#include <errno.h>
#include <stdarg.h>
#include <assert.h>
#include <unistd.h>
#include <limits.h>
#include <string.h>
#include <libgen.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <dirent.h>
#include <sys/user.h>

#include "benchmark.h"

#define TST_PASS 0
#define TST_FAIL 1
#define TST_INIT 2
#define TST_SKIP 3

#ifndef MAX_LOG_LEN
#define MAX_LOG_LEN 4096
#endif /* MAX_LOG_LEN */
#ifndef MAX_CMD_LEN
#define MAX_CMD_LEN 4096
#endif /* MAX_CMD_LEN */

#ifndef PAGE_SHIFT
#define PAGE_SHIFT 12
#endif /* PAGE_SHIFT */
#ifndef PAGE_SIZE
#define PAGE_SIZE (1UL << PAGE_SHIFT)
#endif /* PAGE_SIZE */
#ifndef PAGE_MASK
#define PAGE_MASK (~(PAGE_SIZE-1))
#endif /* PAGE_MASK */

#define KB (1024)
#define MB (KB * KB)
#define GB (MB * KB)

extern int _print(const char *format, ...);

#define min(a, b) ((a) > (b) ? (b) : (a))
#define max(a, b) ((a) < (b) ? (b) : (a))

#define dbg(format, ...) _print(format, ##__VA_ARGS__)
#define msg(format, ...) _print(format, ##__VA_ARGS__)
#define err(format, ...) \
    do{ \
        _tc_fail(); \
        _print("%s:%d %s: " format, __FILE__, __LINE__, __FUNCTION__, ##__VA_ARGS__); \
    }while(0)

extern void _skip_test(const char *message, const char *file, int line, const char *func);

#define skip_test(message) _skip_test(message, __FILE__, __LINE__, __FUNCTION__)

#define skip_if_true(expr) \
    do{ \
        if(expr){ \
            skip_test("skip_if_true " #expr); \
        } \
    }while(0)

#define skip_if_false(expr) \
    do{ \
        if(!(expr)){ \
            skip_test("skip_if_false " #expr); \
        } \
    }while(0)

extern void _tc_pass(void);

extern void _tc_fail(void);

extern void _tst_assert(const char *expr, const char *file, int line, const char *func);

// 功能：断言表达式返回真
// 参数：
//   expr -- 表达式
// 返回值：无
#define assert_true(expr) \
    do{ \
        if(expr){ \
            _tc_pass(); \
        }else{ \
            _tc_fail(); \
            _tst_assert(#expr, __FILE__, __LINE__, __FUNCTION__); \
        } \
    }while(0)

// 功能：断言表达式返回假
// 参数：
//   expr -- 表达式
// 返回值：无
#define assert_false(expr) \
    do{ \
        if(!(expr)){ \
            _tc_pass(); \
        }else{ \
            _tc_fail(); \
            _tst_assert(#expr, __FILE__, __LINE__, __FUNCTION__); \
        } \
    }while(0)


extern void show_tc_control(void);

extern int is_file(const char *path);

extern int is_dir(const char *path);

extern int is_exist(const char *path);

extern size_t read_line(const char *path, int line, char *buff, size_t size);

extern size_t read_file(const char *path, char *buff, size_t size);

extern int mkdirs(const char *dir, mode_t mode);

extern int command(const char *command_format, ...);

extern int tc_setup_common(int argc, char **argv) __attribute__((weak));

extern int tc_setup(int argc, char **argv) __attribute__((weak));

extern int do_test(int argc, char **argv) __attribute__((weak));

extern int tc_teardown(int argc, char **argv) __attribute__((weak));

extern int tc_teardown_common(int argc, char **argv) __attribute__((weak));

#endif // __COMMON_H__
