# ============================================================
# tests/python/test_genshin.py — unit-тести genshin_stats.py
# без реальних HTTP-запитів (state-файли — в тимчасовій теці).
# ============================================================
import json
import os
import shutil
import sys
import tempfile
import unittest
from unittest import mock

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "quickshell", "scripts"))
import genshin_stats as gs  # noqa: E402


class EstimateLocalTest(unittest.TestCase):
    def test_partial_recovery_and_remaining_format(self):
        state = {"resin": 10, "max_resin": 200,
                 "full_at": 1005400.0, "synced_at": 999040.0}  # 960s тому
        with mock.patch.object(gs.time, "time", return_value=1000000.0):
            resin, recovery = gs.estimate_local(state)
        self.assertEqual(resin, 12)           # 960s / 480 = +2
        self.assertEqual(recovery, "1h 30m")  # залишок 5400s

    def test_full_at_reached(self):
        state = {"resin": 10, "max_resin": 200,
                 "full_at": 999600.0, "synced_at": 1000000.0}
        with mock.patch.object(gs.time, "time", return_value=1000000.0):
            resin, recovery = gs.estimate_local(state)
        self.assertEqual((resin, recovery), (200, "Full"))

    def test_caps_at_max_resin(self):
        state = {"resin": 190, "max_resin": 200,
                 "full_at": 1100000.0, "synced_at": 900000.0}  # 100000s тому
        with mock.patch.object(gs.time, "time", return_value=1000000.0):
            resin, recovery = gs.estimate_local(state)
        self.assertEqual(resin, 200)           # 190 + 208 регенерації > 200
        self.assertEqual(recovery, "27h 46m")  # залишок 100000s


class BuildTooltipTest(unittest.TestCase):
    def test_dailies_status(self):
        notes = {"finished_task_num": 4, "is_extra_task_reward_received": False,
                 "current_expedition_num": 2, "max_expedition_num": 4,
                 "current_home_coin": 0, "max_home_coin": 500,
                 "remain_resin_discount_num": 2}
        tip = gs.build_tooltip(10, 200, "0h 30m", notes, "✓ 5d")
        self.assertIn("Dailies: 4/4", tip)
        self.assertIn("Expeditions: 2/4", tip)
        self.assertIn("Bosses (discount): 2/3", tip)
        self.assertIn("Check-in: ✓ 5d", tip)

    def test_claimed_cache_note(self):
        notes = {"finished_task_num": 4, "is_extra_task_reward_received": True,
                 "current_expedition_num": 0, "max_expedition_num": 0,
                 "current_home_coin": 0, "max_home_coin": 0,
                 "remain_resin_discount_num": 0}
        tip = gs.build_tooltip(10, 200, "Full", notes, "✗", cache_note="\ncached")
        self.assertIn("\ncached", tip)


class DisplayTest(unittest.TestCase):
    def test_no_state_placeholder(self):
        self.assertEqual(gs.get_local_display({})["text"], " ...")
        self.assertEqual(gs.get_local_display(None)["text"], " ...")

    def test_local_display_with_sign_cache(self):
        now = 1000000.0
        with mock.patch.object(gs.time, "time", return_value=now):
            # дата береться на тому ж "замокнутому" годиннику (time.time
            # глобальний — впливає і на datetime.date.today())
            state = {"resin": 15, "max_resin": 200, "full_at": now + 3600, "synced_at": now,
                     "notes_cache": {"finished_task_num": 1, "is_extra_task_reward_received": False,
                                     "current_expedition_num": 0, "max_expedition_num": 0,
                                     "current_home_coin": 0, "max_home_coin": 0,
                                     "remain_resin_discount_num": 0},
                     "sign": {"date": gs.today_str(), "is_signed": True, "total_sign_day": 5}}
            out = gs.get_local_display(state)
        self.assertEqual(out["text"], " 15/200")
        self.assertIn("✓ 5d", out["tooltip"])
        self.assertEqual(out["class"], "normal")

    def test_cached_response_missing_state(self):
        out = gs._cached_response({})
        self.assertFalse(out["ok"])
        self.assertEqual(out["text"], " Error")


class StateFileTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="genshin-test-")
        self.patch_state = mock.patch.object(gs, "STATE_FILE", os.path.join(self.tmp, "state.json"))
        self.patch_log = mock.patch.object(gs, "REQUEST_LOG_FILE", os.path.join(self.tmp, "req.log"))
        self.state_file = self.patch_state.start()
        self.patch_log.start()
        self.addCleanup(self.patch_state.stop)
        self.addCleanup(self.patch_log.stop)
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def test_load_corrupt_returns_empty(self):
        with open(self.state_file, "w") as f:
            f.write("{broken")
        self.assertEqual(gs.load_state(), {})

    def test_save_load_roundtrip(self):
        gs.save_state({"resin": 42, "sign": {"is_signed": True}})
        self.assertEqual(gs.load_state()["resin"], 42)


