#!/usr/bin/env python3
# coding: utf-8
import abc
import json
import re
import subprocess
from _ctypes import PyObj_FromPtr
from enum import Enum


class ValueType(Enum):
    # 越小越好（value_type.LIB）
    LIB = 'LIB'
    # 越大越好（value_type.HIB）
    HIB = 'HIB'


class KeyItem(Enum):
    # 最大值
    key_max = 'max'
    # 最小值
    key_min = 'min'
    # 平均值
    key_mean = 'mean'
    # 中位数
    key_median = 'median'
    # 标准差
    key_standard_deviation = 'standard_deviation'


class PerfResult:
    def __init__(self, name: str, value_type: ValueType, key_item: KeyItem, unit: str):
        self._result = {
            "name": f'{name}',
            "type": f'{value_type}',
            "key": f'{key_item}',
            "unit": f'{unit}',
            "data": {
                "100": {
                    "max": 0,
                    "min": 0,
                    "mean": 0,
                    "median": 0,
                    "standard_deviation": 0,
                    "dist_20": [0] * 20,
                    "dist_100": [0] * 100
                }
            }
        }

    @property
    def result(self):
        return self._result


class TSTPerf:
    def __init__(self):
        self._result = dict()

    @abc.abstractmethod
    def run(self):
        pass

    def add_result(self, result: PerfResult):
        if result.result['name'] in self._result:
            raise KeyError(f'the result with name {result.result["name"]} has existed')
        self._result[result.result['name']] = result.result

    @property
    def results(self):
        return self._result

    def report(self):
        print(json.dumps(self.results, indent=4, ensure_ascii=False))


class PerfSysBench(TSTPerf):
    def __init__(self, name: str, sysbench: str, testname: str, general_opt: str = None, test_opt: str = None):
        super(PerfSysBench, self).__init__()
        self.name = name
        self.sysbench = sysbench
        self.prepare = None
        self.cleanup = None
        self.testname = testname
        self.general_opt = general_opt
        self.test_opt = test_opt
        self.command = f'{sysbench} {self.general_opt if self.general_opt else ""} {testname} ' \
                       f'{self.test_opt if self.test_opt else ""} run'
        self.outs = None
        self.errs = None

    def run(self, timeout=None):
        if self.prepare is not None and callable(self.prepare):
            self.prepare()
        proc = subprocess.Popen(self.command, shell=True, encoding='utf-8', stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)
        self.outs, self.errs = proc.communicate(timeout=timeout)
        if self.cleanup is not None and callable(self.cleanup):
            self.cleanup()
        print(f'execute command [{self.command}] get exit code {proc.returncode}, output:')
        print(self.outs)
        if self.errs:
            print('errors:')
            print(self.errs)
        self.parse_add_result()

    def get_cpu_result(self):
        result = PerfResult(name=self.name, value_type=ValueType.LIB, key_item=KeyItem.key_mean,
                            unit='ms')
        for line in self.outs.splitlines():
            if 'avg:' in line:
                mean = float(line.split(':')[1].strip())
                result.result['data']['100']['mean'] = mean
                return result

    def get_fileio_result(self, data_type):
        result = PerfResult(name=f'{self.name}-{data_type}', value_type=ValueType.HIB, key_item=KeyItem.key_mean,
                            unit='MiB/s')
        for line in self.outs.splitlines():
            if f'{data_type}:' in line:
                mean = float((line.split('IOPS')[1]).split(' ')[1].strip())
                result.result['data']['100']['mean'] = mean
                return result

    def get_memory_result(self):
        result = PerfResult(name=self.name, value_type=ValueType.LIB, key_item=KeyItem.key_mean,
                            unit='MiB/s')
        for line in self.outs.splitlines():
            if 'MiB/sec' in line:
                mean = float((line.split('(')[1]).split('MiB')[0].strip())
                result.result['data']['100']['mean'] = mean
                return result
    def get_threads_result(self):
        result = PerfResult(name=self.name, value_type=ValueType.LIB, key_item=KeyItem.key_mean,
                            unit='ms')
        for line in self.outs.splitlines():
            if 'avg:' in line:
                mean = float(line.split(':')[1].strip())
                result.result['data']['100']['mean'] = mean
                return result
    def get_mutex_result(self):
        result = PerfResult(name=self.name, value_type=ValueType.LIB, key_item=KeyItem.key_mean,
                            unit='ms')
        for line in self.outs.splitlines():
            if 'avg:' in line:
                mean = float(line.split(':')[1].strip())
                result.result['data']['100']['mean'] = mean
                return result
    def parse_add_result(self):
        if self.outs is None:
            raise Exception('test output is None')
        if self.testname == 'cpu':
            self.add_result(self.get_cpu_result())
        elif self.testname == 'fileio':
            if re.match(r'read:\s+IOPS=0.0', self.outs):
                self.add_result(self.get_fileio_result('write'))
            elif re.match(r'write:\s+IOPS=0.0', self.outs):
                self.add_result(self.get_fileio_result('read'))
            else:
                self.add_result(self.get_fileio_result('read'))
                self.add_result(self.get_fileio_result('write'))
        elif self.testname == 'memory':
            self.add_result(self.get_memory_result())
        elif self.testname == 'threads':
            self.add_result(self.get_threads_result())
        elif self.testname == 'mutex':
            self.add_result(self.get_mutex_result())
        else:
            raise Exception(f'unknown test name {self.testname}')

