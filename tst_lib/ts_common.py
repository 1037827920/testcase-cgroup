#!/usr/bin/env python3
# coding: utf-8
# Desc: 测试套公共模块
import abc
import os.path
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from tst_common.lib.common import TestCase


class MyTestCase(TestCase):
    """
    本测试套内的Python用例需要继承此类
    """

    def tc_setup_common(self, *args):
        """
        所有Python用例执行tc_setup函数前会先执行本函数
        :param args:
        :return:
        """
        self.msg("this is tc_setup_common")

    @abc.abstractmethod
    def do_test(self, *args):
        pass

    def tc_teardown_common(self, *args):
        """
        所有Python用例执行tc_teardown函数后会执行本函数
        :param args:
        :return:
        """
        self.msg("this is tc_teardown_common")
