-- ============================================================
-- modules/json.lua — мінімальний JSON-парсер (без залежностей).
-- Підтримує об'єкти, масиви, рядки (з \u-escape), числа,
-- true/false/null. Будь-яка помилка читання/парсингу → nil
-- (конфіг не падає, застосовуються дефолти).
-- ============================================================

local json = {}
local NULL = {} -- сентинел для JSON null (nil в Lua означає помилку парсингу)

local function skip_ws(s, i)
  local c
  while i <= #s do
    c = s:sub(i, i)
    if c == " " or c == "\t" or c == "\n" or c == "\r" then
      i = i + 1
    else
      return i
    end
  end
  return i
end

local function parse_string(s, i)
  local out = {}
  i = i + 1 -- відкриваюча лапка
  while i <= #s do
    local c = s:sub(i, i)
    if c == '"' then
      return table.concat(out), i + 1
    elseif c == "\\" then
      local n = s:sub(i + 1, i + 1)
      local esc = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f",
                    ["/"] = "/", ["\\"] = "\\", ['"'] = '"' }
      if esc[n] then
        out[#out + 1] = esc[n]
        i = i + 2
      elseif n == "u" then
        local cp = tonumber(s:sub(i + 2, i + 5), 16)
        if cp then
          if cp < 0x80 then
            out[#out + 1] = string.char(cp)
          elseif cp < 0x800 then
            out[#out + 1] = string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
          else
            out[#out + 1] = string.char(0xE0 + math.floor(cp / 4096),
                                        0x80 + math.floor(cp / 64) % 64,
                                        0x80 + cp % 64)
          end
          i = i + 6
        else
          i = i + 2 -- невалідний \u — пропускаємо як є
        end
      else
        out[#out + 1] = "\\" .. n
        i = i + 2
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return nil -- незакритий рядок
end

local parse_value

local function parse_array(s, i)
  local arr = {}
  i = skip_ws(s, i + 1)
  if s:sub(i, i) == "]" then return arr, i + 1 end
  while true do
    local v
    v, i = parse_value(s, i)
    if v == nil then return nil end
    arr[#arr + 1] = v
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == "," then
      i = skip_ws(s, i + 1)
    elseif c == "]" then
      return arr, i + 1
    else
      return nil
    end
  end
end

local function parse_object(s, i)
  local obj = {}
  i = skip_ws(s, i + 1)
  if s:sub(i, i) == "}" then return obj, i + 1 end
  while true do
    i = skip_ws(s, i)
    if s:sub(i, i) ~= '"' then return nil end
    local key
    key, i = parse_string(s, i)
    if not key then return nil end
    i = skip_ws(s, i)
    if s:sub(i, i) ~= ":" then return nil end
    local v
    v, i = parse_value(s, i + 1)
    if v == nil then return nil end
    obj[key] = v
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == "," then
      i = skip_ws(s, i + 1)
    elseif c == "}" then
      return obj, i + 1
    else
      return nil
    end
  end
end

parse_value = function(s, i)
  i = skip_ws(s, i)
  local c = s:sub(i, i)
  if c == "{" then return parse_object(s, i) end
  if c == "[" then return parse_array(s, i) end
  if c == '"' then return parse_string(s, i) end
  if s:sub(i, i + 3) == "true" then return true, i + 4 end
  if s:sub(i, i + 4) == "false" then return false, i + 5 end
  if s:sub(i, i + 3) == "null" then return NULL, i + 4 end
  local num = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
  if num and num ~= "" then
    local n = tonumber(num)
    if n then return n, i + #num end
  end
  return nil, nil -- неочікуваний символ
end

function json.parse(s)
  if type(s) ~= "string" then return nil end
  local v, i = parse_value(s, 1)
  if v == nil then return nil end
  if v == NULL then return nil end -- top-level null теж не значення
  i = skip_ws(s, i)
  if i <= #s then return nil end
  return v
end

-- Читає файл і парсить. Будь-яка помилка (файл відсутній, io
-- недоступний, невалідний JSON) → nil.
function json.read(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  local ok, v = pcall(json.parse, s)
  if not ok then return nil end
  return v
end

return json
