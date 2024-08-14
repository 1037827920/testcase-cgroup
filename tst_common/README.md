# 概述
本项目为自动化测试用例的公共代码库和框架代码，公共库接口函数见`docs/API-*.md`部分内容
测试套应用请参考：https://gitee.com/opencloudos-stream/test-suite-example

# 用法
```shell
tsuite options sub_command sub_options
    help: 显示帮助信息
    new case sh|c|py case_name [template]: 新增测试用例
        sh|c|py: 【必选】三选一，sh表示Shell脚本用例，c表示C用例，py表示Python脚本用例
        case_name: 【必选】要创建的用例名，同时用作文件名
        template: 【可选】不使用默认用例模板时，可以指定一个文件用作新用例模板
    list: 列出本测试套的测试用例
    compile: 编译测试套
    setup: 执行测试套setup
    run [case_path|case_name]: 执行测试用例
        case_path|case_name: 【可选】不指定此参数时执行测试套所有用例，指定时执行指定用例
    teardown: 执行测试套teardown
    clean: 执行make clean
    cleanall: 执行make cleanall，在clean基础上删除所有临时文件等
```