# ============================================================
# genshin_stats.py — API-клієнт HoYoLAB для Genshin Impact:
# смола, чекін, дейліки. Викликається з GenshinMonitor.qml
# ============================================================
import requests
import json
import time
import random
import hashlib
import os
import datetime
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

COOKIE = os.getenv("GENSHIN_COOKIE")
UID = os.getenv("GENSHIN_UID")
SERVER = os.getenv("GENSHIN_SERVER", "os_euro")
ACT_ID = os.getenv("GENSHIN_ACT_ID", "e202102251931481")

STATE_FILE = os.path.join(os.path.dirname(__file__), ".genshin_state.json")
REQUEST_LOG_FILE = os.path.join(os.path.dirname(__file__), ".genshin_requests.log")
REQUEST_LOG_MAX_SIZE = 1024 * 1024
RESIN_REGEN_SECONDS = 480


def log_request(kind):
    """Пише один рядок у лог-файл щоразу, коли йде РЕАЛЬНИЙ HTTP-запит до Hoyolab."""
    try:
        # Проста ротація: файл старше 1MB перейменовується в .old
        if os.path.exists(REQUEST_LOG_FILE) and os.path.getsize(REQUEST_LOG_FILE) > REQUEST_LOG_MAX_SIZE:
            os.replace(REQUEST_LOG_FILE, REQUEST_LOG_FILE + ".old")
        with open(REQUEST_LOG_FILE, "a") as f:
            f.write(f"{datetime.datetime.now().isoformat(timespec='seconds')}  {kind}\n")
    except OSError:
        pass


