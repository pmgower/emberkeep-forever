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

-- The skill list can be incomplete just after entering the world, so it's
-- read once the game has settled, and skill changes before then wait for it.
-- Several changes close together make one read.
local SKILL_DELAY = 1
local settled, skillsQueued = false, false

local function readProfessions()
  local c = not leaving and ns.db.characters[ns.Game.CurrentKey() or ""]
  if c and ns.Professions.Observe(c, ns.Game.Professions(), ns.Game.Now(), settled) then
    ns.MainWindow.RefreshIfShown()
  end
end

local function settle()
  if not leaving then
    settled = true
    readProfessions()
  end
end

local function skillsChanged()
  if not (settled and C_Timer and C_Timer.After) or skillsQueued then
    return
  end
  skillsQueued = true
  C_Timer.After(SKILL_DELAY, function()
    skillsQueued = false
    if settled then
      readProfessions()
    end
  end)
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
    C_Timer.After(RANK_DELAY, settle)
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
-- Lying down in a sleeping bag, or getting up, only changes an aura.
if frame.RegisterUnitEvent then
  frame:RegisterUnitEvent("UNIT_AURA", "player")
end
frame:RegisterEvent("PLAYER_REGEN_ENABLED") -- combat ended: read auras that changed during it
frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
frame:RegisterEvent("TIME_PLAYED_MSG")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("MAIL_SHOW")
frame:RegisterEvent("MAIL_CLOSED")
frame:RegisterEvent("MAIL_INBOX_UPDATE")
frame:RegisterEvent("MAIL_SEND_SUCCESS")
frame:RegisterEvent("MAIL_SUCCESS")
frame:RegisterEvent("MAIL_FAILED")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED") -- moves within the bank itself
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
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
-- The bank is read the same way, but only while it's open: it can't be read
-- from anywhere else.
local BAG_DELAY, ENTER_DELAY = 0.5, 1
local bankOpen = false

-- A queue for one kind of read: one pending read at a time, which runs
-- `tries` more times while an item link hasn't loaded.
local function readQueue(read)
  local queued, queue = false, nil
  queue = function(delay, tries)
    if queued then
      return
    end
    if not (C_Timer and C_Timer.After) then
      return read(0, queue)
    end
    queued = true
    C_Timer.After(delay, function()
      queued = false
      read(tries, queue)
    end)
  end
  return queue
end

local function readInto(field, reading, tries, queue)
  local key = ns.db and not leaving and ns.Game.CurrentKey()
  local c = key and ns.db.characters[key]
  if not c then
    return
  end
  if ns.Bags.Observe(c, reading, ns.Game.Now(), field) then
    ns.AltPanel.RefreshIfShowing(key)
  end
  if reading and reading.missing and tries > 0 then
    queue(RETRY_SECONDS, tries - 1)
  end
end

local queueBags = readQueue(function(tries, queue)
  readInto("bags", ns.Items.Carried(), tries, queue)
end)

local queueBank = readQueue(function(tries, queue)
  if bankOpen then
    readInto("bank", ns.Items.Banked(), tries, queue)
  end
end)

-- The inbox, read while the mailbox is open, once the game says it has loaded.
-- At login, mail warnings wait until the rest of the login chat has passed.
local MAIL_WARNING_DELAY = 5
local mailOpen, MAIL_DELAY = false, 0.3

local queueMail = readQueue(function(tries, queue)
  local key = mailOpen and not leaving and ns.Game.CurrentKey()
  local c = key and ns.db.characters[key]
  if not c then
    return
  end
  local reading = ns.Items.Inbox()
  if ns.Mail.Observe(c, reading, ns.Game.Now()) then
    ns.AltPanel.RefreshIfShowing(key)
    ns.MainWindow.RefreshIfShown()
  end
  if reading and reading.missing and tries > 0 then
    queue(RETRY_SECONDS, tries - 1)
  end
end)

-- Mail you send to one of your characters, or send back to one, shows on their
-- Mail tab at once. What's attached is noted when you press Send (or Return),
-- and added once the game says it has gone: `done` is the event that says so.
-- TSM and Syndicator track mail to alts the same way.
local outgoing

