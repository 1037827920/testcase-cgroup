#!/usr/bin/env python3
# coding: utf-8
# Time: 2022-04-19 22:26:42
# Desc: Python用例公共模块

import abc
import getpass
import os
import platform
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import traceback
import __main__ as main

TST_PASS = 0
TST_FAIL = 1
TST_INIT = 2
TST_SKIP = 3
tst_tc_stat_dict = {
    TST_PASS: 'TST_PASS',
    TST_FAIL: 'TST_FAIL',
    TST_INIT: 'TST_INIT',
    TST_SKIP: 'TST_SKIP',
}


def command(cmd, timeout=20):
    proc = subprocess.Popen(cmd, shell=True, encoding='utf-8')
    try:
        proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
    return proc.wait()


def command_output(cmd, timeout=20):
    proc = subprocess.Popen(cmd, shell=True, encoding='utf-8', stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    outs = ""
    errs = ""
    try:
        outs, errs = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
    code = proc.wait()
    return outs, errs, code


def command_quiet(cmd, timeout=20):
    proc = subprocess.Popen(cmd, shell=True, encoding='utf-8', stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
    code = proc.wait()
    return code


def get_yum_provide(filename):
    outs, errs, code = command_output(f'yum provides {filename}')
    print(f'stdout:\n{outs}')
    print(f'stderr:\n{errs}')
    print(f'status: {code}')
    if code != 0 or outs is None:
        return None
    for line in outs.splitlines():
        match = re.match(r'^([-\w.]+)-\d(\.\d+)+-.* : ', line)
        if match:
            package = match.groups()[0]
            print(f'get file {filename} provide: {package}')
            return package
    return None


def try_install_command(cmd, package=None):
    if command_quiet(f'which {cmd}') == 0:
        return True
    if package is None:
        package = get_yum_provide(cmd)
    if package is not None:
        command(f'yum install -y {package}')
    if command(f'which {cmd}') == 0:
        return True
    return False


def get_kernel_release():
    return platform.release()


def get_system_boot_time():
    with open('/proc/uptime', 'r') as f:
        uptime = float(f.readline().split()[0])
    now_time = time.time()
    boot_time = now_time - uptime
    result = boot_time

    tsuite_tmpdir = os.path.join('/tmp', f'.tsuite-{getpass.getuser()}')
    if not os.path.exists(tsuite_tmpdir):
        os.makedirs(tsuite_tmpdir, mode=0o755, exist_ok=True)
    boot_time_file = os.path.join(tsuite_tmpdir, 'boot-time')
    if os.path.exists(boot_time_file):
        # 如果系统启动的时间已经有记录，那么看看是否同一次启动
        with open(boot_time_file, 'r') as f:
            old_boot_time = float(f.readline())
        # 如果记录的时间和当前计算的时间差别不大，那么就认为是同一次启动
        if abs(old_boot_time - boot_time) <= 10:
            result = old_boot_time
        else:
            with open(boot_time_file, 'w') as f:
                f.write(f'{boot_time}')
    else:
        with open(boot_time_file, 'w') as f:
            f.write(f'{boot_time}')
    return 'boot-time.' + time.strftime('%Y%m%d-%H%M%S', time.localtime(result))


def get_os_release():
    release = None
    if os.path.isfile('/etc/os-release'):
        with open('/etc/os-release', 'r') as f:
            for line in f.readlines():
                if re.match(r'PRETTY_NAME=', line, re.IGNORECASE):
                    release = re.sub(r'[^\w.]+', '-', line.split('=')[1].strip())
    if os.path.isfile('/etc/tencentos-release'):
        with open('/etc/tencentos-release', 'r') as f:
            for line in f.readlines():
                if re.match(r'TencentOS', line, re.IGNORECASE):
                    release = re.sub(r'[^\w.]+', '-', line.strip())
    if os.path.isfile('/etc/motd'):
        with open('/etc/motd', 'r') as f:
            for line in f.readlines():
                if re.match(r'version', line, re.IGNORECASE):
                    release = re.sub(r'[^\w.]+', '-', line.strip())
                if re.match(r'tlinux', line, re.IGNORECASE):
                    release = re.sub(r'[^\w.]+', '-', line.strip())
    if release is None:
        return 'Unknown-Linux'
    return release.strip('-')


def get_tst_test_env_ip():
    outs, _, _ = command_output('ifconfig eth1')
    eth1_ip = get_ip_of_ifconfig(outs)
    # 测试环境的eth1都是192.168.x.x
    if (eth1_ip is None) or (not eth1_ip.startswith('192.168.')):
        return None
    env_main_ip_1 = re.sub(r'\.\d{1,3}$', '.11', eth1_ip)
    # 获取测试环境主环境的IP
    outs, _, _ = command_output(f'ssh root@{env_main_ip_1} ifconfig eth0', timeout=3)
    env_main_ip_0 = get_ip_of_ifconfig(outs)
    if env_main_ip_0 is None:
        return None
    return [env_main_ip_0, eth1_ip]


def get_ip_of_ifconfig(ifconfig_outs: str):
    if ifconfig_outs is None:
        return None
    if not isinstance(ifconfig_outs, str):
        return None
    for line in ifconfig_outs.splitlines():
        if 'netmask' not in line:
            continue
        return re.search(r'\b(?:\d{1,3}\.){3}\d{1,3}\b', line).group()
    return None


def get_host_ip():
    """
    这个方法是目前见过最优雅获取本机服务器的IP方法了。没有任何的依赖，也没有去猜测机器上的网络设备信息。
    而且是利用 UDP 协议来实现的，生成一个UDP包，把自己的 IP 放如到 UDP 协议头中，然后从UDP包中获取本机的IP。
    这个方法并不会真实的向外部发包，所以用抓包工具是看不到的。但是会申请一个 UDP 的端口，所以如果经常调用也会比较耗时的，
    这里如果需要可以将查询到的IP给缓存起来，性能可以获得很大提升。

    作者：钟翦
    链接：https://www.zhihu.com/question/49036683/answer/1243217025
    来源：知乎
    著作权归作者所有。商业转载请联系作者获得授权，非商业转载请注明出处。

    :return:
    """
    _local_ip = None
    s = None
    try:
        if not _local_ip:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(('8.8.8.8', 80))
            _local_ip = s.getsockname()[0]
        return _local_ip
    finally:
        if s:
            s.close()


def command_to_filename(cmd: str):
    return re.sub(r'\W+', '.', cmd) + '.txt'


def get_commands_logs(cmd_list, logs_dir, timeout=60):
    start_time = time.time()
    exec_list = list()
    index = 1
    for cmd in cmd_list:
        # print(f'{index} execute command: {cmd}')
        cmd_dict = {
            'index': index,
            'command': cmd,
            'timeout': timeout,
            'start_time': time.time(),
            'proc': subprocess.Popen(cmd, shell=True, encoding='utf-8', stdout=subprocess.PIPE, stderr=subprocess.PIPE),
            'log_file': os.path.join(os.path.realpath(logs_dir), command_to_filename(cmd)),
            'end_time': None,
            'cost': None,
            'stdout': None,
            'stderr': None,
            'status': None
        }
        exec_list.append(cmd_dict)
        index += 1

    # 检查命令是否执行完
    while True:
        all_command_ok = True
        if time.time() - start_time > timeout:
            break
        for proc_dict in exec_list:
            if proc_dict['status'] is not None:
                continue
            try:
                proc_dict['stdout'], proc_dict['stderr'] = proc_dict['proc'].communicate(timeout=1)
            except subprocess.TimeoutExpired:
                all_command_ok = False
                continue
            proc_dict['status'] = proc_dict['proc'].returncode
            proc_dict['end_time'] = time.time()
            proc_dict['cost'] = proc_dict['end_time'] - proc_dict['start_time']
            # print(f'{proc_dict["index"]} command {proc_dict["command"]} end, status {proc_dict["status"]}')
        if all_command_ok:
            break

    # 记录命令执行结果，还没有结束的命令直接终止
    for proc_dict in exec_list:
        if proc_dict['status'] is None:
            proc_dict['proc'].kill()
            proc_dict['stdout'], proc_dict['stderr'] = proc_dict['proc'].communicate(timeout=1)
            proc_dict['status'] = proc_dict['proc'].returncode
            proc_dict['end_time'] = time.time()
            proc_dict['cost'] = proc_dict['end_time'] - proc_dict['start_time']
            print(f'{proc_dict["index"]} command {proc_dict["command"]} killed, status {proc_dict["status"]}')
        with open(file=proc_dict['log_file'], mode='a', buffering=1, encoding='utf-8') as f:
            f.write('=' * 60 + '\n')
            f.write(f'### command: {proc_dict["command"]}\n')
            f.write(f'### timeout: {proc_dict["timeout"]}\n')
            f.write(f'### start_time: '
                    f'{time.strftime("%Y-%m-%d %H:%M:%S %z", time.localtime(proc_dict["start_time"]))}\n')
            f.write(f'### end_time: '
                    f'{time.strftime("%Y-%m-%d %H:%M:%S %z", time.localtime(proc_dict["end_time"]))}\n')
            f.write(f'### cost: {proc_dict["cost"]}\n')
            f.write(f'### log_file: {proc_dict["log_file"]}\n')
            f.write(f'### status: {proc_dict["status"]}\n')
            f.write('=' * 60 + '\n')
            f.write('### stdout:\n')
            f.write(proc_dict["stdout"])
            f.write('=' * 60 + '\n')
            f.write('### stderr:\n')
            f.write(proc_dict["stderr"])
            f.write('=' * 60 + '\n')
    print(f'### all command cost {time.time() - start_time}')


def sysinfo(log_dir, install_command=False, merge_files=True):
    command_list = [
        "uname -a",
        "ulimit -a",
        "lscpu",
        "lspci",
        "lspci -k",
        "lspci -vv",
        "lspci -t -vv -nn",
        "lsscsi",
        "lsscsi --list --verbose --long",
        "lsusb",
        "lsusb --tree",
        "lshw -short",
        "lsmod",
        "route -n",
        "ifconfig -a",
        "dmidecode",
        "udevadm info --export-db",
        "ipmitool sdr",
        "ipmitool fru",
        "ipmitool sensor",
        "ipmitool sel",
        "fdisk -l",
        "mount",
        "df -P",
        "lsblk",
        "lsblk -O",
        "smartctl --scan"
        "free",
        "numastat -v",
        "numastat -v -m",
        "cpupower --cpu all frequency-info",
        "cpupower --cpu all idle-info",
        "sysctl -a",
        "cat /etc/os-release",
        "cat /etc/system-release",
        "cat /etc/centos-release",
        "cat /etc/redhat-release",
        "cat /etc/system-release",
        "cat /etc/tencentos-release",
        "cat /etc/tlinux-release",
        "cat /proc/cpuinfo",
        "cat /proc/meminfo",
        "cat /proc/buddyinfo",
        "cat /proc/devices",
        "cat /proc/interrupts",
        "cat /proc/iomem",
        "cat /proc/ioports",
        "cat /proc/modules",
        "cat /proc/module_md5_list",
        "zcat /proc/config.gz",
        "zcat /proc/bt_stat",
        "zcat /proc/cgroups",
        "zcat /proc/cmdline",
        "zcat /proc/consoles",
        "zcat /proc/crypto",
        "zcat /proc/devices",
        "zcat /proc/diskstats",
        "zcat /proc/dma",
        "zcat /proc/execdomains",
        "zcat /proc/filesystems",
        "zcat /proc/kallsyms",
        "zcat /proc/loadavg",
        "zcat /proc/loadavg_bt",
        "zcat /proc/locks",
        "zcat /proc/mdstat",
        "zcat /proc/misc",
        "zcat /proc/mtrr",
        "zcat /proc/partitions",
        "zcat /proc/sched_debug",
        "zcat /proc/schedstat",
        "zcat /proc/slabinfo",
        "zcat /proc/softirqs",
        "zcat /proc/stat",
        "zcat /proc/swaps",
        "zcat /proc/timer_list",
        "zcat /proc/uptime",
        "zcat /proc/version",
        "zcat /proc/vmallocinfo",
        "zcat /proc/vmstat",
        "zcat /proc/zoneinfo",
        "dmesg"
    ]
    if os.path.isfile('/proc/net/dev'):
        with open(file='/proc/net/dev', mode='r') as f:
            for line in f.readlines():
                if ':' not in line:
                    continue
                dev = line.split(':')[0].strip()
                command_list.append(f'ethtool {dev}')
                command_list.append(f'ethtool -i {dev}')
    if os.path.isfile('/proc/modules'):
        with open(file='/proc/modules', mode='r') as f:
            for line in f.readlines():
                module = line.split()[0].strip()
                command_list.append(f'modinfo {module}')
    outs, _, _ = command_output('smartctl --scan')
    if outs:
        for line in outs.splitlines():
            dev = line.split()[0].strip()
            command_list.append(f'smartctl --xall {dev}')
            command_list.append(f'hdparm {dev}')

    # 尝试安装命令
    if install_command:
        for cmd in set([c.split()[0] for c in command_list]):
            try_install_command(cmd)

    if not os.path.exists(log_dir):
        os.makedirs(log_dir, mode=0o755, exist_ok=True)
    get_commands_logs(command_list, log_dir)
    # 将多个日志文本文件合并成一个文件
    if merge_files:
        tmp_file = tempfile.mkstemp()[1]
        with open(tmp_file, 'w') as f:
            for txt_file in os.listdir(log_dir):
                txt_path = os.path.join(log_dir, txt_file)
                with open(txt_path, 'r') as tf:
                    f.write(tf.read())
                os.remove(txt_path)
        shutil.move(tmp_file, os.path.join(log_dir, 'sysinfo.txt'))


def get_crash_path():
    result = None
    if not os.path.exists('/etc/kdump.conf'):
        return result
    with open('/etc/kdump.conf', 'r') as f:
        for line in f.readlines():
            if line.startswith('path '):
                result = line.split()[1]
    return result


def safe_repr(obj, short=False):
    max_len = 120
    try:
        result = repr(obj)
    except Exception:
        result = object.__repr__(obj)
    if not short or len(result) < max_len:
        return result
    return result[:max_len] + ' [truncated]...'


def set_env(env, value):
    if os.environ.get(env):
        print(f"the env {env} has value {os.environ.get(env)}, don't set to {value}")
        return
    os.environ[env] = f"{value}"


def set_env_force(env, value):
    if os.environ.get(env):
        print(f"the env {env} has value {os.environ.get(env)}, now set to {value}")
    os.environ[env] = value


def get_env(env):
    return os.environ.get(env)


def get_env_default(env, default):
    return os.environ.get(env, default)


def _is_main_process():
    return int(get_env_default('TST_TC_PID', '0')) == os.getpid()


class ExceptionSkip(Exception):
    def __init__(self, message=""):
        super(ExceptionSkip, self).__init__(self)
        self.message = f'{message}'

    def __str__(self):
        return self.message


def tcstat_to_str(tcstat):
    tst_tc_stat_dict.get(tcstat, 'UNKNOWN')


class TestCase:
    def __init__(self, *args):
        # 用例文件路径
        self.tc_path = os.path.realpath(main.__file__)
        # 用例名
        self.tc_name = self._get_tc_attr('用例名称')
        # 执行用例文件时的目录
        self.exec_cwd = os.getcwd()
        # TST_TC_CWD 测试用例CWD
        self.tst_tc_cwd = os.path.dirname(self.tc_path)
        set_env('TST_TC_CWD', self.tst_tc_cwd)
        # TST_TC_PID 测试用例主进程pid
        self.tst_tc_pid = os.getpid()
        set_env('TST_TC_PID', self.tst_tc_pid)
        # 用例执行状态
        self._tcstat = TST_INIT
        # 用例退出码，0表示用例PASS或SKIP，其他表示异常
        self._exit_code = 0
        # TST_TS_TOPDIR 测试套顶层目录
        self.tst_ts_topdir = self._get_ts_topdir()
        set_env('TST_TS_TOPDIR', self.tst_ts_topdir)
        # TST_COMMON_TOPDIR common顶层目录
        self.tst_common_topdir = self._get_common_topdir()
        set_env('TST_COMMON_TOPDIR', self.tst_common_topdir)
        # 标记tc_setup是否被调用
        self._tc_setup_called = False
        # TST_TS_SYSDIR 测试套公共运行目录
        self.tst_ts_sysdir = None if self.tst_ts_topdir is None \
            else os.path.join(self.tst_ts_topdir, 'logs', '.ts.sysdir')
        set_env('TST_TS_SYSDIR', self.tst_ts_sysdir)
        # TST_TC_SYSDIR 测试用例管理用临时目录
        self.tst_tc_sysdir = None if self.tst_ts_topdir is None \
            else os.path.join(self.tst_ts_topdir, 'logs', 'testcase', f'.tc.{self.tst_tc_pid}.sysdir')
        set_env('TST_TC_SYSDIR', self.tst_tc_sysdir)

    def dbg(self, message):
        print(message, file=sys.stderr)

    def msg(self, message):
        print(message, file=sys.stderr)

    def err(self, message):
        print(message, file=sys.stderr)
        self._fail(message)

    def _get_tc_attr(self, attr):
        with open(file=self.tc_path, mode='r', encoding='utf-8') as f:
            for line in f.readlines():
                if f"@{attr}:" not in line:
                    continue
                return re.sub(f'.*@{attr}:', '', line).strip()
        return None

    def _get_ts_topdir(self):
        result = self.tst_tc_cwd
        while True:
            if os.path.isdir(os.path.join(result, 'cmd')) and os.path.isdir(os.path.join(result, 'testcase')) and \
                    os.path.isfile(os.path.join(result, 'tsuite')):
                if os.path.isdir(os.path.join(result, '..', 'tst_common')):
                    return os.path.dirname(result)
                return result
            next_path = os.path.dirname(result)
            if next_path == result:
                return None
            result = next_path

    def _get_common_topdir(self):
        if self.tst_ts_topdir is None:
            return None
        if os.path.isdir(os.path.join(self.tst_ts_topdir, 'tst_common')):
            return os.path.join(self.tst_ts_topdir, 'tst_common')
        return self.tst_ts_topdir

    def _set_tcstat(self, stat):
        self._tcstat = stat

    def _get_tcstat(self):
        return self._tcstat

    def _get_tcstat_str(self):
        return tcstat_to_str(self._tcstat)

    def _fail(self, message=None):
        if self._tcstat != TST_FAIL:
            self.msg("the testcase first fail here")
            self._set_tcstat(TST_FAIL)
            raise AssertionError(message)

    def _pass(self):
        if self._get_tcstat() == TST_INIT:
            self._set_tcstat(TST_PASS)

    def skip_test(self, message=None):
        """
        标记用例为SKIP状态（当用例不需要测试时）
        :param message: 要输出的信息
        :return: None
        示例:
            skip_test(message='内核CONFIG_XXX未开，系统不支持此测试')
        """
        if self._get_tcstat() in (TST_PASS, TST_INIT, TST_SKIP):
            self._set_tcstat(TST_SKIP)
            raise ExceptionSkip(f'set testcase SKIP: {message}')
        else:
            self.msg(f'set testcase SKIP fail: {message}')
            self._fail(f'the testcase stat is {self._get_tcstat_str()}, can\'t set to SKIP')

    def skip_if_true(self, expr, message=None):
        """
        当表达式返回真或命令执行成功时，用例不满足测试条件，终止测试
        :param expr: 要判断的表达式
        :param message: 要输出的信息
        :return: None
        示例:
            skip_if_true(1 == 2)
        """
        if expr:
            self.skip_test(f'skip_if_true -> {safe_repr(expr)}: {message}')

    def skip_if_false(self, expr, message=None):
        """
        当表达式返回假或命令执行失败，用例不满足测试条件，终止测试
        :param expr: 要判断的表达式
        :param message: 要输出的信息
        :return: None
        示例:
            skip_if_false(1 == 2)
        """
        if not expr:
            self.skip_test(f'skip_if_false -> {safe_repr(expr)}: {message}')

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
        if not expr:
            self.msg(f"{safe_repr(expr)} is not true: {message}")
            self._fail(message)
        else:
            self._pass()

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
        if expr:
            self.msg(f"{safe_repr(expr)} is not false: {message}")
            self._fail(message)
        else:
            self._pass()

    def _tc_setup_common(self, *args):
        # 只有用例的主进程才能执行此函数
        if not _is_main_process():
            return None
        try:
            self.tc_setup_common(*args)
        except Exception:
            raise

    def tc_setup_common(self, *args):
        self.msg("this is TestCase.tc_setup_common")

    def _tc_setup(self, *args):
        # 只有用例的主进程才能执行此函数
        if not _is_main_process():
            return None
        try:
            self._tc_setup_called = True
            self.tc_setup(*args)
        except Exception:
            raise

    def tc_setup(self, *args):
        self.msg("this is TestCase.tc_setup")

    def _do_test(self, *args):
        # 只有用例的主进程才能执行此函数
        if not _is_main_process():
            return None
        try:
            self.do_test(*args)
        except Exception:
            raise

    @abc.abstractmethod
    def do_test(self, *args):
        self.msg("this is TestCase.do_test")

    def _tc_teardown(self, *args):
        # 只有用例的主进程才能执行此函数
        if not _is_main_process():
            return None
        try:
            self.tc_teardown(*args)
        except Exception:
            raise

    def tc_teardown(self, *args):
        self.msg("this is TestCase.tc_teardown")

    def _tc_teardown_common(self, *args):
        # 只有用例的主进程才能执行此函数
        if not _is_main_process():
            return None
        try:
            self.tc_teardown_common(*args)
        except Exception:
            raise

    def tc_teardown_common(self, *args):
        self.msg("this is TestCase.tc_teardown_common")

    def _is_ts_setup_called(self):
        if self.tst_ts_sysdir:
            return os.path.isfile(os.path.join(self.tst_ts_sysdir, 'ts.setup.stat'))
        else:
            return False

    def _get_ts_setup_stat(self):
        if self.tst_ts_sysdir:
            ts_stat_file = os.path.join(self.tst_ts_sysdir, 'ts.setup.stat')
            if not os.path.isfile(ts_stat_file):
                return None
            with open(file=ts_stat_file, mode='r', encoding='utf-8') as f:
                line = f.readline()
                return int(line)
        else:
            return None

    def tst_main(self, *args):
        time_start = int(time.monotonic() * 1000000000)
        if self._is_ts_setup_called():
            self.msg(f"tsuite setup executed, stat is {self._get_ts_setup_stat()}")
        else:
            self.msg("tsuite setup may not executed")

        try:
            self._tc_setup_common(*args)
            self.msg("call _tc_setup_common success")
            self._tc_setup(*args)
            self.msg("call _tc_setup success")
            self._do_test(*args)
            self.msg("call _do_test success")
        except ExceptionSkip as e:
            self._set_tcstat(TST_SKIP)
            self.msg(e.message)
        except Exception:
            self._set_tcstat(TST_FAIL)
            self.msg(traceback.format_exc())
        finally:
            try:
                if self._tc_setup_called:
                    self._tc_teardown(*args)
                else:
                    self.msg("the tc_setup not called, so tc_teardown ignore")
                self._tc_teardown_common(*args)
            except ExceptionSkip as e:
                self._set_tcstat(TST_SKIP)
                self.msg(e.message)
            except Exception:
                self._set_tcstat(TST_FAIL)
                self.msg(traceback.format_exc())

        # TCase自动化执行框架需要用这个输出判断用例是否支持完
        self.msg("Global test environment tear-down")
        if self._get_tcstat() == TST_PASS:
            self.msg(f"RESULT : {self.tc_name} ==> [  PASSED  ]")
            self._exit_code = 0
        elif self._get_tcstat() == TST_FAIL:
            self.msg(f"RESULT : {self.tc_name} ==> [  FAILED  ]")
            self._exit_code = 1
        elif self._get_tcstat() == TST_INIT:
            self.msg(f"RESULT : {self.tc_name} ==> [  NOTEST  ]")
            self._exit_code = 1
        elif self._get_tcstat() == TST_SKIP:
            self.msg(f"RESULT : {self.tc_name} ==> [  SKIP  ]")
            self._exit_code = 0
        else:
            self.msg(f"RESULT : {self.tc_name} ==> [  UNKNOWN  ]")
            self._exit_code = 1
        time_end = int(time.monotonic() * 1000000000)
        self.msg(f'cost {(time_end - time_start) / 1000000000:.9f}')
        exit(self._exit_code)