def load_state():
    if not os.path.exists(STATE_FILE):
        return {}
    try:
        with open(STATE_FILE, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return {}


def save_state(state):
    try:
        with open(STATE_FILE, "w") as f:
            json.dump(state, f)
    except OSError:
        pass


def today_str():
    return datetime.date.today().isoformat()


def generate_ds():
    salt = "6s2sh5u6baebhw6id6p087w26a6isv12"
    t = int(time.time())
    r = "".join(random.choices("abcdefghijklmnopqrstuvwxyz0123456789", k=6))
    h = hashlib.md5(f"salt={salt}&t={t}&r={r}".encode()).hexdigest()
    return f"{t},{r},{h}"


def make_headers(ds=None):
    headers = {
        "Cookie": COOKIE,
        "Accept": "application/json, text/plain, */*",
        "x-rpc-app_version": "1.5.0",
        "x-rpc-client_type": "5",
        "x-rpc-language": "en-us",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36",
        "Referer": "https://act.hoyolab.com/",
        "Origin": "https://act.hoyolab.com"
    }
    if ds:
        headers["DS"] = ds
    return headers


# ---------------- Чекін ----------------

def _real_check_sign_status():
    log_request("check_sign_status (GET /event/sol/info)")
    url = f"https://sg-hk4e-api.hoyolab.com/event/sol/info?act_id={ACT_ID}"
    try:
        r = requests.get(url, headers=make_headers())
        data = r.json()
        if data["retcode"] != 0:
            return None, f"Code: {data['retcode']}\n{data['message']}"
        info = data["data"]
        return info.get("is_sign", False), info.get("total_sign_day", 0)
    except Exception as e:
        return None, str(e)


def check_sign_status(state, force=False):
    cached = state.get("sign")
    if not force and cached and cached.get("date") == today_str():
        return cached.get("is_signed"), cached.get("total_sign_day")

    is_signed, result = _real_check_sign_status()
    if is_signed is None:
        if cached:
            return cached.get("is_signed"), cached.get("total_sign_day")
        return None, result

    total_sign_day = result
    state["sign"] = {
        "date": today_str(),
        "is_signed": is_signed,
        "total_sign_day": total_sign_day,
    }
    save_state(state)
    return is_signed, total_sign_day


def do_sign(force=False):
    state = load_state()
    cached = state.get("sign")

    if not force and cached and cached.get("date") == today_str() and cached.get("is_signed"):
        return True, "Check-in already done today (cache, no API call)"

    log_request("do_sign (POST /event/sol/sign)")
    url = f"https://sg-hk4e-api.hoyolab.com/event/sol/sign?act_id={ACT_ID}"
    try:
        r = requests.post(url, headers=make_headers(), json={})
        data = r.json()
        if data["retcode"] == 0:
            state["sign"] = {
                "date": today_str(),
                "is_signed": True,
                "total_sign_day": cached.get("total_sign_day", 0) + 1 if cached else 1,
            }
            save_state(state)
            return True, "Check-in done!"
        elif data["retcode"] == -5003:
            state["sign"] = {
                "date": today_str(),
                "is_signed": True,
                "total_sign_day": cached.get("total_sign_day", 0) if cached else 0,
            }
            save_state(state)
            # Чекін фактично зроблено — повертаємо успіх, щоб UI не показував ✗
            return True, "Already checked in today"
        else:
            return False, f"Code: {data['retcode']}\n{data['message']}"
    except Exception as e:
        return False, str(e)


# ---------------- Локальний обрахунок смоли ----------------

def estimate_local(state):
    now = time.time()
    resin = state.get("resin", 0)
    max_resin = state.get("max_resin", 200)
    full_at = state.get("full_at", 0)
    synced_at = state.get("synced_at", now)

    if now >= full_at:
        resin = max_resin
        recovery_str = "Full"
    else:
        # Кламп від'ємного elapsed (зсув годинника) — інакше смола "віднімається"
        elapsed = max(0.0, now - synced_at)
        resin = min(max_resin, resin + int(elapsed // RESIN_REGEN_SECONDS))
        remaining = int(full_at - now)
        hours, rem = divmod(remaining, 3600)
        minutes, _ = divmod(rem, 60)
        recovery_str = f"{hours}h {minutes}m"

    return resin, recovery_str


def build_tooltip(resin, max_resin, recovery_str, notes, sign_str, cache_note=""):
    daily_done = notes.get("finished_task_num", 0)
    is_claimed = any([
        notes.get("is_extra_task_reward_received"),
        notes.get("is_extra_reward_received")
    ])
    if is_claimed:
        daily_status = "Kath 󰃯 "
    elif daily_done == 4:
        daily_status = "Kath 󰃰 "
    else:
        daily_status = "Kath 󰨱 "

    return (
        f"Resin cap in: {recovery_str}\n"
        f"Expeditions: {notes.get('current_expedition_num')}/{notes.get('max_expedition_num')}\n"
        f"Teapot: {notes.get('current_home_coin')}/{notes.get('max_home_coin')}\n"
        f"Dailies: {daily_done}/4 ({daily_status})\n"
        f"Bosses (discount): {notes.get('remain_resin_discount_num')}/3\n"
        f"Check-in: {sign_str}"
        f"{cache_note}"
    )


def get_local_display(state):
    if not state or "resin" not in state:
        return {"text": " ...", "tooltip": "First sync...", "class": "normal"}

    resin, recovery_str = estimate_local(state)
    max_resin = state.get("max_resin", 200)

    sign_cache = state.get("sign", {})
    if sign_cache.get("date") == today_str():
        is_signed = sign_cache.get("is_signed", False)
        total_days = sign_cache.get("total_sign_day", 0)
        sign_str = f"✓ {total_days}d" if is_signed else "✗"
    else:
        sign_str = "?"

    tooltip = build_tooltip(resin, max_resin, recovery_str, state.get("notes_cache", {}), sign_str)
    return {
        "text": f" {resin}/{max_resin}",
        "tooltip": tooltip,
        "class": "critical" if resin >= 190 else "normal",
    }


# ---------------- Синк з API ----------------

def _real_get_notes():
    log_request("get_notes (GET /dailyNote)")
    url = f"https://bbs-api-os.hoyolab.com/game_record/genshin/api/dailyNote?server={SERVER}&role_id={UID}"
    try:
        response = requests.get(url, headers=make_headers(generate_ds()))
        data = response.json()

        if data["retcode"] != 0:
            if data["retcode"] == -502:
                return None, {"text": " Wait", "tooltip": "API Rate Limit. Wait 15 min."}
            return None, {"text": " Error", "tooltip": f"Code: {data['retcode']}\n{data['message']}"}

        return data["data"], None
    except Exception as e:
        return None, {"text": " !", "tooltip": f"Error: {str(e)}"}


def _cached_response(state, cache_note=""):
    """Формує відповідь із локального кешу без жодного реального запиту до API."""
    if not state or "resin" not in state:
        return {"text": " Error", "tooltip": "No cached data",
                "class": "error", "resin": 0, "maxResin": 200, "ok": False}

    resin, recovery_str = estimate_local(state)
    max_resin = state.get("max_resin", 200)
    sign_cache = state.get("sign", {})
    if sign_cache.get("date") == today_str():
        is_signed = sign_cache.get("is_signed", False)
        total_days = sign_cache.get("total_sign_day", 0)
        sign_str = f"✓ {total_days}d" if is_signed else "✗"
    else:
        sign_str = "?"
    tooltip = build_tooltip(
        resin, max_resin, recovery_str, state.get("notes_cache", {}), sign_str,
        cache_note=cache_note
    )
    return {"text": f" {resin}/{max_resin}", "tooltip": tooltip,
            "class": "critical" if resin >= 190 else "normal",
            "resin": resin, "maxResin": max_resin}


# Мінімальний інтервал між реальними запитами дайлі-ноут (сек).
# Захист незалежний від того, хто викликає sync (QML-таймер, ручний рефреш, крон тощо).
SYNC_MIN_INTERVAL = 45

# Пауза після відповіді -502 (rate limit) перед наступною спробою реального запиту.
RATE_LIMIT_BACKOFF = 900  # 15 хв


def do_sync(min_interval=SYNC_MIN_INTERVAL):
    state = load_state()
    now = time.time()

    # Якщо недавно отримали rate limit — не смикаємо API, віддаємо кеш
    backoff_until = state.get("backoff_until")
    if backoff_until and now < backoff_until:
        remaining = int(backoff_until - now)
        return _cached_response(state, cache_note=f"\nRate limit backoff, {remaining}s remaining")

    # Троттлінг: не робимо реальний запит частіше, ніж раз на min_interval секунд,
    # незалежно від того, хто саме викликав sync
    if state.get("synced_at") and "resin" in state and (now - state["synced_at"]) < min_interval:
        return _cached_response(state)

    notes, error = _real_get_notes()

    if error:
        if error.get("text") == " Wait":
            state["backoff_until"] = now + RATE_LIMIT_BACKOFF
            save_state(state)
        if state and "resin" in state:
            return _cached_response(state, cache_note="\nRequest failed, data from cache")
        return {"text": " Error", "tooltip": error.get("tooltip", str(error)),
                "class": "error", "resin": 0, "maxResin": 200, "ok": False}

    # Успішний запит — знімаємо backoff, якщо він був
    state.pop("backoff_until", None)

    resin = notes.get("current_resin", 0)
    max_resin = notes.get("max_resin", 200)
    recovery_time = int(notes.get("resin_recovery_time", 0))

    state["resin"] = resin
    state["max_resin"] = max_resin
    state["synced_at"] = time.time()
    state["full_at"] = time.time() + recovery_time if resin < max_resin else time.time()
    state["notes_cache"] = notes
    save_state(state)

    resin_display, recovery_str = estimate_local(state)

    is_signed, sign_days = check_sign_status(state)
    sign_str = f"✓ {sign_days}d" if is_signed else ("✗" if is_signed is False else "Error")

    tooltip = build_tooltip(resin_display, max_resin, recovery_str, notes, sign_str)
    return {
        "text": f" {resin_display}/{max_resin}",
        "tooltip": tooltip,
        "class": "critical" if resin_display >= 190 else "normal",
        "resin": resin_display,
        "maxResin": max_resin,
    }


if __name__ == "__main__":
    import sys
    args = sys.argv[1:]

    if args and args[0] == "sign":
        force = "--force" in args
        ok, msg = do_sign(force=force)
        print(json.dumps({"ok": ok, "msg": msg}))
    elif args and args[0] == "sync":
        print(json.dumps(do_sync()))
    else:
        print(json.dumps(get_local_display(load_state())))