-- The key of one of your characters, from a name typed into the mail. With
-- names unique across the region, the realm isn't part of it. On Forever the
-- game reports each character's surname as its realm (/emberkeep debug on
-- 2026-11-27: realm=Doombringer for Pheumageddon Doombringer), so a bare name
-- can't be held to "your realm" there either.
local function findAlt(name)
  local regional = RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled()
  if regional then
    name = tostring(name or ""):gsub("%-.*$", "")
  end
  local me = ns.Game.Sighting()
  local realm = me.realm
  if regional or (me.surname and me.surname == realm) then
    realm = nil
  end
  local key = ns.Roster.FindByName(ns.db.characters, name, realm)
  return key ~= ns.Game.CurrentKey() and key or nil
end

local function noteSend(recipient)
  outgoing = nil
  local key = ns.db and findAlt(recipient)
  if key then
    outgoing = { key = key, mail = ns.Items.Outgoing(), done = "MAIL_SEND_SUCCESS" }
  end
end

local function noteReturn(index)
  outgoing = nil
  local mail = ns.db and ns.Items.InboxMail(index)
  local key = mail and findAlt(mail.sender)
  if key then
    mail.returned = true
    outgoing = { key = key, mail = mail, done = "MAIL_SUCCESS" }
  end
end

-- A mail sent back is confirmed by MAIL_SUCCESS, which other mailbox actions
-- send too, so it is forgotten when the mailbox closes. A send is not: its
-- MAIL_SEND_SUCCESS can arrive just after.
local function mailboxClosed()
  mailOpen = false
  if outgoing and outgoing.done == "MAIL_SUCCESS" then
    outgoing = nil
  end
end

if hooksecurefunc then
  hooksecurefunc("SendMail", function(recipient)
    pcall(noteSend, recipient)
  end)
  hooksecurefunc("ReturnInboxItem", function(index)
    pcall(noteReturn, index)
  end)
end

local function mailSent()
  local sent = outgoing
  outgoing = nil
  local me = ns.db and ns.db.characters[ns.Game.CurrentKey() or ""]
  if not (sent and me) then
    return
  end
  sent.mail.from = ns.Roster.DisplayName(me, ns.db.settings.hideSurnames)
  sent.mail.fromName = me.name
  if ns.Mail.Sent(ns.db.characters[sent.key], sent.mail, ns.Game.Now()) then
    ns.AltPanel.RefreshIfShowing(sent.key)
    ns.MainWindow.RefreshIfShown()
  end
end

local BANKER = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Banker
local MAILBOX = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.MailInfo

-- The bank window opening or closing, from either event that says so.
local function bankEvent(event, arg1)
  if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    if BANKER == nil or arg1 ~= BANKER then
      return
    end
  end
  local opened = event == "BANKFRAME_OPENED" or event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW"
  if opened and not bankOpen then
    bankOpen = true
    queueBank(BAG_DELAY, RETRIES) -- a moment after opening, once its slots have loaded
  elseif not opened then
    bankOpen = false
  end
end

-- The sleeping bag's XP buff, read whenever an aura changes. What was saved
-- for the character before this login is kept until the buff is first read,
-- to learn whether its timer runs while logged out.
local beforeLogin

local function noteLogin()
  local c = ns.db.characters[ns.Game.CurrentKey() or ""]
  if c and c.bagBuff then
    beforeLogin = { buff = c.bagBuff, lastSeen = c.lastSeen }
  end
end

-- An aura changed during combat, so read them once it ends.
local aurasChanged = false

local function readBagBuff()
  local c = not leaving and ns.db and ns.db.characters[ns.Game.CurrentKey() or ""]
  if not c then
    return
  end
  local reading, hidden = ns.Game.BagXpBuff()
  if hidden then
    return -- the game wouldn't say; keep what was saved
  end
  local now = ns.Game.Now()
  if beforeLogin then
    local verdict = ns.Rest.OfflineTimer(beforeLogin.buff, beforeLogin.lastSeen, reading, now)
    ns.db.bagBuffOffline = verdict or ns.db.bagBuffOffline
    beforeLogin = nil
  end
  if ns.Rest.ObserveBagBuff(c, reading, now) then
    ns.MainWindow.RefreshIfShown()
  end
end

