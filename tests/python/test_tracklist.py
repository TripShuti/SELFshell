# ============================================================
# tests/python/test_tracklist.py — unit-тести tracklist.py
# без живого D-Bus: модуль dbus підміняється стабом до імпорту.
# ============================================================
import io
import sys
import types
import unittest
from contextlib import redirect_stderr

_dbus = types.ModuleType("dbus")


class _Str(str):
    pass


class _List(list):
    pass


class _Int(int):
    pass


class _Float(float):
    pass


class _Bool(int):
    pass


class _Path(str):
    pass


_dbus.String = _Str
_dbus.Array = _List
_dbus.ObjectPath = _Path
_dbus.Int64 = _Int
_dbus.UInt64 = _Int
_dbus.Int32 = _Int
_dbus.UInt32 = _Int
_dbus.Double = _Float
_dbus.Boolean = _Bool


class DBusException(Exception):
    pass


_dbus.exceptions = types.SimpleNamespace(DBusException=DBusException)


class _FakeBus:
    def __init__(self, names):
        self._names = names

    def list_names(self):
        return self._names


_dbus.SessionBus = lambda: _FakeBus(_dbus._names)  # noqa: E731
sys.modules["dbus"] = _dbus

import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "quickshell", "scripts"))
import tracklist as tl  # noqa: E402


class BusNameTest(unittest.TestCase):
    def _names(self, names):
        _dbus._names = names

    def test_exact_full_name(self):
        self._names(["org.mpris.MediaPlayer2.spotify"])
        self.assertEqual(tl._player_bus_name("org.mpris.MediaPlayer2.spotify"),
                         "org.mpris.MediaPlayer2.spotify")

    def test_suffix_exact_beats_substring(self):
        # "fire" не має матчити firefox.instance1234 коли є точний fire
        self._names(["org.mpris.MediaPlayer2.firefox.instance1234",
                     "org.mpris.MediaPlayer2.fire"])
        self.assertEqual(tl._player_bus_name("fire"),
                         "org.mpris.MediaPlayer2.fire")

    def test_instance_suffix_match(self):
        self._names(["org.mpris.MediaPlayer2.chromium.instance1172"])
        self.assertEqual(tl._player_bus_name("chromium.instance1172"),
                         "org.mpris.MediaPlayer2.chromium.instance1172")

    def test_substring_last_resort(self):
        self._names(["org.mpris.MediaPlayer2.firefox.instance1234"])
        self.assertEqual(tl._player_bus_name("fire"),
                         "org.mpris.MediaPlayer2.firefox.instance1234")

    def test_no_match_returns_full(self):
        self._names(["org.freedesktop.DBus"])
        self.assertEqual(tl._player_bus_name("spotify"),
                         "org.mpris.MediaPlayer2.spotify")


class MetadataShapeTest(unittest.TestCase):
    def test_dict_result(self):
        out = tl._clean_metadata({"xesam:title": _Str("Song"),
                                  "mpris:length": _Int(210000000)})
        self.assertEqual(out["title"], "Song")
        self.assertEqual(out["length"], 210000000)

    def test_trackid_index(self):
        out = tl._clean_metadata({"mpris:trackid": _Path("/a/b/7")})
        self.assertEqual(out["index"], 7)


class MainErrorTest(unittest.TestCase):
    def test_dbus_error_reports_stderr_and_exits_1(self):
        real_argv = sys.argv
        # busname ловить DBusException сам — беремо list щоб дійти до main
        sys.argv = ["tracklist.py", "--player", "nope", "list"]
        _dbus._names = []
        orig = _dbus.SessionBus
        _dbus.SessionBus = lambda: (_ for _ in ()).throw(DBusException("gone"))  # noqa: E731
        try:
            err = io.StringIO()
            with redirect_stderr(err):
                with self.assertRaises(SystemExit) as cm:
                    tl.main()
            self.assertEqual(cm.exception.code, 1)
            self.assertIn("tracklist:", err.getvalue())
        finally:
            _dbus.SessionBus = orig
            sys.argv = real_argv


if __name__ == "__main__":
    unittest.main()
