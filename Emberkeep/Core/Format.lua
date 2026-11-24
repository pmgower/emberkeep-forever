-- Format: turns raw numbers into the short text the windows show. Pure Lua.
local _, ns = ...
ns = ns or {}
local Format = {}
ns.Format = Format

-- Copper to gold, silver and copper parts: 1204 gold 37 silver 5 copper is
-- { gold = "1,204g", silver = "37s", copper = "5c" }; zero parts are "".
function Format.Money(copper)
  copper = math.max(0, math.floor(tonumber(copper) or 0))
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  local gold = ""
  if g > 0 then
    local digits = tostring(g):reverse():gsub("(%d%d%d)", "%1,"):reverse()
    gold = digits:gsub("^,", "") .. "g"
  end
  return {
    gold = gold,
    silver = s > 0 and (s .. "s") or "",
    copper = (g == 0 and c > 0) and (c .. "c") or "",
  }
end

-- How long ago a timestamp was, in the words the window uses.
function Format.Ago(then_, now)
  if not then_ then
    return "never"
  end
  local seconds = math.max(0, now - then_)
  if seconds < 3600 then
    return "just now"
  elseif seconds < 86400 then
    return math.floor(seconds / 3600) .. "h ago"
  end
  local days = math.floor(seconds / 86400)
  return days == 1 and "yesterday" or (days .. " days ago")
end

-- A time span in the two biggest units: "1d 18h", "5h 20m", "12m".
function Format.Duration(seconds)
  seconds = math.max(0, math.floor(seconds or 0))
  local d, h, m =
    math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600), math.floor(seconds % 3600 / 60)
  if d > 0 then
    return d .. "d " .. h .. "h"
  elseif h > 0 then
    return h .. "h " .. m .. "m"
  end
  return math.max(m, 1) .. "m"
end

return Format
