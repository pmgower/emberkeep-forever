-- App: wires game events to the roster. Loads after Core and the adapters,
-- before the windows.
local addonName, ns = ...
local App = {}
ns.App = App

local listeners = {}

-- Windows call this to be told when the roster changes.
function App.OnChange(fn)
  listeners[#listeners + 1] = fn
end

function App.DB()
  return ns.db
end

-- When what the character is wearing is read. Not at logout: it reads empty.
local GEAR_EVENTS = { PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true, PLAYER_EQUIPMENT_CHANGED = true }

-- Just after login or an equip the game can know an item before its link, so
-- read again a few times until every link is in.
local RETRY_SECONDS, RETRIES = 2, 5

local function readGear(key, tries)
  local c = ns.db.characters[key]
  if not c then
    return
  end
  local _, missing = ns.Gear.Observe(c, ns.Items.Worn(), ns.Game.Now())
  if missing and tries > 0 and C_Timer and C_Timer.After then
    C_Timer.After(RETRY_SECONDS, function()
      readGear(key, tries - 1)
      ns.MainWindow.RefreshIfShown()
    end)
  end
end

local RANK_DELAY = 3

-- True between leaving the world and entering it again (zoning or logging
-- out), when readings can come back empty.
local leaving = true

local function readRank()
  local c = not leaving and ns.db.characters[ns.Game.CurrentKey() or ""]
  if c and ns.Rest.ObserveRank(c, ns.Game.WellRestedRank()) then
    ns.MainWindow.RefreshIfShown()
  end
end

local function readProfessions()
  local c = not leaving and ns.db.characters[ns.Game.CurrentKey() or ""]
  if c and ns.Professions.Observe(c, ns.Game.Professions(), ns.Game.Now()) then
    ns.MainWindow.RefreshIfShown()
  end
end

local function observe(event, arg1)
  if not ns.db then
    return
  end
  local sighting = ns.Game.Sighting()
  -- During PLAYER_LEVEL_UP the game can still report the old level; the new
  -- one is the event's first argument.
  if event == "PLAYER_LEVEL_UP" and type(arg1) == "number" then
    sighting.level = arg1
  end
  local key =
    ns.Roster.Observe(ns.db.characters, sighting, ns.Game.Now(), { loggingOut = event == "PLAYER_LOGOUT" })
  -- The Legacy trees may not be loaded on entering the world, and could read
  -- as 0, so give them a moment.
  if event == "PLAYER_ENTERING_WORLD" and C_Timer and C_Timer.After then
    C_Timer.After(RANK_DELAY, readRank)
    C_Timer.After(RANK_DELAY, readProfessions)
  elseif key and event == "TRAIT_CONFIG_UPDATED" then
    ns.Rest.ObserveRank(ns.db.characters[key], ns.Game.WellRestedRank())
  end
  -- Not on level-up (XP to level can still be the old level's) or logout
  -- (reads can come back empty); the readings just before are good.
  if key and event ~= "PLAYER_LEVEL_UP" and event ~= "PLAYER_LOGOUT" then
    ns.Rest.Observe(ns.db.characters[key], ns.Game.RestObservation())
  end
  if key and GEAR_EVENTS[event] then
    readGear(key, RETRIES)
  end
  if event == "TIME_PLAYED_MSG" then
    if key then
      ns.Played.Observe(ns.db.characters[key], arg1, ns.Game.Now())
    end
    -- Next frame: a chat window listening again mid-event could still
    -- print this answer.
    if C_Timer and C_Timer.After then
      C_Timer.After(0, ns.Game.PlayedAnswered)
    else
      ns.Game.PlayedAnswered()
    end
  elseif key and event == "PLAYER_LOGOUT" then
    ns.Played.Settle(ns.db.characters[key], ns.Game.Now())
  end
  for _, fn in ipairs(listeners) do
    fn()
  end
end

local function metadata(field)
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return get and get(addonName, field) or nil
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED") -- subzone changes, like walking into an inn
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("UPDATE_EXHAUSTION")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
frame:RegisterEvent("TIME_PLAYED_MSG")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
-- The last few errors Emberkeep hit this session, for /emberkeep feedback and
-- /emberkeep debug. Kept in memory only, never saved.
App.errors = {}

-- The game's error handler from before ours, so BugSack and the game's own
-- error popup still see every error first.
local previousHandler, ourHandler
-- True while we pass an event error on, so we don't note it a second time.
local forwarding = false

-- The first error each session offers a bug report (unless that option is
-- off); later ones are only remembered.
function App.NoteError(text)
  ns.Feedback.Remember(App.errors, text)
  if App.warned then
    return
  end
  App.warned = true
  local function offer()
    if ns.db and ns.db.settings.errorPrompt and ns.FeedbackWindow then
      ns.FeedbackWindow.ShowErrorPrompt(text)
    else
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cff9fd0ffEmberkeep:|r hit an error. Type /emberkeep feedback to report it."
      )
    end
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(0, offer) -- not from inside the error
  else
    offer()
  end
end

-- Notes an error that reached the game's handler, if it came from our folder.
local function noteIfOurs(msg, stack)
  if forwarding then
    return
  end
  pcall(function()
    if ns.Feedback.IsOurs(msg, stack) then
      App.NoteError(ns.Feedback.ShortError(msg, stack))
    end
  end)
end

-- Errors from our windows and buttons (outside the event handler below) reach
-- the game's error handler. BugGrabber (BugSack) owns that handler and blocks
-- seterrorhandler, but tells listeners about each error it grabs; without it
-- we chain onto the handler ourselves.
if BugGrabber and BugGrabber.RegisterCallback then
  BugGrabber.RegisterCallback(App, "BugGrabber_BugGrabbed", function(_, err)
    if type(err) == "table" then
      noteIfOurs(err.message, err.stack)
    end
  end)
elseif geterrorhandler and seterrorhandler then
  previousHandler = geterrorhandler()
  ourHandler = function(msg, ...)
    -- Level 2 starts below this handler, so its own line (in our folder)
    -- doesn't make every error look like ours.
    noteIfOurs(msg, debugstack and debugstack(2, 20, 0) or nil)
    if previousHandler then
      return previousHandler(msg, ...)
    end
  end
  seterrorhandler(ourHandler)
end

-- Bags change often, so they're read on their own, without the rest of the
-- sighting. Not between leaving the world and entering it again (zoning or
-- logging out), when they can read as empty.
-- Several changes close together (looting, a shot that uses ammo) make one read.
local queued = false
local BAG_DELAY, ENTER_DELAY = 0.5, 1
local queueBags

local function readBags(tries)
  local key = ns.db and not leaving and ns.Game.CurrentKey()
  local c = key and ns.db.characters[key]
  if not c then
    return
  end
  local reading = ns.Items.Carried()
  if ns.Bags.Observe(c, reading, ns.Game.Now()) then
    ns.AltPanel.RefreshIfShowing(key)
  end
  if reading and reading.missing and tries > 0 then
    queueBags(RETRY_SECONDS, tries - 1)
  end
end

function queueBags(delay, tries)
  if queued then
    return
  end
  if not (C_Timer and C_Timer.After) then
    return readBags(0)
  end
  queued = true
  C_Timer.After(delay, function()
    queued = false
    readBags(tries)
  end)
end

local function handle(event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == addonName then
      EmberkeepDB = ns.Store.Ensure(EmberkeepDB)
      ns.db = EmberkeepDB
      local themeKeys = {}
      for _, t in ipairs(ns.Window.THEMES) do
        themeKeys[t.key] = true
      end
      ns.Settings.Apply(ns.db.settings, themeKeys)
      ns.versionText = ns.Version.Short(metadata("Version"))
      ns.MinimapButton.Init(ns.db)
      ns.OptionsPage.Init()
    end
    if ns.db then
      ns.CharacterButton.Init()
    end
    return
  end
  if event == "BAG_UPDATE_DELAYED" then
    return queueBags(BAG_DELAY, RETRIES)
  elseif event == "SKILL_LINES_CHANGED" then
    if ns.db then
      readProfessions()
    end
    return
  elseif event == "PLAYER_LEAVING_WORLD" then
    leaving = true
    return
  elseif event == "PLAYER_ENTERING_WORLD" then
    leaving = false
  end
  observe(event, arg1)
  if event == "PLAYER_ENTERING_WORLD" then
    queueBags(ENTER_DELAY, RETRIES) -- whatever changed behind the loading screen
  end
  -- Ask for /played once per session (login or /reload), a moment after
  -- loading so it doesn't land among every other addon's login work.
  if event == "PLAYER_ENTERING_WORLD" and not App.playedAsked then
    App.playedAsked = true
    if C_Timer and C_Timer.After then
      C_Timer.After(3, ns.Game.RequestPlayed)
    else
      ns.Game.RequestPlayed()
    end
  end
  -- arg1 is isInitialLogin: true on login, false on /reload and zoning.
  if event == "PLAYER_ENTERING_WORLD" and arg1 == true then
    App.LoginHint()
  end
end

frame:SetScript("OnEvent", function(_, event, arg1)
  local ok, err = pcall(handle, event, arg1)
  if not ok then
    App.NoteError(ns.Feedback.ShortError(event .. ": " .. tostring(err)))
    -- Hand it on, so BugSack and the game's own error popup still see it.
    local report = geterrorhandler and geterrorhandler()
    if report then
      forwarding = true
      pcall(report, err)
      forwarding = false
    end
  end
end)

-- The chat line on login: who to play next, if anyone is full or filling.
function App.LoginHint()
  if not (ns.db and ns.db.settings.loginHint) then
    return
  end
  local _, summary = ns.RestedView.Build(ns.db.characters, ns, ns.Game.RestContext(ns.db))
  local line = ns.RestedView.HintText(summary)
  if line then
    ns.Say(line)
  end
end

-- fn's result, or fallback if it errors: the report has to open even when
-- the thing being reported is what's broken.
local function try(fallback, fn, ...)
  local ok, a, b = pcall(fn, ...)
  if ok then
    return a, b
  end
  return fallback
end

-- Everything /emberkeep feedback reports, read from the game. No names.
function App.FeedbackContext()
  local db = ns.db or { characters = {}, settings = {} }
  local client = {}
  if GetBuildInfo then
    client.version, client.build, client.date, client.interface = GetBuildInfo()
  end
  client.locale = GetLocale and GetLocale() or nil
  local race, class, faction
  if UnitRace then
    race = select(2, UnitRace("player"))
  end
  if UnitClass then
    class = select(2, UnitClass("player"))
  end
  if UnitFactionGroup then
    faction = UnitFactionGroup("player")
  end
  local s = try({}, ns.Game.Sighting)
  local current = db.characters[try(nil, ns.Game.CurrentKey) or ""]
  local rest = try(nil, ns.Game.RestObservation)
  local rows, summary = try({}, function()
    return ns.RestedView.Build(db.characters, ns, ns.Game.RestContext(db))
  end)
  summary = summary or {}
  local alts = {}
  for i, r in ipairs(rows) do
    alts[i] =
      { level = r.level, class = r.classFile, percent = r.percent, full = r.full, resting = r.resting }
  end
  local saved = 0
  for _ in pairs(db.characters) do
    saved = saved + 1
  end
  return {
    version = metadata("Version"),
    client = client,
    character = {
      level = s.level,
      race = race,
      class = class,
      faction = faction,
      realm = s.realm,
      maxLevel = try(nil, ns.Game.MaxLevel),
    },
    rest = rest,
    wellRested = current and current.wellRested,
    settings = db.settings,
    saved = saved,
    atMax = summary.atMax,
    alts = alts,
    addons = {
      BugSack = BugSack ~= nil,
      LibDBIcon = LibStub ~= nil and LibStub("LibDBIcon-1.0", true) ~= nil,
    },
    errors = App.errors,
  }
end

-- Opens the feedback window. Shared by /emberkeep feedback, the options page,
-- the minimap button and the error prompt.
function App.OpenFeedback()
  local report = ns.Feedback.Report(App.FeedbackContext())
  local url, prefilled = ns.Feedback.IssueUrl(report)
  ns.FeedbackWindow.Show(url, report, prefilled)
end
