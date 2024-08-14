# 概述
为提高测试效率，开发了本项目，在测试用例上增加适配层，统一用例的执行接口。
适配层以测试套的方式存在，支持C、Shell和Python三种语言开发的用例。
当多个用例之间有一定关联性或存在公共代码时，可以组织成一个测试套，测试套内用例共享部分资源。

# 测试套目录结构
```shell
suite_example           ---------> 测试套顶层目录，绝对路径存储在环境变量TST_TS_TOPDIR中
├── cmd                 ---------> 测试套公共命令
│   ├── hello.c
│   └── Makefile
├── tst_common              -----> 【不可修改】submodule，公共代码库：test-suite-base
│   ├── cmd
│   │   ├── Makefile
│   │   └── tsuite.c
│   ├── kmod
│   │   ├── kmod_common.c
│   │   └── Makefile
│   ├── lib
│   │   ├── assert.sh
│   │   ├── common.c
│   │   ├── common_func.sh
│   │   ├── common.h
│   │   ├── common.sh
│   │   ├── main.h
│   │   ├── Makefile
│   │   ├── signature.sh
│   │   ├── tst_ts_setup
│   │   ├── tst_ts_teardown
│   │   └── tsuite_func.sh
│   ├── Makefile
│   └── tsuite
├── kmod                ---------> 内核模块，该目录下每个.c文件都会编译成同名的ko
│   ├── kmod_common.c
│   └── Makefile
├── lib                 ---------> 测试套公共库文件，.sh会被source，.c会被编译为静态库，.py会被import
│   ├── common.sh
│   ├── Makefile
│   ├── other_common.sh
│   ├── ts_setup
│   └── ts_teardown
├── logs                ---------> 日志和其他运行时临时目录
├── Makefile
├── testcase            ---------> 测试用例目录，所有测试用例放在此目录下
│   ├── Makefile
│   ├── test_cmd_ls.sh  ---------> 测试用例，.sh和.py会被直接执行，.c会被编译为同名的可执行程序后执行
│   └── test_c_testcase.c -------> 测试用例
└── tsuite -> ./common/tsuite ---> 软连接，指向公共代码库中的tsuite文件
```

# 新建测试项目
可以一个测试套对应一个测试git仓库，也可以多个测试套保存在一个仓库。这里以多个测试套对应一个git仓库示例如下：
```shell
# 1、先在代码托管平台（如gitee、github等）新建git仓库
# 这里的示例仓库为OpenCloudOS社区的软件包测试项目
# HTTPS协议：https://gitee.com/OpenCloudOS/packages-testing.git
#   SSH协议：    git@gitee.com:OpenCloudOS/packages-testing.git

# 2、下载测试项目
git clone --recurse-submodules https://gitee.com/OpenCloudOS/packages-testing.git

# 3、新建一个测试套，例如测试套名为：coreutils
cd ./packages-testing
# 3.1、下载测试套模板
git clone https://gitee.com/opencloudos-stream/test-suite-example.git ./coreutils
# 3.2、删除无用的文件（git文件、用例示例等）
rm -rf ./coreutils/.git ./coreutils/.gitmodules ./coreutils/testcase/test*
rm -rf ./coreutils/tst_common ./coreutils/README.md
# 3.3、为测试套配置git子模块
git submodule add https://gitee.com/opencloudos-stream/test-suite-base.git ./coreutils/tst_common

# 4、将测试套提交到git
git add ./coreutils
git commit -asm "提交coreutils测试套模板"
```

# 开发测试用例
测试用例要放在测试套的testcase目录下，推荐使用tsuite工具生成测试用例模板。
tsuite工具的用法参考：https://gitee.com/opencloudos-stream/test-suite-base
开发测试用例步骤如下：
```shell
# 1、假设需要开发的用例名为tc-mkdir-01，用例使用shell脚本开发
cd ./coreutils
./tsuite new case sh tc-mkdir-01
# 1.1、编辑用例文件，增加测试逻辑
vim testcase/tc-mkdir-01.sh

# 2、部分用例有C代码，需要编译，直接执行make all即可
./tsuite compile

# 3、用例开发完成后可以执行和调试用例
./tsuite run ./testcase/tc-mkdir-01.sh
# 3.1、或直接执行用例
./testcase/tc-mkdir-01.sh

# 4、用例调试通过后提交用例到git
git add ./testcase/tc-mkdir-01.sh
git commit -asm "新增测试用例tc-mkdir-01验证mkdir命令功能"
```