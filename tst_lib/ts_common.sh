#!/bin/bash
# 测试套公共函数
# 约定：
#   1、以下划线"_"开头的函数和变量用例不能直接调用
#   2、环境变量全大写，全局变量加上"g_"前置，局部变量统一加"local"修饰

# source自己定义的其他公共函数
source "${TST_TS_TOPDIR}/tst_lib/other_common.sh" || exit 1

ts_setup() {
    msg "this is ts_setup"
    return 0
}

tc_setup_common() {
    msg "this is tc_setup_common"
    # 检查是否是ROOT用户
    if ! is_root; then
        msg "错误原因：脚本需要 root 权限运行, 尝试在root shell环境下运行"
        return 1
    fi
    # 检查是否开启了CONFIG_CGROUPS
    if ! grep -q CONFIG_CGROUPS=y /boot/config-"$(uname -r)"; then
        msg "错误原因: CONFIG_CGROUPS 配置未开启"
        return 1
    fi
    # 检查是否安装了bc工具
    if ! is_bc_installed; then
        msg "错误原因: 未安装bc工具"
        return 1
    fi
}

tc_teardown_common() {
    msg "this is tc_teardown_common"
    return 0
}

ts_teardown() {
    msg "this is ts_teardown"
    return 0
}
