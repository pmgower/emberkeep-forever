-- RestedView: the Rested focus as rows and a summary. Pure Lua: it turns the
-- roster and Rest's projections into what the window, the minimap tooltip and
-- the login line show.
local _, ns = ...
ns = ns or {}
local RestedView = {}
ns.RestedView = RestedView

-- rows: rank, key, name, classFile, level, percent (whole number), fill (0 to
-- 1 of the cap), full, fullIn ("Full" or "1d 18h"), resting.
-- summary: levelling, atMax, full (how many are full), next (the top row that
-- isn't the character you're on, or nil).
function RestedView.Build(store, deps, maxLevel, now, currentKey)
  local characters = deps.Roster.Characters(store)
  local rows, summary = {}, { levelling = 0, atMax = 0, full = 0 }
  for _, c in ipairs(characters) do
    if (c.level or 0) >= maxLevel then
      summary.atMax = summary.atMax + 1
    else
      summary.levelling = summary.levelling + 1
    end
  end
  for i, ranked in ipairs(deps.Rest.Ranking(characters, maxLevel, now)) do
    local c, p = ranked.character, ranked.projection
    local row = {
      rank = i,
      key = c.key,
      name = c.name,
      classFile = c.classFile,
      level = tostring(c.level or "?"),
      percent = math.floor(p.percent + 0.5),
      fill = p.cap > 0 and p.rested / p.cap or 0,
      full = p.full,
      fullIn = p.full and "Full" or deps.Format.Duration(p.secondsToFull),
      fullAt = p.fullAt,
      resting = c.rest.resting,
    }
    rows[#rows + 1] = row
    if p.full then
      summary.full = summary.full + 1
    end
    if not summary.next and row.key ~= currentKey then
      summary.next = row
    end
  end
  return rows, summary
end

-- "3 levelling · 1 at max" for the window's title bar.
function RestedView.RightText(summary)
  local text = summary.levelling .. " levelling"
  if summary.atMax > 0 then
    text = text .. " · " .. summary.atMax .. " at max"
  end
  return text
end

-- "2 alts full, 3 still resting" for the minimap tooltip.
function RestedView.CountText(rows, summary)
  local filling = #rows - summary.full
  if #rows == 0 then
    return "No alts below max level yet"
  end
  local parts = {}
  if summary.full > 0 then
    parts[#parts + 1] = summary.full .. (summary.full == 1 and " alt full" or " alts full")
  end
  if filling > 0 then
    parts[#parts + 1] = filling .. " still resting"
  end
  return table.concat(parts, ", ")
end

-- The login line, or nil when nobody else has rested XP worth mentioning.
function RestedView.HintText(summary)
  local top = summary.next
  if not top or top.percent < 1 then
    return nil
  end
  return string.format("play next %s (%d%% rested%s)", top.name, top.percent, top.full and ", full" or "")
end

return RestedView
