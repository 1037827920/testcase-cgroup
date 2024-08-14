// Time: 2022-06-30 11:10:49
// Desc: 性能测试框架

#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

#include "benchmark.h"

long long tst_time_diff(struct tst_time *s, struct tst_time *e) {
    return (long long) (e->ts.tv_sec - s->ts.tv_sec) * NS_PER_SEC + (e->ts.tv_nsec - s->ts.tv_nsec);
}

int tst_get_time(struct tst_time *t) {
    if (clock_gettime(CLOCK_MONOTONIC, &(t->ts)) != 0) {
        return 1;
    }
    return 0;
}

long long tst_time_since_now(struct tst_time *t) {
    struct tst_time now;
    (void) tst_get_time(&now);
    return tst_time_diff(t, &now);
}

struct tst_perf_ctrl *tst_alloc_ctrl(const char *name, tst_perf_func_t setup, tst_perf_func_t do_test,
                                     tst_perf_func_t teardown, void *args, int warmup, int loop, enum value_type type,
                                     enum key_item key) {
    struct tst_perf_ctrl *c = NULL;

    if (name == NULL) {
        printf("the name can't be NULL\n");
        return NULL;
    }
    if (do_test == NULL) {
        printf("the do_test function can't be NULL\n");
        return NULL;
    }
    if (warmup < 0) {
        printf("the warmup can't less then 0");
        return NULL;
    }
    if (loop <= 0) {
        printf("the loop must greater then 0");
        return NULL;
    }
    if (type < LIB || type > HIB) {
        printf("the type must in enum value_type");
        return NULL;
    }
    if (key < key_max || key > key_standard_deviation) {
        printf("the key must in enum key_item");
        return NULL;
    }

    c = (struct tst_perf_ctrl *) malloc(sizeof(struct tst_perf_ctrl));
    if (c == NULL) {
        printf("malloc tst_perf_ctrl fail\n");
        return NULL;
    }
    (void) memset(c, 0, sizeof(struct tst_perf_ctrl));
    c->name = name;
    c->perf_setup = setup;
    c->perf_do_test = do_test;
    c->perf_teardown = teardown;
    c->args = args;
    c->nr_warmup = warmup;
    c->nr_loop = loop;
    c->value_type = type;
    c->key_item = key;
    c->data = (long long *) calloc(c->nr_loop, sizeof(long long));
    if (c->data == NULL) {
        printf("alloc memory for time data fail\n");
        free(c);
        return NULL;
    }

    return c;
}

void tst_destroy_ctrl(struct tst_perf_ctrl **c) {
    if (c == NULL || *c == NULL) {
        return;
    }
    if ((*c)->data != NULL) {
        free((*c)->data);
        (*c)->data = NULL;
    }
    free(*c);
    *c = NULL;
}

int tst_perf_run(struct tst_perf_ctrl *c) {
    int ret = 0;
    int i;
    struct tst_time t;

    if (c == NULL) {
        return 1;
    }
    // 预热
    fprintf(stderr, "%s : start warmup %d\n", c->name, c->nr_warmup);
    while (c->nr_warmup > 0) {
        c->nr_warmup--;

        if (c->perf_setup) {
            ret = c->perf_setup(c->args);
            if (ret != 0) {
                printf("the perf_setup return %d\n", ret);
                return 1;
            }
        }

        ret = c->perf_do_test(c->args);
        if (ret != 0) {
            printf("the perf_do_test return %d\n", ret);
            return 1;
        }

        if (c->perf_teardown) {
            ret = c->perf_teardown(c->args);
            if (ret != 0) {
                printf("the perf_teardown return %d\n", ret);
                return 1;
            }
        }
    }

    // 执行性能测试
    fprintf(stderr, "%s : start perf test loop %d\n", c->name, c->nr_loop);
    for (i = 0; i < c->nr_loop; i++) {
        if (c->perf_setup) {
            ret = c->perf_setup(c->args);
            if (ret != 0) {
                printf("the perf_setup return %d\n", ret);
                return 1;
            }
        }

        (void) tst_get_time(&t);
        ret = c->perf_do_test(c->args);
        if (ret != 0) {
            printf("the perf_do_test return %d\n", ret);
            return 1;
        }
        c->data[i] = tst_time_since_now(&t);

        if (c->perf_teardown) {
            ret = c->perf_teardown(c->args);
            if (ret != 0) {
                printf("the perf_teardown return %d\n", ret);
                return 1;
            }
        }
    }

    return 0;
}

int compare_time(const void *a, const void *b) {
    return (int) (*(long long *) a - *(long long *) b);
}

int statistic_data_base(long long *data, int len, struct tst_statistics_base *result) {
    long double sum = 0;
    long double step_20, step_100;
    long double variance = 0;
    int i;

    if (data == NULL || result == NULL || len <= 0) {
        return 1;
    }

    result->max = data[len - 1];
    result->min = data[0];
    result->median = data[(int) (len / 2)];
    step_20 = (long double) (result->max - result->min) / 20;
    step_100 = (long double) (result->max - result->min) / 100;

    for (i = 0; i < len; i++) {
        sum += data[i];
        if (step_20 > 0) {
            result->dist_20[(int) ((data[i] - result->min) / step_20)]++;
        }
        if (step_100 > 0) {
            result->dist_100[(int) ((data[i] - result->min) / step_100)]++;
        }
    }

    result->mean = sum / len;

    // 计算方差和
    for (i = 0; i < len; i++) {
        variance += powl(data[i] - result->mean, 2);
    }
    // 计算标准差
    result->standard_deviation = sqrtl(variance / len);

    return 0;
}

