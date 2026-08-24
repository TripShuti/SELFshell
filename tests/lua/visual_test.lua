-- ============================================================
-- tests/lua/visual_test.lua — unit-тест general.lua: дефолти без
-- visual.json, оверрайди перемагають, криві типи ігноруються,
-- колір бордера перемикає градієнт на суцільний.
-- Запуск: luajit visual_test.lua <repo-root>
-- Мокує глобальний hl; HOME — тимчасова тека (без env.json).
-- ============================================================

local root = arg[1] or "."
package.path = root .. "/hypr/?.lua;" .. package.path

local captured = nil
hl = {
  config = function(cfg) captured = cfg end,
  device = function() end,
}

local HOME = "/tmp/selfshell-visual-test-home"
os.execute("rm -rf '" .. HOME .. "'")
os.execute("mkdir -p '" .. HOME .. "/.config/hypr'")

local real_getenv = os.getenv
os.getenv = function(k)
  if k == "HOME" then return HOME end
  return real_getenv(k)
end

local function load_general()
  captured = nil
  package.loaded["modules.general"] = nil
  local ok, err = pcall(require, "modules.general")
  assert(ok, "general.lua failed: " .. tostring(err))
  return captured
end

-- --- Прохід 1: без visual.json — дефолти репо ---
local c = load_general()
assert(c.general.gaps_in == 3 and c.general.gaps_out == 1, "default gaps")
assert(c.general.border_size == 1, "default border size")
assert(c.general.layout == "dwindle", "default layout")
assert(c.general.resize_on_border == false, "default resize_on_border")
assert(type(c.general.col.active_border) == "table", "default active border = gradient")
assert(c.general.col.inactive_border == "rgba(111a1294)", "default inactive border")
assert(c.decoration.rounding == 0, "default rounding")
assert(c.decoration.dim_inactive == false, "default dim off")
assert(c.decoration.active_opacity == 1.0 and c.decoration.inactive_opacity == 1.0,
  "default opacities")
assert(c.decoration.shadow.enabled == true, "default shadows on (hyprland-like)")
assert(c.cursor.inactive_timeout == 3, "default cursor inactive_timeout")
assert(c.master.mfact == 0.55 and c.master.orientation == "left", "default master params")

-- --- Прохід 2: оверрайди перемагають ---
local f = assert(io.open(HOME .. "/.config/hypr/visual.json", "w"))
f:write([[{
  "gaps_in": 7,
  "gaps_out": "many",
  "border_size": 0,
  "layout": "master",
  "mfact": 0.6,
  "orientation": "top",
  "rounding": 16,
  "rounding_power": 4.5,
  "dim_inactive": true,
  "dim_strength": 0.5,
  "active_opacity": 0.92,
  "inactive_opacity": 0.85,
  "shadows": false,
  "active_border": "rgba(ffffffff)",
  "inactive_border": "rgba(000000ff)",
  "resize_on_border": true,
  "inactive_timeout": 0,
  "new_status": "slave",
  "always_keep_position": true
}]])
f:close()

c = load_general()
assert(c.general.gaps_in == 7, "override gaps_in")
assert(c.general.gaps_out == 1, "bad type (string) falls back to default")
assert(c.general.border_size == 0, "override border_size 0 is valid")
assert(c.general.layout == "master", "override layout")
assert(c.general.resize_on_border == true, "override resize_on_border")
assert(c.master.mfact == 0.6 and c.master.orientation == "top", "override master params")
assert(c.master.new_status == "slave", "override new_status (json-only key)")
assert(c.master.always_keep_position == true, "override always_keep_position")
assert(c.decoration.rounding == 16, "override rounding")
assert(c.decoration.rounding_power == 4.5, "override rounding_power")
assert(c.decoration.dim_inactive == true and c.decoration.dim_strength == 0.5, "override dim")
assert(c.decoration.active_opacity == 0.92, "override active opacity")
assert(c.decoration.inactive_opacity == 0.85, "override inactive opacity")
assert(c.decoration.shadow.enabled == false, "override shadows off")
assert(c.general.col.active_border == "rgba(ffffffff)", "solid active border replaces gradient")
assert(c.general.col.inactive_border == "rgba(000000ff)", "solid inactive border")
assert(c.cursor.inactive_timeout == 0, "override inactive_timeout 0 is valid")

-- --- Прохід 3: пошкоджений visual.json — дефолти, не краш ---
local f2 = assert(io.open(HOME .. "/.config/hypr/visual.json", "w"))
f2:write("{ not json")
f2:close()
c = load_general()
assert(c.general.gaps_in == 3 and c.general.layout == "dwindle", "broken json -> defaults")

os.execute("rm -rf '" .. HOME .. "'")
print("OK: visual.json defaults, overrides, bad types, broken json, border color switch")
