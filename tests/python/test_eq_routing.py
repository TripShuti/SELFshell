# ============================================================
# tests/python/test_eq_routing.py — перевірки системного EQ з браузером, hotplug і внутрішніми фільтрами.
# ============================================================
import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "quickshell/scripts"))
import eq_routing


SINKS = [
    {"index": 36, "name": "SELFshell_EQ", "properties": {"object.id": "33"}},
    {"index": 1619, "name": "hdmi"},
]
STREAMS = [
    {"index": 37, "sink": 1619, "client": None,
     "properties": {"node.name": "output.filter-chain-1076-29", "node.virtual": "true"}},
    {"index": 97, "sink": 36, "client": "96",
     "properties": {"application.name": "Player"}},
    {"index": 1814, "sink": 1619, "client": "1717",
     "properties": {"application.name": "LibreWolf", "object.id": "66"}},
    {"index": 1953, "sink": 1619, "client": "1717",
     "properties": {"application.name": "LibreWolf", "object.id": "101"}},
]


class AudioServer:
    def __init__(self, streams=None):
        self.streams = copy.deepcopy(STREAMS if streams is None else streams)
        self.default = "hdmi"
        self.calls = []
        self.on_default = None
        self.on_move = None

    def pactl(self, *args):
        self.calls.append(args)
        if args == ("-f", "json", "list", "sinks"):
            return json.dumps(SINKS)
        if args == ("-f", "json", "list", "sink-inputs"):
            return json.dumps(self.streams)
        if args == ("get-default-sink",):
            return self.default
        if args[0] == "set-default-sink":
            self.default = args[1]
            if self.on_default:
                self.on_default()
            return ""
        if args[0] == "move-sink-input":
            index, target = args[1:]
            stream = next(s for s in self.streams if str(s["index"]) == index)
            if self.on_move:
                self.on_move(stream, target)
            stream["sink"] = next(s["index"] for s in SINKS if s["name"] == target)
            return ""
        raise AssertionError(args)


