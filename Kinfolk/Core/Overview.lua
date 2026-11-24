-- Overview: the focus that lists every character with level, gold, zone and
-- when they were last played. Pure Lua: it turns the roster into rows.
local _, ns = ...
ns = ns or {}
local Overview = {}
ns.Overview = Overview

-- Returns rows (highest level first) and the summary for the header.
function Overview.Build(store, Roster, Format, now)
  local rows, total = {}, 0
  for _, c in ipairs(Roster.Characters(store)) do
    total = total + (c.money or 0)
    rows[#rows + 1] = {
      key = c.key,
      name = c.name,
      classFile = c.classFile,
      level = c.level and tostring(c.level) or "?",
      money = Format.Money(c.money),
      zone = c.zone or "",
      seen = Format.Ago(c.lastSeen, now),
    }
  end
  return rows, { count = #rows, money = Format.Money(total) }
end

return Overview
