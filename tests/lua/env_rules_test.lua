-- ============================================================
-- tests/lua/env_rules_test.lua — smoke-тест env.json → env.lua
-- дефолти + data-driven rules.lua (windowRules).
-- Запуск: luajit env_rules_test.lua <repo-root> [env.json]
-- Мокує глобальний hl; дома користувача — тимчасова тека.
-- ============================================================

local root = arg[1] or "."
package.path = root .. "/hypr/?.lua;" .. package.path

local calls = {}
hl = {
  window_rule = function(r) calls[#calls + 1] = { kind = "rule", r = r } end,
  layer_rule = function(r) calls[#calls + 1] = { kind = "layer_rule", r = r } end,
  config = function() calls[#calls + 1] = { kind = "config" } end,
  on = function(e, fn) calls[#calls + 1] = { kind = "on", e = e, fn = fn } end,
  exec_cmd = function(c) calls[#calls + 1] = { kind = "exec", c = c } end,
  dsp = { exec_cmd = function(c) return c end },
}

local ENV_JSON = arg[2] or (root .. "/hypr/env.json")
local HOME = "/tmp/selfshell-env-test-home"
-- Порожня дома для кейсу «env.json відсутній» — інакше тест читав би
-- СВІЙ $HOME розробника (негерметично на машинах з власним hypr/env.json)
local NOHOME = "/tmp/selfshell-env-test-nohome"

local function setup_home()
  os.execute("rm -rf '" .. HOME .. "'")
  os.execute("mkdir -p '" .. HOME .. "/.config/hypr'")
  os.execute("cp '" .. ENV_JSON .. "' '" .. HOME .. "/.config/hypr/env.json'")
end

os.execute("rm -rf '" .. NOHOME .. "'")
os.execute("mkdir -p '" .. NOHOME .. "'")

-- LuaJIT: os.setenv недоступний — підставляємо os.getenv
local real_getenv = os.getenv
local home_override = nil
os.getenv = function(k)
  if k == "HOME" and home_override then return home_override end
  return real_getenv(k)
end

local function fresh_env(home)
  home_override = home
  package.loaded["modules.env"] = nil
  package.loaded["modules.json"] = nil
  local ok, mod = pcall(require, "modules.env")
  home_override = nil
  assert(ok, "env.lua failed: " .. tostring(mod))
  return mod
end

local function load_rules(home)
  calls = {}
  home_override = home
  package.loaded["modules.env"] = nil
  package.loaded["modules.json"] = nil
  package.loaded["modules.rules"] = nil
  local ok, err = pcall(require, "modules.rules")
  home_override = nil
  assert(ok, "rules.lua failed: " .. tostring(err))
end

-- 1) Немає env.json → дефолти env.lua
local e = fresh_env(NOHOME)
assert(e.kbLayout == "us", "kbLayout default")
assert(e.kbOptions == "", "kbOptions default")
assert(e.suspendKey == "", "suspendKey default")
assert(#e.windowRules == 0, "windowRules default empty")
assert(e.mainMod == "SUPER" and e.cursorSize == 24, "other defaults")

-- 2) Еталонний env.json (у репо) → нейтральні значення, без особистого мусору
setup_home()
local shipped = fresh_env(HOME)
assert(shipped.kbLayout == "us", "shipped kbLayout = '" .. tostring(shipped.kbLayout) .. "'")
assert(#shipped.devices == 0, "shipped devices must be empty")
assert(#shipped.windowRules == 0, "shipped windowRules must be empty")
assert(shipped.suspendKey == "", "shipped suspendKey must be empty")
assert(#shipped.autostart == 2, "shipped autostart (awww-daemon, hyprsunset)")

-- 3) rules.lua зі shipped env → тільки універсальні правила
load_rules(HOME)
assert(#calls >= 4, "universal rules registered (2 window_rule + 2 layer_rule)")

-- 4) windowRules з env → hl.window_rule отримує їх без змін
local custom = HOME .. "/.config/hypr/env.json"
local f = io.open(custom, "w")
f:write('{"windowRules": [{"name": "t", "match": {"class": "foo"}, "float": true}]}')
f:close()
load_rules(HOME)
local found = false
for _, c in ipairs(calls) do
  if c.kind == "rule" and c.r.name == "t" then
    assert(c.r.match.class == "foo" and c.r.float == true, "rule body passed through")
    found = true
  end
end
assert(found, "data-driven window rule applied")

-- 5) Неправильні типи в env.json → дефолти (конфіг не падає)
f = io.open(custom, "w")
f:write('{"mod": 42, "kbLayout": 7, "cursorSize": "big", "autostart": "kitty", "devices": {}, "windowRules": true}')
f:close()
e = fresh_env(HOME)
assert(e.mainMod == "SUPER", "wrong-typed mod -> default")
assert(e.kbLayout == "us", "wrong-typed kbLayout -> default")
assert(e.cursorSize == 24, "wrong-typed cursorSize -> default")
assert(#e.autostart == 0 and #e.devices == 0, "non-list arrays -> empty")
assert(#e.windowRules == 0, "non-list arrays -> empty")

os.execute("rm -rf '" .. HOME .. "'")
print("OK: env.lua defaults, shipped env.json, rules.lua data-driven")