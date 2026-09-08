# ============================================================
# tests/python/test_sysinfo.py — unit-тести sysinfo.py
# на штучних sysfs/meminfo (без доступу до реального заліза).
# ============================================================
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "quickshell", "scripts"))
import sysinfo as si  # noqa: E402


def _chip(root, name, temps):
    d = os.path.join(root, name)
    os.makedirs(d)
    with open(os.path.join(d, "name"), "w") as f:
        f.write(name + "\n")
    for sensor, val in temps.items():
        with open(os.path.join(d, sensor), "w") as f:
            f.write(str(val) + "\n")


class PickTempTest(unittest.TestCase):
    def test_prefers_k10temp_over_garbage(self):
        with tempfile.TemporaryDirectory() as tmp:
            hw = os.path.join(tmp, "hw")
            _chip(hw, "nct6798",
                  {"temp3_input": 84000, "temp1_input": 36000})
            _chip(hw, "k10temp", {"temp1_input": 35375})
            self.assertAlmostEqual(si.pick_cpu_temp(hw), 35.375)

    def test_skips_implausible_and_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            hw = os.path.join(tmp, "hw")
            _chip(hw, "nct6798", {"temp1_input": 0})
            self.assertIsNone(si.pick_cpu_temp(hw))
            self.assertIsNone(si.pick_cpu_temp(os.path.join(tmp, "nope")))


class FreqTest(unittest.TestCase):
    def test_avg_over_policies(self):
        with tempfile.TemporaryDirectory() as tmp:
            for i, v in ((0, 3600000), (1, 4400000)):
                d = os.path.join(tmp, "policy%d" % i)
                os.makedirs(d)
                with open(os.path.join(d, "scaling_cur_freq"), "w") as f:
                    f.write(str(v) + "\n")
            self.assertEqual(si.avg_freq_mhz(tmp, "/nonexistent"), 4000)

    def test_cpuinfo_fallback(self):
        with tempfile.TemporaryDirectory() as tmp:
            cpuinfo = os.path.join(tmp, "cpuinfo")
            with open(cpuinfo, "w") as f:
                f.write("cpu MHz\t\t: 3700.000\ncpu MHz\t\t: 3900.000\n")
            self.assertEqual(
                si.avg_freq_mhz(os.path.join(tmp, "empty"), cpuinfo), 3800)


class MeminfoTest(unittest.TestCase):
    def test_used_pct(self):
        pct, total, used = si.parse_meminfo(
            "MemTotal:        8000000 kB\nMemAvailable:    6000000 kB\n")
        self.assertEqual(pct, 25)
        self.assertAlmostEqual(total, 7.6, places=1)
        self.assertIsNone(si.parse_meminfo("garbage"))


class MainTest(unittest.TestCase):
    def test_prints_valid_json(self):
        out = subprocess.run(
            [sys.executable, os.path.join(ROOT, "quickshell", "scripts", "sysinfo.py")],
            capture_output=True, text=True, timeout=30)
        self.assertEqual(out.returncode, 0)
        data = json.loads(out.stdout)
        for key in ("cpu_temp_c", "cpu_mhz", "mem_used_pct", "disks"):
            self.assertIn(key, data)


if __name__ == "__main__":
    unittest.main()
