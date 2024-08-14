#ifndef TST_SUITE_COMMON_BENCHMARK_H
#define TST_SUITE_COMMON_BENCHMARK_H


#define NS_PER_SEC 1000000000
#define NUM_20 20
#define NUM_100 100

typedef int (*tst_perf_func_t)(void *);

enum value_type {
    // 越小越好（value_type.LIB）
    LIB,
    // 越大越好（value_type.HIB）
    HIB
};

enum key_item {
    // 最大值
    key_max,
    // 最小值
    key_min,
    // 平均值
    key_mean,
    // 中位数
    key_median,
    // 标准差
    key_standard_deviation
};

struct tst_time {
    struct timespec ts;
};

struct tst_statistics_base {
    // 时间单位都是ns
    long long max;
    long long min;
    long double mean;
    long long median;
    long double standard_deviation;
    int dist_20[NUM_20];
    int dist_100[NUM_100];
};

struct tst_statistics_result {
    struct tst_statistics_base all;
    struct tst_statistics_base mid_90;
};

struct tst_perf_ctrl {
    // 测试项名称
    const char *name;
    // 初始化函数
    tst_perf_func_t perf_setup;
    // 性能测试的对象函数
    tst_perf_func_t perf_do_test;
    // 清理函数
    tst_perf_func_t perf_teardown;
    // 性能测试函数的参数
    void *args;
    // 预热循环次数
    int nr_warmup;
    // 性能测试循环次数
    int nr_loop;
    // 性能数据类型，
    int value_type;
    // 本性能指标最重要的统计数据项，例如最大值（key_item.max）、平均值（key_item.mean）
    int key_item;

    // 性能测试数据
    long long *data;
    // 性能数据统计结果
    struct tst_statistics_result result;
};

extern int tst_get_time(struct tst_time *t);

extern long long tst_time_since_now(struct tst_time *t);

#endif //TST_SUITE_COMMON_BENCHMARK_H