-- Auras change all the time (every buff and cooldown), so only a change in
-- whether you're lying in a sleeping bag saves a new rest reading.
local function auraChanged()
  local key = ns.db and not leaving and ns.Game.CurrentKey()
  local c = key and ns.db.characters[key]
  if not (c and c.rest) then
    return
  end
  local obs = ns.Game.RestObservation()
  if (obs.bag and true or false) ~= (c.rest.bag and true or false) and ns.Rest.Observe(c, obs) then
    ns.MainWindow.RefreshIfShown()
  end
  -- Out of the bag but still in its grace: look again once that has passed,
  -- unless you've logged out by then.
  if obs.bag and not ns.Game.InSleepingBag() and C_Timer and C_Timer.After then
    C_Timer.After(ns.Game.BAG_GRACE + 1, auraChanged)
  end
end

local function handle(event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == addonName then
      EmberkeepDB = ns.Store.Ensure(EmberkeepDB)
      ns.db = EmberkeepDB
      noteLogin()
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
  if event == "UNIT_AURA" or event == "PLAYER_REGEN_ENABLED" then
    -- In combat the game hides auras from addons (asking throws an error),
    -- so aura changes wait until combat ends.
    if InCombatLockdown and InCombatLockdown() then
      aurasChanged = true
      return
    elseif event == "PLAYER_REGEN_ENABLED" and not aurasChanged then
      return
    end
    aurasChanged = false
    readBagBuff()
    return auraChanged()
  elseif event == "MAIL_SHOW" then
    mailOpen = true
    return
  elseif event == "MAIL_CLOSED" then
    return mailboxClosed()
  elseif event == "MAIL_INBOX_UPDATE" then
    if mailOpen then
      queueMail(MAIL_DELAY, RETRIES)
    end
    return
  elseif event == "MAIL_SEND_SUCCESS" or event == "MAIL_SUCCESS" then
    if outgoing and outgoing.done == event then
      mailSent()
    end
    return
  elseif event == "MAIL_FAILED" then
    outgoing = nil
    return
  elseif event == "PLAYERBANKSLOTS_CHANGED" then
    if bankOpen then
      queueBank(BAG_DELAY, RETRIES)
    end
    return
  elseif event == "BAG_UPDATE_DELAYED" then
    if bankOpen then
      queueBank(BAG_DELAY, RETRIES)
    end
    return queueBags(BAG_DELAY, RETRIES)
  elseif event:find("^PLAYER_INTERACTION_MANAGER_FRAME_") and MAILBOX ~= nil and arg1 == MAILBOX then
    -- Some clients send only these when the mailbox opens or closes.
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
      mailOpen = true
    else
      mailboxClosed()
    end
    return
  elseif event:find("^BANKFRAME_") or event:find("^PLAYER_INTERACTION_MANAGER_FRAME_") then
    return bankEvent(event, arg1)
  elseif event == "SKILL_LINES_CHANGED" then
    return skillsChanged()
  elseif event == "PLAYER_LEAVING_WORLD" then
    leaving, settled, bankOpen, mailOpen = true, false, false, false
    return
  elseif event == "PLAYER_ENTERING_WORLD" then
    leaving = false
  end
  observe(event, arg1)
  if event == "PLAYER_ENTERING_WORLD" then
    queueBags(ENTER_DELAY, RETRIES) -- whatever changed behind the loading screen
    -- Auras can still be loading just after entering the world.
    if C_Timer and C_Timer.After then
      C_Timer.After(RANK_DELAY, readBagBuff)
    else
      readBagBuff()
    end
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
    if C_Timer and C_Timer.After then
      C_Timer.After(MAIL_WARNING_DELAY, App.MailWarnings)
    else
      App.MailWarnings()
    end
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

-- At login, after the rest of the login chat: one line per character with mail
-- about to expire.
function App.MailWarnings()
  if not (ns.db and ns.db.settings.mailWarning) then
    return
  end
  local now = ns.Game.Now()
  for _, c in ipairs(ns.Roster.Characters(ns.db.characters)) do
    local left, deletes = ns.Mail.Soonest(c, now, ns.Mail.WARN_WITHIN)
    if left then
      local name = ns.Roster.DisplayName(c, ns.db.settings.hideSurnames)
      local when = left <= 0 and "has expired" or ("expires in " .. ns.Format.Duration(left))
      local after = deletes and "|cffff6060it will be deleted|r" or "then it goes back to the sender"
      ns.Say(string.format("%s has mail with items or gold that %s (%s).", name, when, after))
    end
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
    alts[i] = {
      level = r.level,
      class = r.classFile,
      percent = r.percent,
      full = r.full,
      resting = r.resting,
      where = r.where,
    }
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
