-- Rest: rested XP. Turns the last thing the game reported about a character
-- (a rest observation) into where their rested XP is now, and ranks who to
-- play next. Pure Lua.
--
-- Rates (WoW Forever): in an inn or city rested XP builds at 5% of a level per
-- 8 hours (measured about 4.9% on Forever), a quarter of that elsewhere (the
-- Classic rule, not yet measured on Forever), up to 150% of a level. Legacy's
-- Well Rested perk (0 to 5 ranks) adds 4% to the rate and 4% to the cap per
-- rank. Whether the cap becomes 150% x (1 + 0.04 per rank) or 150% plus 4
-- points per rank is not yet checked in game; this takes the first.
local _, ns = ...
ns = ns or {}
local Rest = {}
ns.Rest = Rest

Rest.CAP = 1.5
Rest.PER_SECOND = 0.05 / (8 * 3600) -- share of a level per second, resting
Rest.AWAY = 0.25
Rest.WELL_RESTED_STEP = 0.04

-- observation: { rested, xpMax, resting, wellRested, at }
-- Saves it on the character unless it's a bad read: XP to level reads 0
-- while logging out, and that must not replace a good observation.
function Rest.Observe(c, obs)
  if type(obs.xpMax) ~= "number" or obs.xpMax <= 0 or type(obs.at) ~= "number" then
    return false
  end
  local rank = obs.wellRested
  if type(rank) ~= "number" then
    rank = c.rest and c.rest.wellRested or 0 -- keep the last rank read
  end
  c.rest = {
    rested = math.max(0, tonumber(obs.rested) or 0),
    xpMax = obs.xpMax,
    resting = obs.resting and true or false,
    wellRested = rank,
    at = obs.at,
  }
  return true
end

-- Where a character's rested XP is at `now`: rested XP, cap, percent of a
-- level, whether it's full, when it filled (or will), seconds to full.
-- Well Rested is account-wide, so the account's rank (when known) wins over
-- the rank saved with an alt's older reading.
function Rest.Project(rest, now, accountRank)
  local rank = type(accountRank) == "number" and accountRank or rest.wellRested or 0
  local bonus = 1 + Rest.WELL_RESTED_STEP * rank
  local cap = rest.xpMax * Rest.CAP * bonus
  local rate = rest.xpMax * Rest.PER_SECOND * bonus * (rest.resting and 1 or Rest.AWAY)
  local start = math.min(rest.rested, cap)
  local fullAt = rest.at + (cap - start) / rate
  local elapsed = math.max(0, now - rest.at)
  local rested = math.min(cap, start + elapsed * rate)
  local full = rested >= cap
  return {
    rested = rested,
    cap = cap,
    percent = rested / rest.xpMax * 100,
    full = full,
    fullAt = fullAt,
    secondsToFull = full and 0 or (fullAt - now),
  }
end

-- Characters to show on the Rested focus: below max level, with a rest
-- observation. Full ones first, alphabetically (the game doesn't tell addons
-- the character select order); then the rest by how full, highest first.
function Rest.Ranking(characters, maxLevel, now, accountRank)
  local rows = {}
  for _, c in ipairs(characters) do
    if c.rest and (c.level or 0) < maxLevel then
      rows[#rows + 1] = { character = c, projection = Rest.Project(c.rest, now, accountRank) }
    end
  end
  table.sort(rows, function(a, b)
    local pa, pb = a.projection, b.projection
    if pa.full ~= pb.full then
      return pa.full
    end
    if not pa.full and pa.percent ~= pb.percent then
      return pa.percent > pb.percent
    end
    return tostring(a.character.name) < tostring(b.character.name)
  end)
  return rows
end

return Rest
