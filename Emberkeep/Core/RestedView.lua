-- RestedView: the Rested focus as rows and a summary. Pure Lua: it turns the
-- roster and Rest's projections into what the window, the minimap tooltip and
-- the login line show.
local _, ns = ...
ns = ns or {}
local RestedView = {}
ns.RestedView = RestedView

-- ctx: maxLevel, now, currentKey (the character you're on), hideSurnames
-- (first names only).
-- rows: rank, key, name, classFile, level, percentText ("12.5%"), percent (whole number, rounded
-- down until full so 150% always means full), fill (0 to 1 of the cap), full,
-- fullIn ("Full" or "1d 18h"), fullAt, wellRested (0 to 5, or nil when it was
-- never read), resting, zone.
-- summary: levelling (rows shown), atMax, full (how many are full), next (the
-- top row that isn't the character you're on and has rested XP, or nil).
function RestedView.Build(store, deps, ctx)
  local characters = deps.Roster.Characters(store)
  local rows, summary = {}, { levelling = 0, atMax = 0, full = 0 }
  for _, c in ipairs(characters) do
    if (c.level or 0) >= ctx.maxLevel then
      summary.atMax = summary.atMax + 1
    end
  end
  local ranked = deps.Rest.Ranking(characters, ctx.maxLevel, ctx.now)
  for i, entry in ipairs(ranked) do
    local c, p = entry.character, entry.projection
    local row = {
      rank = i,
      key = c.key,
      name = deps.Roster.DisplayName(c, ctx.hideSurnames),
      classFile = c.classFile,
      level = tostring(c.level or "?"),
      percentText = deps.Rest.PercentText(p),
      percent = p.full and math.floor(p.percent + 0.5) or math.floor(p.percent),
      fill = p.cap > 0 and p.rested / p.cap or 0,
      full = p.full,
      fullIn = p.full and "Full" or deps.Format.Duration(p.secondsToFull),
      fullAt = p.fullAt,
      wellRested = c.wellRested,
      resting = c.rest.resting,
      zone = c.zone or "",
    }
    rows[#rows + 1] = row
    if p.full then
      summary.full = summary.full + 1
    end
    if not summary.next and row.key ~= ctx.currentKey and row.percent >= 1 then
      summary.next = row
    end
  end
  summary.levelling = #rows
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
    return "No levelling alts seen yet"
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
  if not top then
    return nil
  end
  return string.format("play next %s (%d%% rested%s)", top.name, top.percent, top.full and ", full" or "")
end

return RestedView
