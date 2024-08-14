// 测试套自定义公共函数库
#include "common.h"
#include "ts_common.h"

int ts_setup(void) {
    msg("this is ts_setup");
    return 0;
}

int tc_setup_common(int argc, char **argv) {
    msg("this is tc_setup_common");
    return 0;
}

int tc_teardown_common(int argc, char **argv) {
    msg("this is tc_teardown_common");
    return 0;
}

int ts_teardown(void) {
    msg("this is ts_teardown");
    return 0;
}
