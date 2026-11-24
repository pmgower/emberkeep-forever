-- Overview: the focus that lists every character with level, gold, zone and
-- when they were last played. Pure Lua: it turns the roster into rows.
local _, ns = ...
ns = ns or {}
local Overview = {}
ns.Overview = Overview

-- Returns rows (highest level first) and the summary for the header.
-- opts.hideSurnames shows first names only; opts.currentKey is the character
-- you're on, whose played time is still counting. Played is "" until the game
-- has told us, and the summary's total counts only the alts it has.
function Overview.Build(store, Roster, Format, now, opts, Played)
  local rows, total, playedTotal = {}, 0, 0
  for _, c in ipairs(Roster.Characters(store)) do
    total = total + (c.money or 0)
    local played = Played and Played.Total(c, now, opts and c.key == opts.currentKey)
    playedTotal = playedTotal + (played or 0)
    rows[#rows + 1] = {
      key = c.key,
      name = Roster.DisplayName(c, opts and opts.hideSurnames),
      classFile = c.classFile,
      level = c.level and tostring(c.level) or "?",
      money = Format.Money(c.money),
      zone = c.zone or "",
      seen = Format.Ago(c.lastSeen, now),
      played = played and Format.Duration(played) or "",
    }
  end
  return rows,
    {
      count = #rows,
      money = Format.Money(total),
      played = playedTotal > 0 and Format.Duration(playedTotal) or "",
    }
end

return Overview
