-- Played: each character's /played time. The game only says it when asked
-- (TIME_PLAYED_MSG), so this keeps the last answer and when it came, and
-- counts the time since for the character you're on. Pure Lua.
local _, ns = ...
ns = ns or {}
local Played = {}
ns.Played = Played

-- Saves the game's answer: total seconds played, as of `at`.
function Played.Observe(c, total, at)
  if type(total) ~= "number" or total < 0 or type(at) ~= "number" then
    return false
  end
  c.played = { total = total, at = at }
  return true
end

-- Seconds played as of `now`, or nil if never read. Only the character
-- you're logged in on (current) is still adding time.
function Played.Total(c, now, current)
  local p = c.played
  if not p then
    return nil
  end
  if current then
    return p.total + math.max(0, now - p.at)
  end
  return p.total
end

-- On logout, folds this session into the saved total, so it reads right
-- while you're on another alt.
function Played.Settle(c, now)
  local total = Played.Total(c, now, true)
  if total then
    c.played = { total = total, at = now }
  end
end

return Played
