#!/usr/bin/env python3
# coding: utf-8

import os.path
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from lib.common import TestCase


class PythonTestCase(TestCase):
    """
    @用例ID: 20220420-234008-893237761
    @用例名称: test_python_testcase
    @用例级别: 3
    @用例标签:
    @用例类型: 功能
    """

    def tc_setup(self, *args):
        # @预置条件:
        self.msg("this is tc_setup")

    def do_test(self, *args):
        # @测试步骤:1:

        # @测试步骤:2:

        # @测试步骤:3:
        # @预期结果:3:
        self.assert_true(1 == 1)

    def tc_teardown(self, *args):
        self.msg("this is tc_teardown")


if __name__ == '__main__':
    PythonTestCase().tst_main(sys.argv)
