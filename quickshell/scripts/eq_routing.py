#!/usr/bin/env python3
# ============================================================
# quickshell/scripts/eq_routing.py — маршрутизація програм через EQ без перенесення внутрішніх аудіофільтрів.
# ============================================================
import argparse
import json
import subprocess
import sys


def pactl(*args):
    return subprocess.run(
        ["pactl", *args], check=True, capture_output=True, text=True, timeout=5
    ).stdout


def moves(sinks, streams, target):
    sink = next((s for s in sinks
                 if s.get("name") == target or str(s.get("index")) == target), None)
    if sink is None:
        raise ValueError("Audio output is unavailable: " + target)
    result = []
    for stream in streams:
        props = stream.get("properties") or {}
        # Виходи filter-chain/loopback не є програмами: перенесення виходу
        # самого EQ на його вхід створило б аудіопетлю.
        if stream.get("client") is None or str(props.get("node.virtual", "")).lower() == "true":
            continue
        if props.get("media.class", "Stream/Output/Audio") != "Stream/Output/Audio":
            continue
        if str(stream.get("sink")) != str(sink["index"]):
            result.append(str(stream["index"]))
    return sink["name"], result


def route(target, make_default=False, fallback=False):
    sinks = json.loads(pactl("-f", "json", "list", "sinks"))
    default = pactl("get-default-sink").strip() if make_default or fallback else ""
    if fallback:
        hardware = [s for s in sinks if s["name"] != "SELFshell_EQ"]
        selected = next((s for s in hardware if s["name"] == target or str(s["index"]) == target), None)
        selected = selected or next((s for s in hardware if s["name"] == default), None)
        selected = selected or next((s for s in hardware if s.get("state") == "RUNNING"), None)
        selected = selected or next(iter(hardware), None)
        if selected is None:
            raise ValueError("No audio output is available without EQ")
        target = selected["name"]
    name, _ = moves(sinks, [], target)
    if make_default and default != name:
        pactl("set-default-sink", name)
    # Зміна default може пересоздати потоки. Знімок до неї швидко застаріває;
    # перевіряємо новий стан після перенесення, а не лише exit code pactl.
    for attempt in range(4):
        streams = json.loads(pactl("-f", "json", "list", "sink-inputs"))
        _, indexes = moves(sinks, streams, name)
        if not indexes:
            if make_default and pactl("get-default-sink").strip() != name:
                raise ValueError("Default audio output changed during routing")
            return name
        if attempt == 3:
            raise ValueError("Application audio did not settle on " + name)
        for index in indexes:
            try:
                pactl("move-sink-input", index, name)
            except subprocess.CalledProcessError:
                # Короткий потік міг завершитися після знімка; це не збій EQ.
                current = json.loads(pactl("-f", "json", "list", "sink-inputs"))
                if any(str(s.get("index")) == index for s in current):
                    raise


def main():
    parser = argparse.ArgumentParser(description="Route application audio to an output")
    parser.add_argument("target")
    parser.add_argument("--default", action="store_true", dest="make_default")
    parser.add_argument("--fallback", action="store_true")
    parser.add_argument("--print-target", action="store_true")
    args = parser.parse_args()
    try:
        target = route(args.target, args.make_default, args.fallback)
        if args.print_target:
            print(target)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        detail = (error.stderr or str(error)).strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
        print("[AudioEq] Routing failed: " + detail, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
