#!/usr/bin/env python3
# coding: utf-8
# Time: 2022-08-24 12:22:09
# Desc: 系统调度

import os, time
from multiprocessing import Process, cpu_count


def exec_cpu(cpu: int, rate: float, interval: int, timeout: int) -> None:
    t_start = time.time()
    while time.time() - t_start < timeout:
        if ((time.time() - t_start) / interval) % 1 < rate:
            pass
        else:
            time.sleep((1 - rate) * interval)
    print(f'cpu {cpu} execute terminated')


def set_cpu_rate_of_system(rate: float, interval: int = 1, timeout: int = 10) -> None:
    """
    设置系统CPU使用率到指定值
    :param rate: 系统CPU使用率百分比, [0, cpu_num]
    :param interval: 设置使用率的采样间隔时间
    :param timeout: 设置使用率的时间
    :return: None
    """
    cpu_num = cpu_count()
    if (rate < 0 or rate > cpu_num):
        print(f'Input usage rate is {rate}, which must be a float value between 0 and {cpu_num}!')
        return
    if (interval <= 0):
        print(f'Input interval is {interval}, which must be a positive number!')
        return
    if (timeout <= 0):
        print(f'Input timeout is {timeout}, which must be a positive number!')
        return

    ps_list = []
    cpu_rate = rate / cpu_num
    for i in range(0, cpu_num):
        ps_list.append(Process(target = exec_cpu, args = (i, cpu_rate, interval, timeout)))
    for p in ps_list:
        p.start()
    for p in ps_list:
        p.join()
    print("all cpus execute over")


def exec_on_specific_cpu(cpu: int, rate: float, interval: int, timeout: int) -> None:
    pid = os.getpid()
    os.sched_setaffinity(pid, {cpu})
    t_start = time.time()
    while time.time() - t_start < timeout:
        if ((time.time() - t_start) / interval) % 1 < rate:
            pass
        else:
            time.sleep((1 - rate) * interval)
    print(f'cpu {cpu} execute terminated')


def set_cpu_rate_of_cpu(cpu_index: int, rate: float, interval: int = 1, timeout : int = 10) -> Process:
    """
    设置某个CPU的使用率到指定值
    :param cpu_index: cpu编号
    :param rate: CPU使用率百分比, [0, 1]
    :param interval: 设置使用率的采样间隔时间
    :param timeout: 设置使用率的时间
    :return: None
    """
    if (rate < 0 or rate > 1):
        print(f'Input usage rate is {rate}, which must be a float value between 0 and 1!')
        return
    if (interval <= 0):
        print(f'Input interval is {interval}, which must be a positive number!')
        return
    if (timeout <= 0):
        print(f'Input timeout is {timeout}, which must be a positive number!')
        return
    pid = os.getpid()
    eligible_cpu_set = os.sched_getaffinity(pid)
    if (cpu_index not in eligible_cpu_set):
        print(f'Input cpu index is {cpu_index}, which is not valid! ' +
              f'The eligible cpu set is {eligible_cpu_set}')
        return

    print(f'Set cpu usage of cpu{cpu_index} to {rate}')

    p = Process(target = exec_on_specific_cpu, args = (cpu_index, rate, interval, timeout))
    p.start()
    return p


def set_cpu_rate_of_task(rate: float, interval: int = 1, timeout : int = 10) -> None:
    """
    设置进程的使用率到指定值
    :param rate: 进程CPU使用率百分比, [0, 1]
    :param interval: 设置使用率的采样间隔时间
    :param timeout: 设置使用率的时间
    :return: None
    """
    if (rate < 0 or rate > 1):
        print(f'Input usage rate is {rate}, which must be a float value between 0 and 1!')
        return
    if (interval <= 0):
        print(f'Input interval is {interval}, which must be a positive number!')
        return
    if (timeout <= 0):
        print(f'Input timeout is {timeout}, which must be a positive number!')
        return

    pid = os.getpid()
    print(f'set cpu usage of pid {pid} to {rate}')
    t_start = time.time()
 
    while time.time() - t_start < timeout:
        if ((time.time() - t_start) / interval) % 1 < rate:
            pass
        else:
            time.sleep((1 - rate) * interval)

if __name__ == '__main__':
    # set_cpu_rate_of_system(4, 1, 60)
    p = set_cpu_rate_of_cpu(1, 0.3, 1, 30)
    print('joining')
    p.join()
    print('cpu test finished')
    # set_cpu_rate_of_task(1.5, 1, 20)

