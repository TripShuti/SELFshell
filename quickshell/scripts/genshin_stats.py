# ============================================================
# genshin_stats.py — API Genshin Impact (смола, дейліки, чекін)
# ============================================================
# Отримує дані Genshin Impact з Hoyolab API
# Використання: python3 genshin_stats.py [sign]
#   - без аргументів: повертає JSON зі смолою, дейліками, експедиціями тощо
#   - sign: виконує щоденний чекін

import requests
import json
import time
import random
import hashlib
import os
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

# Змінні середовища: COOKIE, UID, SERVER, ACT_ID
COOKIE = os.getenv("GENSHIN_COOKIE")
UID = os.getenv("GENSHIN_UID")
SERVER = os.getenv("GENSHIN_SERVER", "os_euro")
ACT_ID = os.getenv("GENSHIN_ACT_ID", "e202102251931481")


# Генерує DS (динамічний підпис) для авторизації запитів
def generate_ds():
    salt = "6s2sh5u6baebhw6id6p087w26a6isv12"
    t = int(time.time())
    r = "".join(random.choices("abcdefghijklmnopqrstuvwxyz0123456789", k=6))
    h = hashlib.md5(f"salt={salt}&t={t}&r={r}".encode()).hexdigest()
    return f"{t},{r},{h}"


# Формує заголовки для запитів до API
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


# Перевіряє статус щоденного чекіну
def check_sign_status():
    url = f"https://sg-hk4e-api.hoyolab.com/event/sol/info?act_id={ACT_ID}"
    try:
        r = requests.get(url, headers=make_headers())
        data = r.json()
        if data["retcode"] != 0:
            return None, f"Код: {data['retcode']}\n{data['message']}"
        info = data["data"]
        return info.get("is_sign", False), info.get("total_sign_day", 0)
    except Exception as e:
        return None, str(e)


# Виконує чекін
def do_sign():
    url = f"https://sg-hk4e-api.hoyolab.com/event/sol/sign?act_id={ACT_ID}"
    try:
        r = requests.post(url, headers=make_headers(), json={})
        data = r.json()
        if data["retcode"] == 0:
            return True, "Чекін виконано!"
        elif data["retcode"] == -5003:
            return False, "Чекін вже зроблений сьогодні"
        else:
            return False, f"Код: {data['retcode']}\n{data['message']}"
    except Exception as e:
        return False, str(e)


# Отримує щоденну статистику (смола, дейліки, експедиції тощо)
def get_notes():
    url = f"https://bbs-api-os.hoyolab.com/game_record/genshin/api/dailyNote?server={SERVER}&role_id={UID}"

    try:
        response = requests.get(url, headers=make_headers(generate_ds()))
        data = response.json()

        if data["retcode"] != 0:
            if data["retcode"] == -502:
                return {"text": " Wait", "tooltip": "API Rate Limit. Почекайте 15 хв."}
            return {"text": " Error", "tooltip": f"Код: {data['retcode']}\n{data['message']}"}

        notes = data["data"]
        resin = notes.get("current_resin", 0)
        max_resin = notes.get("max_resin", 200)
        recovery_time = int(notes.get("resin_recovery_time", 0))

        if recovery_time > 0:
            hours, remainder = divmod(recovery_time, 3600)
            minutes, _ = divmod(remainder, 60)
            recovery_str = f"{hours}г {minutes}хв"
        else:
            recovery_str = "Повна"

        is_claimed = any([
            notes.get("is_extra_task_reward_received"),
            notes.get("is_extra_reward_received")
        ])

        daily_done = notes.get("finished_task_num", 0)

        if is_claimed:
            daily_status = "Катя 󰃯 "
        elif daily_done == 4:
            daily_status = "Катя 󰃰 "
        else:
            daily_status = "Катя  "

        is_signed, sign_days = check_sign_status()
        if is_signed is None:
            sign_str = "Помилка"
        elif is_signed:
            sign_str = f"✓ {sign_days}д"
        else:
            sign_str = "✗"

        tooltip = (
            f"Кап смоли через: {recovery_str}\n"
            f"Експедиції: {notes.get('current_expedition_num')}/{notes.get('max_expedition_num')}\n"
            f"Чайник: {notes.get('current_home_coin')}/{notes.get('max_home_coin')}\n"
            f"Дейліки: {daily_done}/4 ({daily_status})\n"
            f"Боси (знижка): {notes.get('remain_resin_discount_num')}/3\n"
            f"Чекін: {sign_str}"
        )

        return {
            "text": f" {resin}/{max_resin}",
            "tooltip": tooltip,
            "class": "critical" if resin >= 190 else "normal"
        }

    except Exception as e:
        return {"text": " !", "tooltip": f"Помилка: {str(e)}"}


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "sign":
        ok, msg = do_sign()
        print(json.dumps({"ok": ok, "msg": msg}))
    else:
        print(json.dumps(get_notes()))
