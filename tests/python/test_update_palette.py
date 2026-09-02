# ============================================================
# tests/python/test_update_palette.py — unit-тести update-palette.py:
# колірні хелпери, atomic_write, ensure_qt6ct_palette та end-to-end
# генерація всіх тем із мокнутим matugen (HOME — тимчасова тека).
# ============================================================
import io
import json
import os
import shutil
import sys
import tempfile
import unittest
from unittest import mock

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPTS = os.path.join(ROOT, "quickshell", "scripts")
sys.path.insert(0, SCRIPTS)

# update-palette.py має дефіс у назві — звичайний import неможливий,
# завантажуємо модуль за шляхом через importlib
import importlib.util
_spec = importlib.util.spec_from_file_location(
    "update_palette_mod", os.path.join(SCRIPTS, "update-palette.py"))
up = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(up)

# Синтетична відповідь matugen (формат "matugen image ... -j hex")
MATUGEN_OUT = json.dumps({
    "colors": {
        "on_background": {"dark": {"color": "#e0e4e8"}},
        "outline": {"dark": {"color": "#8a9199"}},
        "on_surface_variant": {"dark": {"color": "#9aa2ab"}},
        "tertiary": {"dark": {"color": "#f2cc8f"}},
        "secondary": {"dark": {"color": "#a3c8ff"}},
        "primary": {"dark": {"color": "#7db3ff"}},
        "background": {"dark": {"color": "#14181c"}},
        "on_surface": {"dark": {"color": "#c5cbd2"}},
        "on_primary": {"dark": {"color": "#0a1118"}},
        "error": {"dark": {"color": "#ff7c8a"}},
    },
    "palettes": {
        "primary": {"70": {"color": "#a9ccff"}},
        "neutral": {"20": {"color": "#1e2328"}, "25": {"color": "#23292f"},
                    "35": {"color": "#31383f"}, "90": {"color": "#d3d9df"},
                    "95": {"color": "#e7ebef"}},
        "error": {"80": {"color": "#ff9aa5"}},
        "secondary": {"70": {"color": "#c0d8ff"}},
        "tertiary": {"70": {"color": "#f5d9a8"}, "80": {"color": "#faddbe"}},
    },
})


class FakeProc:
    stdout = MATUGEN_OUT


class ColorHelpersTest(unittest.TestCase):
    def test_parse_hex(self):
        self.assertEqual(up.parse_hex("#aabbcc"), (0xAA, 0xBB, 0xCC))
        self.assertEqual(up.parse_hex("#FFAABB"), (255, 170, 187))
        self.assertEqual(up.parse_hex("#ffaabbcc"), (170, 187, 204))  # ARGB → RGB

    def test_to_hex_roundtrip(self):
        self.assertEqual(up.to_hex(170, 187, 204), "#aabbcc")

    def test_blend(self):
        self.assertEqual(up.blend("#000000", "#ffffff", 0.0), "#000000")
        self.assertEqual(up.blend("#000000", "#ffffff", 0.5), "#808080")
        self.assertEqual(up.blend("#000000", "#ffffff", 1.0), "#ffffff")

    def test_alpha(self):
        self.assertEqual(up.alpha("#ffffff", 0.5), "#80ffffff")
        self.assertEqual(up.alpha("#ffffff", 1.5), "#ffffffff")  # clamping
        self.assertEqual(up.alpha("#ffffff", -1), "#00ffffff")

    def test_qt_argb_and_foot_hex(self):
        self.assertEqual(up.qt_argb("#12ab34"), "#ff12ab34")
        self.assertEqual(up.foot_hex("#12ab34"), "12ab34")


class AtomicWriteTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="atomic-")
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.target = os.path.join(self.tmp, "out.txt")

    def test_writes_content(self):
        up.atomic_write(self.target, "hello\n")
        with open(self.target) as f:
            self.assertEqual(f.read(), "hello\n")

    def test_failure_leaves_target_and_cleans_tmp(self):
        up.atomic_write(self.target, "old")
        with mock.patch.object(up.os, "replace", side_effect=OSError("boom")):
            with self.assertRaises(OSError):
                up.atomic_write(self.target, "new")
        with open(self.target) as f:
            self.assertEqual(f.read(), "old")
        leftovers = [n for n in os.listdir(self.tmp) if n.endswith(".tmp")]
        self.assertEqual(leftovers, [])


