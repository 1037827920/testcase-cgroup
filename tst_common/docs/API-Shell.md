# 断言
## assert_true和assert_true_cont
```Shell
# 功能：断言表达式返回真或命令执行成功，'_cont'后缀的断言函数在断言失败后用例继续执行，不终止
# 参数：
#   $* -- 需要断言的表达式
# 返回值：
#   0 -- 断言成功
#   1 -- 断言失败
# 示例：
assert_true [ $? -eq 0 ]
assert_true_cont grep "abc" /tmp/file
```

## assert_false和assert_false_cont
```Shell
# 功能：断言表达式返回假或命令执行失败，'_cont'后缀的断言函数在断言失败后用例继续执行，不终止
# 参数：
#   $* -- 需要断言的表达式
# 返回值：
#   0 -- 断言成功
#   1 -- 断言失败
# 示例：
assert_false test -d /tmp/dir
assert_false_cont rmmod mykmod
```

## skip_test、skip_if_true和skip_if_false
```Shell
# skip_test
# 功能：标记用例为SKIP状态（当用例不需要测试时）
# 参数：
#   $1 -- 对SKIP状态标记的描述
# 返回值：无
# 示例：
skip_test "内核CONFIG_XXXX未打开，系统不支持xxx功能"

# skip_if_true
# 功能：当表达式返回真或命令执行成功时，用例不满足测试条件，终止测试
# 参数：
#   $* -- 需要断言的表达式
# 返回值：无
# 示例：
skip_if_true test -f /etc/xxx.conf

# skip_if_false
# 功能：当表达式返回假或命令执行失败，用例不满足测试条件，终止测试
# 参数：
#   $* -- 需要断言的表达式
# 返回值：无
# 示例：
skip_if_false which ps
```
# 工具
## conv_unit
```Shell
# 功能：将K/M/G/T等单位互相转换
# 参数：conv_unit [-i k|m|g|t] [-o k|m|g|t] value[_with_unit]
#   -i k|m|g|t 【可选参数】输入数据的单位，可选参数，若不指定单位，则默认为1，或者输入的值后面带参数
#   -o k|m|g|t 【可选参数】输出数据的单位，若不指定单位，则默认为1
#   value[_with_unit] 【必选参数】需要转换的数据值，可以跟单位（只取单位第一个字母用于判断k|m|g|t）
# 返回值：标准输出转换后的结果
#   0 -- 转换成功
#   1 -- 转换失败
# 示例：
conv_unit -o M 3G
conv_unit -o M -i G 3
```
