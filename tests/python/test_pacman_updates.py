# ============================================================
# tests/python/test_pacman_updates.py — unit-тести pacman_updates.py
# на фейкових checkupdates/yay/pacman (без мережі та root).
# ============================================================
import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "quickshell", "scripts"))
import pacman_updates as pu  # noqa: E402


def _stub_bin(tmp, name, body):
    path = os.path.join(tmp, name)
    with open(path, "w") as f:
        # абсолютний шеврон: тести з урізаним PATH ламають /usr/bin/env-пошук
        f.write("#!/usr/bin/bash\n" + body + "\n")
    os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC)
    return path


class ParseLineTest(unittest.TestCase):
    def test_official(self):
        self.assertEqual(pu.parse_update_line("fish 4.9.1-1 -> 4.9.2-1"),
                         ("fish", "4.9.1-1", "4.9.2-1", None))

    def test_repo_prefix(self):
        self.assertEqual(pu.parse_update_line("aur/kcd-bin 1.0-1 -> 1.1-1"),
                         ("kcd-bin", "1.0-1", "1.1-1", "aur"))

    def test_epoch_version(self):
        self.assertEqual(pu.parse_update_line("vim 2:9.2-1 -> 2:9.3-1"),
                         ("vim", "2:9.2-1", "2:9.3-1", None))

    def test_ansi_stripped(self):
        self.assertEqual(
            pu.parse_update_line("\x1b[1mfish\x1b[0m 4.9.1-1 -> 4.9.2-1"),
            ("fish", "4.9.1-1", "4.9.2-1", None))

    def test_garbage_skipped(self):
        self.assertIsNone(pu.parse_update_line(""))
        self.assertIsNone(pu.parse_update_line("error: something broke"))
        self.assertIsNone(pu.parse_update_line("fish 4.9.1-1"))
        self.assertIsNone(pu.parse_update_line("weird name here -> there"))


class SizeTest(unittest.TestCase):
    def test_units(self):
        self.assertEqual(pu.size_to_bytes("865.53 KiB"),
                         int(865.53 * 1024))
        self.assertEqual(pu.size_to_bytes("3.60 MiB"),
                         int(3.60 * 1024 ** 2))
        self.assertEqual(pu.size_to_bytes("12 B"), 12)
        self.assertIsNone(pu.size_to_bytes(""))
        self.assertIsNone(pu.size_to_bytes("huge"))

    def test_human(self):
        self.assertEqual(pu.human_bytes(512), "512 B")
        self.assertEqual(pu.human_bytes(2048), "2.0 KiB")


class CollectTest(unittest.TestCase):
    def _env(self, tmp, checkupdates_body, yay_body=None, si_body=None):
        bin_d = os.path.join(tmp, "bin")
        os.makedirs(bin_d)
        _stub_bin(bin_d, "checkupdates", checkupdates_body)
        if yay_body is not None:
            _stub_bin(bin_d, "yay", yay_body)
        if si_body is not None:
            _stub_bin(bin_d, "pacman", si_body)
        db = os.path.join(tmp, "db")
        os.makedirs(os.path.join(db, "sync"))
        env = dict(os.environ)
        env["PATH"] = bin_d + ":/usr/bin:/bin"
        env["CHECKUPDATES_DB"] = db
        return env

    def _run_main(self, env):
        proc = subprocess.run(
            [sys.executable, os.path.join(ROOT, "quickshell", "scripts",
                                          "pacman_updates.py")],
            capture_output=True, text=True, env=env, timeout=60)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        return json.loads(proc.stdout)

    def test_official_and_aur_merged(self):
        si = ('if [[ "$*" == *-Si* ]]; then printf "Name            : fish\\n'
              'Repository      : extra\\nDescription     : shell\\n'
              'Download Size   : 3.60 MiB\\n\\n"; fi; exit 0')
        with tempfile.TemporaryDirectory() as tmp:
            env = self._env(
                tmp,
                'printf "fish 4.9.1-1 -> 4.9.2-1\\n"; exit 0',
                'printf "kcd-bin 1.0-1 -> 1.1-1\\n"; exit 0',
                si)
            data = self._run_main(env)
        self.assertTrue(data["ok"])
        self.assertEqual(data["repo_count"], 1)
        self.assertEqual(data["aur_count"], 1)
        self.assertEqual(data["helper"], "yay")
        by_name = {p["name"]: p for p in data["packages"]}
        self.assertEqual(by_name["fish"]["repo"], "extra")
        self.assertEqual(by_name["fish"]["download"], "3.60 MiB")
        self.assertEqual(by_name["kcd-bin"]["repo"], "aur")
        self.assertTrue(data["total_download"].endswith("MiB"))

    def test_no_updates_exit2(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = self._env(tmp, "exit 2", 'printf ""')
            data = self._run_main(env)
        self.assertTrue(data["ok"])
        self.assertEqual(data["packages"], [])
        self.assertEqual(data["repo_count"], 0)

    def test_missing_checkupdates(self):
        with tempfile.TemporaryDirectory() as tmp:
            bin_d = os.path.join(tmp, "bin")
            os.makedirs(bin_d)
            env = dict(os.environ)
            env["PATH"] = bin_d  # порожній: ні checkupdates, ні хелперів
            data = self._run_main(env)
        self.assertFalse(data["ok"])
        self.assertTrue(data["missing_checkupdates"])

    def test_offline_keeps_shape(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = self._env(tmp, 'echo "Cannot fetch updates" >&2; exit 1')
            data = self._run_main(env)
        self.assertFalse(data["ok"])
        self.assertTrue(data["error"])
        self.assertEqual(data["packages"], [])

    def test_no_helper_means_no_aur(self):
        with tempfile.TemporaryDirectory() as tmp:
            bin_d = os.path.join(tmp, "bin")
            os.makedirs(bin_d)
            _stub_bin(bin_d, "checkupdates",
                      'printf "fish 4.9.1-1 -> 4.9.2-1\\n"; exit 0')
            env = dict(os.environ)
            env["PATH"] = bin_d  # хелперів нема — AUR пропускається
            data = self._run_main(env)
        self.assertTrue(data["ok"])
        self.assertEqual(data["helper"], "")
        self.assertEqual(data["aur_count"], 0)


if __name__ == "__main__":
    unittest.main()