class EqRoutingTest(unittest.TestCase):
    def test_browser_bypassing_default_is_moved_by_pulse_index(self):
        self.assertEqual(eq_routing.moves(SINKS, STREAMS, "SELFshell_EQ"),
                         ("SELFshell_EQ", ["1814", "1953"]))

    def test_disable_leaves_eq_output_on_hardware_and_moves_player(self):
        self.assertEqual(eq_routing.moves(SINKS, STREAMS, "1619"), ("hdmi", ["97"]))

    def test_internal_virtual_and_recording_streams_are_not_routed(self):
        streams = [
            {"index": 1, "sink": 1619, "client": 5, "properties": {"node.virtual": True}},
            {"index": 2, "sink": 1619, "client": None, "properties": {}},
            {"index": 3, "sink": 1619, "client": 6,
             "properties": {"media.class": "Stream/Input/Audio"}},
        ]
        self.assertEqual(eq_routing.moves(SINKS, streams, "SELFshell_EQ")[1], [])

    def test_already_routed_programs_do_not_trigger_more_moves(self):
        streams = [dict(s, sink=36) for s in STREAMS]
        self.assertEqual(eq_routing.moves(SINKS, streams, "SELFshell_EQ")[1], [])

    def test_missing_target_fails_before_changing_default_or_moving_streams(self):
        server = AudioServer()
        with patch.object(eq_routing, "pactl", side_effect=server.pactl):
            with self.assertRaises(ValueError):
                eq_routing.route("missing", make_default=True)
        self.assertFalse(any(c[0] in ("set-default-sink", "move-sink-input") for c in server.calls))

    def test_route_reasserts_default_and_repairs_all_browser_streams(self):
        server = AudioServer()
        with patch.object(eq_routing, "pactl", side_effect=server.pactl):
            self.assertEqual(eq_routing.route("SELFshell_EQ", make_default=True), "SELFshell_EQ")
        self.assertEqual(server.default, "SELFshell_EQ")
        self.assertTrue(all(s["sink"] == 36 for s in server.streams if s["client"] is not None))
        self.assertEqual(server.streams[0]["sink"], 1619)

    def test_default_is_changed_before_snapshot_to_catch_recreated_browser(self):
        server = AudioServer([])
        server.on_default = lambda: server.streams.append(copy.deepcopy(STREAMS[2]))
        with patch.object(eq_routing, "pactl", side_effect=server.pactl):
            eq_routing.route("SELFshell_EQ", make_default=True)
        self.assertEqual(server.streams[0]["sink"], 36)

    def test_browser_restarted_during_move_is_caught_by_post_move_verification(self):
        server = AudioServer([STREAMS[2]])
        def restart(stream, target):
            if stream["index"] == 1814:
                replacement = copy.deepcopy(STREAMS[3])
                server.streams[:] = [replacement]
        server.on_move = restart
        with patch.object(eq_routing, "pactl", side_effect=server.pactl):
            eq_routing.route("SELFshell_EQ", make_default=True)
        self.assertEqual(server.streams[0]["index"], 1953)
        self.assertEqual(server.streams[0]["sink"], 36)

    def test_correct_default_is_not_rewritten(self):
        server = AudioServer([])
        server.default = "SELFshell_EQ"
        with patch.object(eq_routing, "pactl", side_effect=server.pactl):
            eq_routing.route("SELFshell_EQ", make_default=True)
        self.assertNotIn(("set-default-sink", "SELFshell_EQ"), server.calls)

    def test_stream_disappearing_during_move_is_harmless(self):
        server = AudioServer([STREAMS[2]])
        def disappear(stream, target):
            server.streams.clear()
            raise subprocess.CalledProcessError(1, "pactl")
        server.on_move = disappear
        with patch.object(eq_routing, "pactl", side_effect=server.pactl):
            eq_routing.route("SELFshell_EQ")

    def test_failed_move_of_existing_stream_is_reported(self):
        server = AudioServer([STREAMS[2]])
        def fail(stream, target):
            raise subprocess.CalledProcessError(1, "pactl")
        server.on_move = fail
        with patch.object(eq_routing, "pactl", side_effect=server.pactl):
            with self.assertRaises(subprocess.CalledProcessError):
                eq_routing.route("SELFshell_EQ")

    def test_successful_command_with_unchanged_route_is_not_reported_as_success(self):
        server = AudioServer([STREAMS[2]])
        def ignored_move(*args):
            if args[0] == "move-sink-input":
                return ""
            return server.pactl(*args)
        with patch.object(eq_routing, "pactl", side_effect=ignored_move):
            with self.assertRaisesRegex(ValueError, "did not settle"):
                eq_routing.route("SELFshell_EQ")

    def test_disable_resolves_saved_sink_by_exact_index_and_updates_default_first(self):
        server = AudioServer()
        server.default = "SELFshell_EQ"
        with patch.object(eq_routing, "pactl", side_effect=server.pactl):
            self.assertEqual(eq_routing.route("1619", make_default=True, fallback=True), "hdmi")
        self.assertEqual(server.default, "hdmi")
        self.assertTrue(all(s["sink"] == 1619 for s in server.streams))
        moves = [i for i,c in enumerate(server.calls) if c[0] == "move-sink-input"]
        self.assertLess(server.calls.index(("set-default-sink", "hdmi")), min(moves))

    def test_missing_saved_device_falls_back_to_available_hardware(self):
        server = AudioServer([])
        server.default = "SELFshell_EQ"
        with patch.object(eq_routing, "pactl", side_effect=server.pactl):
            self.assertEqual(eq_routing.route("disconnected", make_default=True, fallback=True), "hdmi")

    def test_no_hardware_cannot_report_successful_disable(self):
        server = AudioServer([])
        def no_hardware(*args):
            if args == ("-f", "json", "list", "sinks"):
                return json.dumps([SINKS[0]])
            return server.pactl(*args)
        with patch.object(eq_routing, "pactl", side_effect=no_hardware):
            with self.assertRaisesRegex(ValueError, "No audio output"):
                eq_routing.route("disconnected", make_default=True, fallback=True)
        self.assertFalse(any(c[0] == "set-default-sink" for c in server.calls))


if __name__ == "__main__":
    unittest.main()
