#!/usr/bin/env python3
# ============================================================
# quickshell/scripts/sysinfo.py — міні-моніторинг для секції System: CPU температура/частота, пам'ять, диски одним JSON
# ============================================================
"""Друкує один рядок JSON: cpu_temp_c, cpu_mhz, mem_used_pct/total/used_gb,
disks [{mount, used_pct}]. Все читання — з /sys та /proc, без root і мережі.
Будь-який відсутній сенсор дає null — QML показує прочерк."""

import json
import os
import sys


def pick_cpu_temp(hwmon_root="/sys/class/hwmon"):
    """Температура CPU в °C. Пріоритет: k10temp/Tctl (AMD), coretemp/Package
    (Intel), далі перший правдоподібний temp1_input (10–115°C відсікає сміття
    на кшталт AUXTIN). Повертає float або None."""
    try:
        chips = sorted(os.listdir(hwmon_root))
    except OSError:
        return None
    fallback = None
    for chip in chips:
        base = os.path.join(hwmon_root, chip)
        try:
            with open(os.path.join(base, "name")) as f:
                name = f.read().strip()
        except OSError:
            continue
        for sensor in ("temp1_input",):
            try:
                with open(os.path.join(base, sensor)) as f:
                    val = int(f.read().strip()) / 1000.0
            except (OSError, ValueError):
                continue
            if not 10.0 <= val <= 115.0:
                continue
            if name in ("k10temp", "coretemp", "zenpower", "k8temp"):
                return val
            if fallback is None:
                fallback = val
    return fallback


def avg_freq_mhz(cpufreq_root="/sys/devices/system/cpu/cpufreq", cpuinfo="/proc/cpuinfo"):
    """Середня поточна частота CPU в МГц. Спершу scaling_cur_freq політик,
    запасний шлях — поле cpu MHz з /proc/cpuinfo."""
    total, count = 0, 0
    try:
        policies = sorted(os.listdir(cpufreq_root))
    except OSError:
        policies = []
    for pol in policies:
        try:
            with open(os.path.join(cpufreq_root, pol, "scaling_cur_freq")) as f:
                total += int(f.read().strip()) // 1000
                count += 1
        except (OSError, ValueError):
            continue
    if count:
        return total // count
    try:
        with open(cpuinfo) as f:
            vals = [float(line.split(":")[1]) for line in f
                    if line.startswith("cpu MHz")]
    except (OSError, ValueError, IndexError):
        return None
    if not vals:
        return None
    return int(sum(vals) / len(vals))


def parse_meminfo(text):
    """(used_pct, total_gb, used_gb) з тексту /proc/meminfo."""
    mem = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0].endswith(":"):
            try:
                mem[parts[0][:-1]] = int(parts[1])
            except ValueError:
                continue
    total = mem.get("MemTotal", 0)
    avail = mem.get("MemAvailable", 0)
    if not total:
        return None
    used_kb = total - avail
    return (round(used_kb / total * 100),
            round(total / 1024 / 1024, 1),
            round(used_kb / 1024 / 1024, 1))


def disk_info(path):
    """(used_pct, total_gb, free_gb) для ФС, що містить path, або None."""
    try:
        st = os.statvfs(path)
    except OSError:
        return None
    if not st.f_blocks:
        return None
    total = st.f_blocks * st.f_frsize
    free = st.f_bavail * st.f_frsize
    used_pct = round((st.f_blocks - st.f_bavail) / st.f_blocks * 100)
    gb = 1024 ** 3
    return (used_pct, round(total / gb, 1), round(free / gb, 1))


def collect():
    mem = None
    try:
        with open("/proc/meminfo") as f:
            mem = parse_meminfo(f.read())
    except OSError:
        pass
    disks = []
    seen_devs = set()
    for mount in ("/", "/home"):
        try:
            dev = os.stat(mount).st_dev
        except OSError:
            continue
        if dev in seen_devs:
            continue
        seen_devs.add(dev)
        info = disk_info(mount)
        if info is not None:
            disks.append({"mount": mount, "used_pct": info[0],
                          "total_gb": info[1], "free_gb": info[2]})
    return {
        "cpu_temp_c": pick_cpu_temp(),
        "cpu_mhz": avg_freq_mhz(),
        "mem_used_pct": mem[0] if mem else None,
        "mem_total_gb": mem[1] if mem else None,
        "mem_used_gb": mem[2] if mem else None,
        "disks": disks,
    }


def main():
    print(json.dumps(collect()))


if __name__ == "__main__":
    main()