class PerfStream(TSTPerf):
    def __init__(self, name: str, stream: str, general_opt: str = None):
        super(PerfStream, self).__init__()
        self.name = name
        self.stream = stream
        self.general_opt = general_opt
        self.prepare = None
        self.cleanup = None
        self.command = f'{stream} {self.general_opt if self.general_opt else ""}'
        self.outs = None
        self.errs = None

    def run(self, timeout=None):
        if self.prepare is not None and callable(self.prepare):
            self.prepare()
        proc = subprocess.Popen(self.command, shell=True, encoding='utf-8', stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)
        self.outs, self.errs = proc.communicate(timeout=timeout)
        if self.cleanup is not None and callable(self.cleanup):
            self.cleanup()
        print(f'execute command [{self.command}] get exit code {proc.returncode}, output:')
        print(self.outs)
        if self.errs:
            print('errors:')
            print(self.errs)
        self.parse_add_result()

    def get_stream_result(self, data_type):
        result = PerfResult(name=f'{self.name}-{data_type}', value_type=ValueType.HIB, key_item=KeyItem.key_mean,
                            unit='MiB/s')
        for line in self.outs.splitlines():
            if f'{data_type}:' in line:
                mean = float((line.split(':')[1].strip()).split(' ')[0].strip())
                result.result['data']['100']['mean'] = mean
                return result
    def parse_add_result(self):
        if self.outs is None:
            raise Exception('test output is None')
        if self.stream is not None:
            self.add_result(self.get_stream_result('Copy'))
            self.add_result(self.get_stream_result('Scale'))
            self.add_result(self.get_stream_result('Add'))
            self.add_result(self.get_stream_result('Triad'))
        else:
            raise Exception(f'unknown test item {self.stream}')

class PerfHackbench(TSTPerf):
    def __init__(self, name: str, hackbench: str, general_opt: str = None):
        super(PerfHackbench, self).__init__()
        self.name = name
        self.hackbench = hackbench
        self.general_opt = general_opt
        self.prepare = None
        self.cleanup = None
        self.command = f'{hackbench} {self.general_opt if self.general_opt else ""}'
        self.outs = None
        self.errs = None

    def run(self, timeout=None):
        if self.prepare is not None and callable(self.prepare):
            self.prepare()
        proc = subprocess.Popen(self.command, shell=True, encoding='utf-8', stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)
        self.outs, self.errs = proc.communicate(timeout=timeout)
        if self.cleanup is not None and callable(self.cleanup):
            self.cleanup()
        print(f'execute command [{self.command}] get exit code {proc.returncode}, output:')
        print(self.outs)
        if self.errs:
            print('errors:')
            print(self.errs)
        self.parse_add_result()

    def get_hackbench_result(self):
        result = PerfResult(name=self.name, value_type=ValueType.LIB, key_item=KeyItem.key_mean,
                            unit='s')
        for line in self.outs.splitlines():
            if 'Time:' in line:
                mean = float(line.split(':')[1].strip())
                result.result['data']['100']['mean'] = mean
                return result
    def parse_add_result(self):
        if self.outs is None:
            raise Exception('test output is None')
        if self.hackbench is not None:
            self.add_result(self.get_hackbench_result())
        else:
            raise Exception(f'unknown test item {self.hackbench}')

class PerfLibMicro(TSTPerf):
    def __init__(self, name: str, libmicro: str, general_opt: str = None, test_opt: str = None):
        super(PerfLibMicro, self).__init__()
        self.name = name
        self.libmicro = libmicro
        self.prepare = None
        self.cleanup = None
        self.general_opt = general_opt
        self.test_opt = test_opt
        self.command = f'{libmicro} {self.general_opt if self.general_opt else ""} ' \
                       f'{self.test_opt if self.test_opt else ""}'
        self.outs = None
        self.errs = None

    def run(self, timeout=None):
        if self.prepare is not None and callable(self.prepare):
            self.prepare()
        proc = subprocess.Popen(self.command, shell=True, encoding='utf-8', stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)
        self.outs, self.errs = proc.communicate(timeout=timeout)
        if self.cleanup is not None and callable(self.cleanup):
            self.cleanup()
        print(f'execute command [{self.command}] get exit code {proc.returncode}, output:')
        print(self.outs)
        if self.errs:
            print('errors:')
            print(self.errs)
        self.parse_add_result()

    def get_libmicro_result(self):
        result = PerfResult(name=self.name, value_type=ValueType.LIB, key_item=KeyItem.key_mean,
                            unit='us')
        for line in self.outs.splitlines():
            if 'mean' in line:
                mean = float((line.split('mean')[1].strip()).split(' ')[0].strip())
                result.result['data']['100']['mean'] = mean
                return result
    def parse_add_result(self):
        if self.outs is None:
            raise Exception('test output is None')
        if self.libmicro is not None:
            self.add_result(self.get_libmicro_result())
        else:
            raise Exception(f'unknown test item {self.libmicro} ')

