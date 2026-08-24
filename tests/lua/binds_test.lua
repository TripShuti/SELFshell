-- ============================================================
-- tests/lua/binds_test.lua — unit-тест гарячих клавіш з binds.lua:
-- скріншоти (маркер для тоста), медіаклавіші, кліпборд, центр керування.
-- Запуск: luajit binds_test.lua <repo-root>
-- Мокує глобальний hl і env.lua (HOME — тимчасова тека без env.json).
-- ============================================================

local root = arg[1] or "."
package.path = root .. "/hypr/?.lua;" .. package.path

local binds = {}
local function act() return nil end
local dsp_window_hack = {
  close = function() return "close" end,
  float = function() return "float" end,
  move = function() return "move" end,
  drag = function() return "drag" end,
  resize = function() return "resize" end,
}
hl = {
  bind = function(key, action, opts)
    binds[#binds + 1] = { key = key, action = action, opts = opts }
  end,
  dsp = {
    exec_cmd = function(c) return c end,
    window = dsp_window_hack,
    focus = function() return "focus" end,
  },
}

-- Герметичний HOME: env.lua читає env.json звідти, як у env_rules_test
local HOME = "/tmp/selfshell-binds-test-home"
os.execute("rm -rf '" .. HOME .. "'")
os.execute("mkdir -p '" .. HOME .. "/.config/hypr'")

local real_getenv = os.getenv
local home_override = HOME
os.getenv = function(k)
  if k == "HOME" then return home_override end
  return real_getenv(k)
end

local function load_binds()
  binds = {}
  package.loaded["modules.binds"] = nil
  local ok, err = pcall(require, "modules.binds")
  assert(ok, "binds.lua failed: " .. tostring(err))
end

-- --- Прохід 1: без binds.json — дефолти ---
load_binds()

local function find(frag) -- шукає бінд за фрагментом клавіші
  for _, b in ipairs(binds) do
    if b.key:find(frag, 1, true) then return b end
  end
  return nil
end

assert(find("Print"), "Print bind registered (full screen)")
local p = find("SUPER + Print")
assert(p, "SUPER+Print bind registered (region)")

-- Скріншоти: маркер-файл тоста присутній в обох командах
for _, frag in ipairs({ "Print", "SUPER + Print" }) do
  local b = find(frag)
  assert(b.action:find("last-shot.txt", 1, true),
    frag .. ": marker file in command, got: " .. b.action)
  assert(b.action:find("grim", 1, true), frag .. ": grim in command")
end
-- Регіонний бінд має slurp; повноекранний — без
assert(p.action:find("slurp", 1, true), "SUPER+Print: slurp in region command")
assert(not find("Print").action:find("slurp", 1, true), "Print: no slurp in full command")
-- wl-copy в обох
for _, frag in ipairs({ "Print", "SUPER + Print" }) do
  assert(find(frag).action:find("wl%-copy", 1), frag .. ": wl-copy in command")
end

-- Медіаклавіші: гучність (wpctl + OSD) і яскравість (ddcutil + OSD)
local vol = {
  { "XF86AudioRaiseVolume", "wpctl set%-volume" },
  { "XF86AudioLowerVolume", "wpctl set%-volume" },
  { "XF86AudioMute", "wpctl set%-mute" },
}
for _, v in ipairs(vol) do
  local b = find(v[1])
  assert(b, v[1] .. " bind registered")
  assert(b.action:find(v[2], 1), v[1] .. ": command " .. v[2] .. ", got: " .. b.action)
  assert(b.action:find("osd volume", 1, true), v[1] .. ": OSD after change")
end

for _, k in ipairs({ "XF86MonBrightnessUp", "XF86MonBrightnessDown" }) do
  local b = find(k)
  assert(b, k .. " bind registered")
  assert(b.action:find("ddcutil", 1, true), k .. ": ddcutil, got: " .. b.action)
  assert(b.action:find("osd brightness", 1, true), k .. ": OSD after change")
end

-- Кліпборд і центр керування через IPC
local cb = find("SUPER + SHIFT + V")
assert(cb and cb.action == "qs ipc call clipboard toggle",
  "SUPER+SHIFT+V -> clipboard toggle, got: " .. (cb and cb.action or "nil"))
local cc = find("SUPER + Escape")
assert(cc and cc.action == "qs ipc call control toggle",
  "SUPER+Escape -> control toggle, got: " .. (cc and cc.action or "nil"))

-- --- Прохід 2: з binds.json — оверрайди перемагають, дефолти зникають ---
local f = assert(io.open(HOME .. "/.config/hypr/binds.json", "w"))
f:write([[{
  "launcher": "SUPER + T",
  "clipboard": "SUPER + ALT + H",
  "suspend": "XF86Launch1",
  "broken": 42,
  "empty": ""
}]])
f:close()
load_binds()

assert(find("SUPER + T") and find("SUPER + T").action == "qs ipc call launcher toggle",
  "override: SUPER+T -> launcher")
assert(not find("SUPER + R"), "override: old SUPER+R gone")
assert(find("SUPER + ALT + H") and find("SUPER + ALT + H").action == "qs ipc call clipboard toggle",
  "override: clipboard rebound")
assert(not find("SUPER + SHIFT + V"), "override: old clipboard combo gone")
assert(find("XF86Launch1") and find("XF86Launch1").action == "systemctl suspend",
  "override: suspend bound to XF86Launch1")
-- некоректні значення (число/порожній рядок) ігноруються — діє дефолт
assert(find("SUPER + L"), "invalid override values fall back to defaults")
-- решта дефолтів не постраждала
assert(find("SUPER + W") and find("SUPER + W").action == "chromium",
  "non-overridden default intact (browser)")

os.execute("rm -rf '" .. HOME .. "'")
print("OK: screenshot marker binds, media keys, clipboard, control center, binds.json overrides")