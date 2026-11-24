-- Feedback: the bug report. Pure Lua: App gathers the facts from the game, this
-- file turns them into the text /kinfolk feedback shows and the GitHub link
-- that carries it. Nothing leaves the player's computer: addons can't reach
-- the network, so the player copies the link into their browser.
--
-- Character names are left out on purpose: issues are public, and names don't
-- help debug anything. Alts are listed by level and class only.
local _, ns = ...
ns = ns or {}
local Feedback = {}
ns.Feedback = Feedback

Feedback.BUG_FORM_URL = "https://github.com/pmgower/kinfolk-forever/issues/new?template=bug_report.yml"
Feedback.FORM_FIELD = "feedback" -- id of the report box in .github/ISSUE_TEMPLATE/bug_report.yml
Feedback.MAX_URL = 7000 -- GitHub refuses much longer links; past this, the player pastes the report
Feedback.MAX_ERRORS = 5
Feedback.MAX_ERROR_LEN = 600 -- one error plus a short stack, so the link stays short
Feedback.MAX_ALTS = 20

local OURS = "AddOns[/\\]Kinfolk[/\\]"

-- Is this Lua error from Kinfolk? Looks for our folder in the message or the
-- stack, so other addons' errors are left alone.
function Feedback.IsOurs(msg, stack)
  local hay = tostring(msg or "") .. "\n" .. tostring(stack or "")
  return hay:find(OURS) ~= nil
end

-- The message plus the first few stack lines in our code, cut to MAX_ERROR_LEN.
function Feedback.ShortError(msg, stack)
  local out, n = { tostring(msg or "?") }, 0
  for line in tostring(stack or ""):gmatch("[^\n]+") do
    if n >= 4 then
      break
    end
    if line:find(OURS) then
      out[#out + 1] = "  " .. line
      n = n + 1
    end
  end
  local s = table.concat(out, "\n")
  if #s > Feedback.MAX_ERROR_LEN then
    s = s:sub(1, Feedback.MAX_ERROR_LEN) .. "..."
  end
  return s
end

-- Keeps the last MAX_ERRORS, oldest dropped first.
function Feedback.Remember(errors, text)
  errors[#errors + 1] = text
  while #errors > Feedback.MAX_ERRORS do
    table.remove(errors, 1)
  end
  return errors
end

-- Percent-encodes everything but unreserved URL characters (RFC 3986).
function Feedback.UrlEncode(text)
  return (tostring(text):gsub("[^%w%-%._~]", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

-- A link that opens the Bug report form with the report already in its
-- report box (GitHub issue forms prefill a field from a query parameter named
-- after its id). The same text goes in `body` too, which GitHub uses when the
-- form isn't there. Too long for both: the form field only. Too long for
-- that: the plain form link, and false so the window asks for a paste.
-- Returns url, prefilled.
function Feedback.IssueUrl(report)
  local field = Feedback.BUG_FORM_URL .. "&" .. Feedback.FORM_FIELD .. "=" .. Feedback.UrlEncode(report)
  local both = field .. "&body=" .. Feedback.UrlEncode("```\n" .. tostring(report) .. "\n```")
  if #both <= Feedback.MAX_URL then
    return both, true
  end
  if #field <= Feedback.MAX_URL then
    return field, true
  end
  return Feedback.BUG_FORM_URL, false
end

local function onOff(v)
  if v == true then
    return "on"
  elseif v == false then
    return "off"
  end
  return tostring(v)
end

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t or {}) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)
  return keys
end

local function orNone(list)
  return #list > 0 and table.concat(list, ", ") or "none"
end

-- "hideSurnames=off loginHint=on ..." without tables (saved window spots),
-- which would print as memory addresses.
local function settingsLine(settings)
  local parts = {}
  for _, k in ipairs(sortedKeys(settings)) do
    if type(settings[k]) ~= "table" then
      parts[#parts + 1] = k .. "=" .. onOff(settings[k])
    end
  end
  return table.concat(parts, " ")
end

local function q(v)
  return tostring(v == nil and "?" or v)
end

-- ctx = {
--   version,
--   client = { version, build, date, interface, locale },
--   character = { level, race, class, faction, realm, maxLevel },
--   rest = { rested, xpMax, resting },     -- this character's reading, or nil
--   wellRested,                            -- account Well Rested rank, or nil
--   settings = {...},
--   saved, atMax,                          -- how many alts are saved / at max level
--   alts = { { level, class, percent, full, resting }, ... }, -- Rested tab order
--   addons = { BugSack = bool, ... },
--   errors = { "message", ... },
-- }
-- Returns the report as one string, one fact per line.
function Feedback.Report(ctx)
  local out = {}
  local function add(fmt, ...)
    out[#out + 1] = string.format(fmt, ...)
  end
  local c, ch = ctx.client or {}, ctx.character or {}

  add("Kinfolk feedback report")
  add("Addon: %s", q(ctx.version))
  add(
    "Client: %s build %s (%s), interface %s, locale %s",
    q(c.version),
    q(c.build),
    q(c.date),
    q(c.interface),
    q(c.locale)
  )
  add(
    "Character: level %s %s %s, %s, realm %s, max level %s",
    q(ch.level),
    q(ch.race),
    q(ch.class),
    q(ch.faction),
    q(ch.realm),
    q(ch.maxLevel)
  )
  local r = ctx.rest
  if r then
    add("Rested: %s of %s XP, %s", q(r.rested), q(r.xpMax), r.resting and "resting" or "not resting")
  else
    add("Rested: no reading")
  end
  add("Well Rested: %s / 5", q(ctx.wellRested))
  add("Settings: %s", settingsLine(ctx.settings))

  local alts = ctx.alts or {}
  add("Alts saved: %s (%d levelling, %s at max)", q(ctx.saved), #alts, q(ctx.atMax))
  for i, a in ipairs(alts) do
    if i > Feedback.MAX_ALTS then
      add("  ...and %d more", #alts - Feedback.MAX_ALTS)
      break
    end
    add(
      "  %d: level %s %s, %s%%%s, %s",
      i,
      q(a.level),
      q(a.class),
      q(a.percent),
      a.full and " (full)" or "",
      a.resting and "inn" or "outside"
    )
  end

  local addons = {}
  for _, name in ipairs(sortedKeys(ctx.addons)) do
    addons[#addons + 1] = name .. " " .. (ctx.addons[name] and "loaded" or "not loaded")
  end
  add("Other addons: %s", orNone(addons))

  local errs = ctx.errors or {}
  add("Errors this session: %s", #errs == 0 and "none" or tostring(#errs))
  for _, e in ipairs(errs) do
    add("  %s", tostring(e))
  end
  return table.concat(out, "\n")
end

return Feedback