class Qt6ctConfTest(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.mkdtemp(prefix="qt6ct-home-")
        self.conf = os.path.join(self.home, ".config", "qt6ct", "qt6ct.conf")
        self.addCleanup(shutil.rmtree, self.home, True)
        self.env = mock.patch.dict(os.environ, {"HOME": self.home})

    def test_creates_section_with_missing_keys(self):
        with self.env:
            up.ensure_qt6ct_palette("/x/Quickshell.conf")
        with open(self.conf) as f:
            content = f.read()
        self.assertIn("[Appearance]", content)
        self.assertIn("color_scheme_path=/x/Quickshell.conf", content)
        self.assertIn("custom_palette=true", content)

    def test_replaces_existing_keys_and_keeps_others(self):
        os.makedirs(os.path.dirname(self.conf))
        with open(self.conf, "w") as f:
            f.write("[Appearance]\ncolor_scheme_path=/old\ncustom_palette=false\n\n[Window]\nstyle=kvantum\n")
        with self.env:
            up.ensure_qt6ct_palette("/new/Quickshell.conf")
        with open(self.conf) as f:
            content = f.read()
        self.assertIn("color_scheme_path=/new/Quickshell.conf", content)
        self.assertNotIn("/old", content)
        self.assertIn("custom_palette=true", content)
        self.assertIn("[Window]\nstyle=kvantum", content)

    def test_appends_section_when_absent(self):
        os.makedirs(os.path.dirname(self.conf))
        with open(self.conf, "w") as f:
            f.write("[IconTheme]\nname=Test\n")
        with self.env:
            up.ensure_qt6ct_palette("/y/Quickshell.conf")
        with open(self.conf) as f:
            content = f.read()
        self.assertIn("[IconTheme]", content)
        self.assertIn("[Appearance]", content)
        self.assertIn("color_scheme_path=/y/Quickshell.conf", content)


class ListWallpapersTest(unittest.TestCase):
    def test_orders_by_mtime_excluding_current(self):
        wp = tempfile.mkdtemp(prefix="wp-")
        self.addCleanup(shutil.rmtree, wp, True)
        paths = []
        for name, mtime in [("old.jpg", 1000.0), ("new.gif", 3000.0)]:
            p = os.path.join(wp, name)
            with open(p, "w") as f:
                f.write("x")
            os.utime(p, (mtime, mtime))
            paths.append(p)
        with open(os.path.join(wp, "current.png"), "w") as f:
            f.write("x")
        with open(os.path.join(wp, "current-lock.jpg"), "w") as f:
            f.write("x")
        with open(os.path.join(wp, "current.jpg"), "w") as f:
            f.write("x")
        os.utime(os.path.join(wp, "current.jpg"), (9000.0, 9000.0))
        with mock.patch.object(up, "WP_DIR", wp), mock.patch("sys.stdout", new_callable=io.StringIO) as out:
            up.list_wallpapers()
        self.assertEqual(out.getvalue(), paths[1] + "\n" + paths[0])

    def test_missing_dir_prints_nothing(self):
        with mock.patch.object(up, "WP_DIR", "/nonexistent-wp-dir"), \
             mock.patch("sys.stdout", new_callable=io.StringIO) as out:
            up.list_wallpapers()
        self.assertEqual(out.getvalue(), "")


class CurrentWallpaperTest(unittest.TestCase):
    def test_prefers_static_lock_frame(self):
        wp = tempfile.mkdtemp(prefix="wp-")
        self.addCleanup(shutil.rmtree, wp, True)
        with open(os.path.join(wp, "current-lock.jpg"), "w") as f:
            f.write("x")
        p = os.path.join(wp, "current.gif")
        with open(p, "w") as f:
            f.write("y")
        os.utime(p, (9999.0, 9999.0))
        with mock.patch.object(up, "WP_DIR", wp), mock.patch("sys.stdout", new_callable=io.StringIO) as out:
            up.current_wallpaper()
        self.assertEqual(out.getvalue(), os.path.join(wp, "current-lock.jpg"))

    def test_returns_newest_current_file_without_lock_frame(self):
        wp = tempfile.mkdtemp(prefix="wp-")
        self.addCleanup(shutil.rmtree, wp, True)
        for name, mtime in [("current.png", 1000.0), ("current.gif", 3000.0)]:
            p = os.path.join(wp, name)
            with open(p, "w") as f:
                f.write("x")
            os.utime(p, (mtime, mtime))
        with mock.patch.object(up, "WP_DIR", wp), mock.patch("sys.stdout", new_callable=io.StringIO) as out:
            up.current_wallpaper()
        self.assertEqual(out.getvalue(), os.path.join(wp, "current.gif"))

    def test_falls_back_to_any_static_wallpaper(self):
        wp = tempfile.mkdtemp(prefix="wp-")
        self.addCleanup(shutil.rmtree, wp, True)
        p = os.path.join(wp, "wall.png")
        with open(p, "w") as f:
            f.write("x")
        with mock.patch.object(up, "WP_DIR", wp), mock.patch("sys.stdout", new_callable=io.StringIO) as out:
            up.current_wallpaper()
        self.assertEqual(out.getvalue(), p)

    def test_accepts_gif_as_last_resort(self):
        wp = tempfile.mkdtemp(prefix="wp-")
        self.addCleanup(shutil.rmtree, wp, True)
        p = os.path.join(wp, "anim.gif")
        with open(p, "w") as f:
            f.write("x")
        with mock.patch.object(up, "WP_DIR", wp), mock.patch("sys.stdout", new_callable=io.StringIO) as out:
            up.current_wallpaper()
        self.assertEqual(out.getvalue(), p)

    def test_empty_dir_prints_nothing(self):
        wp = tempfile.mkdtemp(prefix="wp-")
        self.addCleanup(shutil.rmtree, wp, True)
        with mock.patch.object(up, "WP_DIR", wp), mock.patch("sys.stdout", new_callable=io.StringIO) as out:
            up.current_wallpaper()
        self.assertEqual(out.getvalue(), "")


class MainEndToEndTest(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.mkdtemp(prefix="palette-home-")
        self.qs_dir = os.path.join(self.home, "qs")
        os.makedirs(os.path.join(self.qs_dir, "data"))
        os.makedirs(os.path.join(self.home, ".config", "starship"))
        starship = os.path.join(self.home, ".config", "starship", "config.toml")
        with open(starship, "w") as f:
            f.write('[palettes.self]\nbackground = "#111111"\nred = "#ff0000"\n\n'
                    "[palettes.other]\nred = '#0000ff'\n")
        self.addCleanup(shutil.rmtree, self.home, True)
        self.ctx = [
            mock.patch.dict(os.environ, {"HOME": self.home}),
            mock.patch.object(up, "QS_DIR", self.qs_dir),
            mock.patch.object(up.subprocess, "run", return_value=FakeProc()),
            mock.patch.object(sys, "argv", ["update-palette.py", "wallpaper.jpg"]),
        ]
        for c in self.ctx:
            c.start()
        self.addCleanup(lambda: [c.stop() for c in self.ctx])

    def _read(self, rel):
        with open(os.path.join(self.home, rel)) as f:
            return f.read()

    def test_palette_json(self):
        self.assertEqual(up.main(), 0)
        with open(os.path.join(self.qs_dir, "data", "palette.json")) as f:
            palette = json.load(f)
        self.assertEqual(palette["font"], "JetBrainsMonoNL Nerd Font")
        self.assertEqual(palette["fg"], "#e0e4e8")
        self.assertEqual(palette["bg0H"], "#1e2328")
        self.assertEqual(palette["accent"], "#7db3ff")
        self.assertEqual(palette["green"], "#a9ccff")
        self.assertIn("bgLayer", palette)

    def test_kitty_and_fish(self):
        up.main()
        kitty = self._read(".config/kitty/current-theme.conf")
        self.assertIn("background              #1e2328", kitty)
        self.assertIn("selection_foreground", kitty)
        fish = self._read(".config/fish/conf.d/99-palette.fish")
        self.assertIn('set -g fish_color_normal "#e0e4e8"', fish)

    def test_starship_palette_updated(self):
        up.main()
        content = self._read(".config/starship/config.toml")
        self.assertIn('background = "#1e2328"', content)
        self.assertIn('red = "#ff9aa5"', content)
        self.assertNotIn('red = "#ff0000"', content)
        self.assertIn("[palettes.other]", content)  # решта файлу збережена

    def test_yazi_foot_qt6ct(self):
        up.main()
        yazi = self._read(".config/yazi/flavors/palette.yazi/flavor.toml")
        self.assertIn("[mgr]", yazi)
        yazi_theme = self._read(".config/yazi/theme.toml")
        self.assertIn('[flavor]', yazi_theme)
        foot = self._read(".config/foot/colors.ini")
        self.assertIn("foreground=e0e4e8", foot)
        foot_ini = self._read(".config/foot/foot.ini")
        self.assertIn("include=~/.config/foot/colors.ini", foot_ini)
        qt = self._read(".config/qt6ct/colors/Quickshell.conf")
        self.assertIn("active_colors=", qt)
        self.assertIn("#ff7db3ff", qt)  # accent (primary) в ролі Highlight
        qt6ct = self._read(".config/qt6ct/qt6ct.conf")
        self.assertIn("color_scheme_path=", qt6ct)

    def test_no_tmp_leftovers(self):
        up.main()
        leftovers = []
        for dirpath, _, files in os.walk(self.home):
            leftovers += [os.path.join(dirpath, n) for n in files if n.endswith(".tmp")]
        self.assertEqual(leftovers, [])


if __name__ == "__main__":
    unittest.main()