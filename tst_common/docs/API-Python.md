# 断言
## assert_true
```Python
def assert_true(self, expr, message=None):
	"""
	断言表达式返回真
	:param expr: 要断言的表达式
	:param message: 断言要输出的信息
	:return: None
	示例:
		assert_true(1 == 2)
		assert_true(a >= b)
	"""
    pass
```

## assert_false
```Python
def assert_false(self, expr, message=None):
	"""
	断言表达式返回假
	:param expr: 要断言的表达式
	:param message: 断言要输出的信息
	:return: None
	示例:
		assert_false(1 == 2)
		assert_false(a >= b)
	"""
    pass
```

## skip_test、skip_if_true和skip_if_false
```Python
def skip_test(self, message=None):
        """
        标记用例为SKIP状态（当用例不需要测试时）
        :param message: 要输出的信息
        :return: None
        示例:
            skip_test(message='内核CONFIG_XXX未开，系统不支持此测试')
        """

def skip_if_true(self, expr, message=None):
        """
        当表达式返回真或命令执行成功时，用例不满足测试条件，终止测试
        :param expr: 要判断的表达式
        :param message: 要输出的信息
        :return: None
        示例:
            skip_if_true(1 == 2)
        """

def skip_if_false(self, expr, message=None):
        """
        当表达式返回假或命令执行失败，用例不满足测试条件，终止测试
        :param expr: 要判断的表达式
        :param message: 要输出的信息
        :return: None
        示例:
            skip_if_false(1 == 2)
        """
```
