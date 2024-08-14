/* ****************************************************************************
 * @用例ID: 20220418-230037-838974137
 * @用例名称: test_c_testcase
 * @用例级别: 3
 * @用例标签:
 * @用例类型: 功能
 * ***************************************************************************/

#include "main.h"

int tc_setup(int argc, char **argv) {
    msg("this is tc_setup");
    // @预置条件:
    // @预置条件:
    return 0;
}

int do_test(int argc, char **argv) {
    msg("this is do_test");

    // @测试步骤:1:

    // @测试步骤:2:

    // @测试步骤:3:
    // @预期结果:3:
    assert_true(1 + 1 == 2);

    return 0;
}

int tc_teardown(int argc, char **argv) {
    msg("this is tc_teardown");
    return 0;
}