int statistic_data(struct tst_perf_ctrl *c) {
    if (c == NULL) {
        return 1;
    }
    int percent_5_start = (int) (c->nr_loop * 0.05);
    int percent_5_len = (int) (c->nr_loop * 0.9);

    if (c->data == NULL) {
        printf("the data is NULL\n");
        return 1;
    }

    // 将时间数据排序
    qsort(c->data, c->nr_loop, sizeof(long long), compare_time);
    (void) statistic_data_base(c->data, c->nr_loop, &(c->result.all));
    (void) statistic_data_base(&(c->data[percent_5_start]), percent_5_len, &(c->result.mid_90));

    return 0;
}

int show_result_json(struct tst_perf_ctrl *c) {
    int i;

    if (statistic_data(c) != 0) {
        return 1;
    }

    printf("{");

    printf("'name': '%s',", c->name);
    printf("'type': '%s',", "LIB");
    printf("'unit': '%s',", "ns");
    printf("'key': '%s',", "mean");

    printf("'data': {");

    printf("100: {");
    printf("'max': %lld,", c->result.all.max);
    printf("'min': %lld,", c->result.all.min);
    printf("'mean': %Lf,", c->result.all.mean);
    printf("'median': %lld,", c->result.all.median);
    printf("'standard_deviation': %Lf,", c->result.all.standard_deviation);
    printf("'dist_20': [");
    for (i = 0; i < NUM_20; i++) {
        printf("%d,", c->result.all.dist_20[i]);
    }
    printf("],");
    printf("'dist_100': [");
    for (i = 0; i < NUM_100; i++) {
        printf("%d,", c->result.all.dist_100[i]);
    }
    printf("],");
    printf("},");

    printf("90: {");
    printf("'max': %lld,", c->result.mid_90.max);
    printf("'min': %lld,", c->result.mid_90.min);
    printf("'mean': %Lf,", c->result.mid_90.mean);
    printf("'median': %lld,", c->result.mid_90.median);
    printf("'standard_deviation': %Lf,", c->result.mid_90.standard_deviation);
    printf("'dist_20': [");
    for (i = 0; i < NUM_20; i++) {
        printf("%d,", c->result.mid_90.dist_20[i]);
    }
    printf("],");
    printf("'dist_100': [");
    for (i = 0; i < NUM_100; i++) {
        printf("%d,", c->result.mid_90.dist_100[i]);
    }
    printf("],");
    printf("},");

    // end of data
    printf("},");

    printf("}");

    return 0;
}


int tst_test(const char *name, tst_perf_func_t setup, tst_perf_func_t do_test, tst_perf_func_t teardown,
             void *args, int warmup, int loop, enum value_type type, enum key_item key) {

    struct tst_perf_ctrl *c = tst_alloc_ctrl(name, setup, do_test, teardown, args, warmup, loop, type, key);
    if (c == NULL) {
        return 1;
    }
    tst_perf_run(c);
    show_result_json(c);
    tst_destroy_ctrl(&c);
    return 0;
}

////////////////////////////////////////////////////////////////////////////////
/* 下面的代码是示例 */
#if 0

#define NR_LOOP_OPEN 100
#define OPEN_PATH_LEN 128
struct open_args {
    int nr_opened;
    char path[NR_LOOP_OPEN][OPEN_PATH_LEN];
    int fds[NR_LOOP_OPEN];
};

int open_setup(void *args) {
    int i;
    struct rlimit r;
    struct open_args *a = (struct open_args *) (args);

    r.rlim_cur = NR_LOOP_OPEN + 1024;
    r.rlim_max = r.rlim_cur;
    setrlimit(RLIMIT_NOFILE, &r);
    memset(a, 0, sizeof(struct open_args));

    system("rm -rf ./file.ops");
    system("mkdir ./file.ops");

    for (i = 0; i < NR_LOOP_OPEN; ++i) {
        snprintf(a->path[i], OPEN_PATH_LEN, "./file.ops/open.%08d.test", i);
    }
    return 0;
}

int open_do_test(void *args) {
    int i;
    struct open_args *a = (struct open_args *) (args);
    for (i = 0; i < NR_LOOP_OPEN; ++i) {
        a->fds[i] = open(a->path[i], O_RDWR | O_CREAT | O_EXCL, 0600);
        if (a->fds[i] < 0) {
            printf("open the %s file fail\n", a->path[i]);
            a->nr_opened = i;
            return 1;
        }
    }
    a->nr_opened = i;
    return 0;
}

int open_teardown(void *args) {
    int i;
    struct open_args *a = (struct open_args *) (args);
    for (i = 0; i < a->nr_opened; ++i) {
        if (a->fds[i] > 0) {
            close(a->fds[i]);
            a->fds[i] = 0;
        }
    }
    system("rm -rf ./file.ops");
    return 0;
}

int exec_do_test(void *args) {
    pid_t pid = fork();
    pid_t wait;
    if (pid == 0) {
        execl("./simple.test", "./simple.test", NULL);
    } else if (pid > 0) {
        wait = waitpid(pid, NULL, 0);
        if (wait == pid) {
            return 0;
        }
        printf("waitpid(%d) return %d not as expect\n", pid, wait);
    } else {
        printf("fork fail\n");
    }
    return 1;
}


int main(int argc, char **argv) {
    struct open_args a;
    printf("{");
    printf("'open': ");
    tst_test("open.100", open_setup, open_do_test, open_teardown, &a, 100, 2000, LIB, key_mean);
    printf(",");
    printf("'exec': ");
    tst_test("exec", NULL, exec_do_test, NULL, NULL, 100, 5000, LIB, key_mean);
    printf(",");
    printf("}\n");
    return 0;
}

#endif