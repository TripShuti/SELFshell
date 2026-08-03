#!/usr/bin/env python3
# ============================================================
# scripts/tracklist.py — обгортка MPRIS TrackList D-Bus
# ============================================================
import argparse
import json
import sys
import dbus


MPRIS_IFACE = "org.mpris.MediaPlayer2"
TRACKLIST_IFACE = f"{MPRIS_IFACE}.TrackList"
PROPERTIES_IFACE = "org.freedesktop.DBus.Properties"
OBJECT_PATH = "/org/mpris/MediaPlayer2"


def _player_bus_name(name: str) -> str:
    if name.startswith(":") or name.startswith("org.mpris.MediaPlayer2"):
        return name
    full = f"{MPRIS_IFACE}.{name}"
    try:
        bus = dbus.SessionBus()
        names = bus.list_names()
        if full in names:
            return full
        # identity може не збігатись з well-known ім'ям (напр. chromium.instance1172)
        for n in names:
            if n.startswith(MPRIS_IFACE + ".") and name.lower() in n.lower():
                return n
    except dbus.DBusException:
        pass
    return full


def _connect(player: str):
    bus = dbus.SessionBus()
    proxy = bus.get_object(_player_bus_name(player), OBJECT_PATH, introspect=False)
    return bus, proxy


def _method(proxy, iface: str, name: str):
    # get_dbus_method не робить інтроспекцію — плеєр може її не підтримувати
    return proxy.get_dbus_method(name, iface)


def _tracklist_iface(proxy):
    return _method(proxy, TRACKLIST_IFACE, "GetTracksMetadata")


def _properties_get(proxy, iface: str, prop: str):
    get = _method(proxy, PROPERTIES_IFACE, "Get")
    return get(iface, prop)


def _go_to(proxy):
    return _method(proxy, TRACKLIST_IFACE, "GoTo")


def cmd_list(player: str):
    _, proxy = _connect(player)
    tracks = _properties_get(proxy, TRACKLIST_IFACE, "Tracks")
    ids = [str(t) for t in tracks]
    print(json.dumps(ids))


def cmd_metadata(player: str, track_ids: list[str]):
    _, proxy = _connect(player)
    paths = [dbus.ObjectPath(t) for t in track_ids]
    result = _tracklist_iface(proxy)(paths)

    # Спека: a{oa{sv}} (dict {path: metadata}), але деякі плеєри (mpris-server)
    # повертають масив a{sv} у порядку запиту — обробляємо обидва варіанти.
    meta_by_id = {}
    if isinstance(result, dict):
        for track_id, meta in result.items():
            meta_by_id[str(track_id)] = _clean_metadata(meta)
    else:
        for tid, meta in zip(track_ids, result):
            meta_by_id[tid] = _clean_metadata(meta)
    tracks = [meta_by_id.get(tid) for tid in track_ids]
    # index у blacklist-віждетах quickshell — позиція в черзі
    for i, t in enumerate(tracks):
        if t is not None:
            t["index"] = i

    print(json.dumps(tracks, ensure_ascii=False))


def _clean_metadata(meta: dict) -> dict:
    result = {}
    for key, value in meta.items():
        if isinstance(value, dbus.Array):
            cleaned = [str(v) for v in value]
            # artist and albumArtist are arrays in MPRIS
            if key == "xesam:artist":
                result["artist"] = cleaned[0] if cleaned else ""
            elif key == "xesam:albumArtist":
                result["albumArtist"] = cleaned[0] if cleaned else ""
            else:
                result[key] = cleaned[0] if len(cleaned) == 1 else cleaned
        elif isinstance(value, dbus.ObjectPath):
            result["trackId"] = str(value)
            result["mpris:trackid"] = str(value)
        elif isinstance(value, (dbus.Int64, dbus.UInt64, dbus.Int32, dbus.UInt32)):
            if key == "mpris:length":
                result["length"] = int(value)
            else:
                result[key] = int(value)
        elif isinstance(value, (dbus.Double, dbus.Boolean)):
            result[key] = value
        elif isinstance(value, dbus.String):
            if key == "xesam:title":
                result["title"] = str(value)
            elif key == "xesam:album":
                result["album"] = str(value)
            elif key == "mpris:artUrl":
                result["artUrl"] = str(value)
            else:
                result[key] = str(value)
        elif isinstance(value, str):
            if key == "xesam:title":
                result["title"] = value
            elif key == "xesam:album":
                result["album"] = value
            elif key == "mpris:artUrl":
                result["artUrl"] = value
            else:
                result[key] = value
        else:
            result[key] = str(value)

    if "mpris:trackid" in result:
        track_id = str(result["mpris:trackid"])
        parts = track_id.rstrip("/").split("/")
        result["index"] = int(parts[-1]) if parts[-1].isdigit() else -1

    return result


def cmd_goto(player: str, track_id: str):
    _, proxy = _connect(player)
    _go_to(proxy)(dbus.ObjectPath(track_id))


def cmd_canedit(player: str):
    _, proxy = _connect(player)
    value = _properties_get(proxy, TRACKLIST_IFACE, "CanEditTracks")
    print(json.dumps(bool(value)))


def cmd_busname(player: str):
    print(_player_bus_name(player))


def main():
    parser = argparse.ArgumentParser(description="MPRIS TrackList CLI")
    parser.add_argument("--player", default="SELFsonic", help="MPRIS player name")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("busname", help="Print resolved D-Bus name of the player")
    sub.add_parser("list", help="List all track IDs")
    meta_parser = sub.add_parser("metadata", help="Get track metadata")
    meta_parser.add_argument("ids", nargs="+", help="Track IDs (object paths)")
    goto_parser = sub.add_parser("goto", help="Go to a track")
    goto_parser.add_argument("id", help="Track ID (object path)")
    sub.add_parser("canedit", help="Check if tracks can be edited")

    args = parser.parse_args()

    try:
        if args.command == "list":
            cmd_list(args.player)
        elif args.command == "metadata":
            cmd_metadata(args.player, args.ids)
        elif args.command == "goto":
            cmd_goto(args.player, args.id)
        elif args.command == "busname":
            cmd_busname(args.player)
        elif args.command == "canedit":
            cmd_canedit(args.player)
    except dbus.exceptions.DBusException as e:
        # Плеєр не існує або не підтримує TrackList — мовчки виходимо
        sys.exit(1)


if __name__ == "__main__":
    main()
