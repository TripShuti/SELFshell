-- ============================================================
-- tests/lua/json_test.lua — unit-тести hypr/modules/json.lua:
-- парсинг JSON, escape-послідовності, помилкові вхідні дані.
-- Запуск: luajit json_test.lua <repo-root>
-- ============================================================

local root = arg[1] or "."
package.path = root .. "/hypr/?.lua;" .. package.path
local json = require("modules.json")

local failed = 0
local function eq(got, want, name)
  if got ~= want then
    print("FAIL " .. name .. ": got " .. tostring(got) .. ", want " .. tostring(want))
    failed = failed + 1
  end
end

local function is_nil(got, name)
  if got ~= nil then
    print("FAIL " .. name .. ": expected nil, got " .. tostring(got))
    failed = failed + 1
  end
end

local function is_table(got, name)
  if type(got) ~= "table" then
    print("FAIL " .. name .. ": expected table, got " .. type(got))
    failed = failed + 1
    return nil
  end
  return got
end

-- --- Основні типи ---
eq(json.parse("true"), true, "true")
eq(json.parse("false"), false, "false")
is_nil(json.parse("null"), "top-level null is invalid")
eq(json.parse("0"), 0, "zero")
eq(json.parse("-12.5"), -12.5, "negative float")
eq(json.parse("1e3"), 1000, "exponent")
eq(json.parse("2.5E-2"), 0.025, "negative exponent")
eq(json.parse("100"), 100, "integer")

-- --- Об'єкти і вкладеність ---
local obj = is_table(json.parse('{"a": 1, "b": "x", "c": [1, 2]}'), "object")
if obj then
  eq(obj.a, 1, "obj.a")
  eq(obj.b, "x", "obj.b")
  eq(obj.c[2], 2, "obj.c[2]")
end
local empty = is_table(json.parse("{}"), "empty object")
if empty then eq(#empty == 0 and true or false, true, "empty object no keys") end
local arr = is_table(json.parse('["a", null, {"k": true}]'), "array")
if arr then
  -- json.lua представляє null сентинелом-таблицею
  eq(type(arr[2]) == "table" and true or false, true, "null sentinel in array")
  eq(arr[3].k, true, "nested object bool")
end

-- --- Рядкові escape ---
eq(json.parse('"\\u0041"'), "A", "\\u0041")
eq(json.parse('"\\u0443"'), "у", "cyrillic \\u0443")
eq(json.parse('"a\\nb\\tc"'), "a\nb\tc", "\\n \\t escapes")
eq(json.parse('"\\\\ \\" \\/"'), "\\ \" /", "backslash/quote/slash escapes")
eq(json.parse('"\\r\\b\\f"'), "\r\b\f", "control escapes")

-- --- Пробільні символи ---
eq(json.parse("  [1]  ")[1], 1, "trailing whitespace accepted")
local ws = is_table(json.parse(" \n\t [ 1 , 2 ] \r\n "), "whitespace object")
if ws then eq(ws[2], 2, "ws[2]") end

-- --- Помилки → nil ---
is_nil(json.parse(""), "empty string")
is_nil(json.parse("{")) -- незакритий об'єкт
is_nil(json.parse("[1,"), "trailing comma")
is_nil(json.parse("[1, 2, 3] garbage"), "trailing garbage")
is_nil(json.parse('{"a":1'), "unclosed object")
is_nil(json.parse("{a: 1}"), "unquoted key")
is_nil(json.parse('"unclosed'), "unclosed string literal")
is_nil(json.parse("+1"), "leading plus number")
is_nil(json.parse("nul"), "typo null")
is_nil(json.parse(42), "non-string input")
is_nil(json.parse("['str']"), "single quotes")

-- --- json.read: файли ---
local tmp = root .. "/tests/lua/.json_test_tmp"
local f = io.open(tmp, "w")
f:write('{"ok": 1}')
f:close()
local rd = is_table(json.read(tmp), "read valid")
if rd then eq(rd.ok, 1, "file value") end
os.remove(tmp)
is_nil(json.read(root .. "/no/such/file.json"), "read missing file")

local bad = root .. "/tests/lua/.json_test_bad"
local g = io.open(bad, "w")
g:write("{broken,")
g:close()
is_nil(json.read(bad), "read broken file")
os.remove(bad)

if failed > 0 then
  print(failed .. " FAILED")
  os.exit(1)
end
print("OK: json.lua unit tests")