class DoSyncTest(StateFileTest):
    NOTES = {"current_resin": 15, "max_resin": 200, "resin_recovery_time": 3600,
             "finished_task_num": 1, "is_extra_task_reward_received": False,
             "current_expedition_num": 0, "max_expedition_num": 0,
             "current_home_coin": 0, "max_home_coin": 0,
             "remain_resin_discount_num": 0}

    @mock.patch.object(gs, "_real_check_sign_status", return_value=(False, 0))
    @mock.patch.object(gs, "_real_get_notes", return_value=(NOTES, None))
    def test_fresh_sync(self, mock_notes, mock_sign):
        out = gs.do_sync()
        self.assertEqual(out["text"], " 15/200")
        self.assertIn("✗", out["tooltip"])
        state = gs.load_state()
        self.assertEqual(state["resin"], 15)
        self.assertEqual(state["max_resin"], 200)
        self.assertIn("full_at", state)
        self.assertIn("synced_at", state)

    @mock.patch.object(gs, "_real_check_sign_status", return_value=(False, 0))
    def test_throttle_within_min_interval(self, mock_sign):
        calls = []

        def fake_notes():
            calls.append(1)
            return self.NOTES, None

        with mock.patch.object(gs, "_real_get_notes", side_effect=fake_notes):
            gs.do_sync()
            out2 = gs.do_sync()          # < min_interval — без повторного запиту
        self.assertEqual(len(calls), 1)
        self.assertEqual(out2["text"], " 15/200")

    @mock.patch.object(gs, "_real_get_notes", side_effect=None)
    def test_rate_limit_backoff_uses_cache(self, mock_notes):
        gs.save_state({"resin": 10, "max_resin": 200,
                       "full_at": 1000000 + 3600, "synced_at": 1000000,
                       "backoff_until": 9e9,
                       "notes_cache": {"finished_task_num": 0},
                       "sign": {}})
        out = gs.do_sync()
        self.assertIn("Rate limit backoff", out["tooltip"])
        self.assertFalse(mock_notes.called)

    @mock.patch.object(gs, "_real_get_notes",
                       return_value=("", {"text": " Wait", "tooltip": "API Rate Limit. Wait 15 min."}))
    @mock.patch.object(gs, "time", wraps=gs.time)
    def test_rate_limit_sets_backoff(self, mock_time, mock_notes):
        mock_time.time.return_value = 1000000.0
        gs.save_state({"resin": 10, "max_resin": 200,
                       "full_at": 1000000 + 3600, "synced_at": 999900,   # поза throttle-вікном
                       "notes_cache": {"finished_task_num": 0}, "sign": {}})
        out = gs.do_sync()
        self.assertGreater(gs.load_state().get("backoff_until", 0), 1000000)
        self.assertIn("data from cache", out["tooltip"])

    @mock.patch.object(gs, "_real_get_notes",
                       return_value=("Error", {"text": " Error", "tooltip": "boom"}))
    def test_error_without_cache(self, mock_notes):
        out = gs.do_sync()
        self.assertFalse(out["ok"])
        self.assertEqual(out["class"], "error")


class CheckSignTest(unittest.TestCase):
    def test_cached_flag_when_fresh(self):
        today = gs.today_str()
        state = {"sign": {"date": today, "is_signed": True, "total_sign_day": 3}}
        with mock.patch.object(gs, "_real_check_sign_status") as real:
            is_signed, days = gs.check_sign_status(state)
        self.assertEqual((is_signed, days), (True, 3))
        real.assert_not_called()

    @mock.patch.object(gs, "_real_check_sign_status", return_value=(None, "offline"))
    def test_api_failure_falls_back_to_cache(self, mock):
        today = gs.today_str()
        state = {"sign": {"date": today, "is_signed": False, "total_sign_day": 2}}
        is_signed, days = gs.check_sign_status(state)
        self.assertEqual((is_signed, days), (False, 2))


class DoSignTest(StateFileTest):
    def test_cached_already_done_skips_api(self):
        today = gs.today_str()
        gs.save_state({"sign": {"date": today, "is_signed": True, "total_sign_day": 4}})
        with mock.patch.object(gs.requests, "post") as mock_post:
            ok, msg = gs.do_sign()
        self.assertTrue(ok)
        self.assertIn("cache", msg)
        mock_post.assert_not_called()


if __name__ == "__main__":
    unittest.main()