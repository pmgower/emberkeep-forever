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
  if key then
    ns.Rest.Observe(ns.db.characters[key], ns.Game.RestObservation())
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
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("UPDATE_EXHAUSTION")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == addonName then
      KinfolkDB = ns.Store.Ensure(KinfolkDB)
      ns.db = KinfolkDB
      local themeKeys = {}
      for _, t in ipairs(ns.Window.THEMES) do
        themeKeys[t.key] = true
      end
      ns.Settings.Apply(ns.db.settings, themeKeys)
      ns.versionText = ns.Version.Short(metadata("Version"))
      ns.MinimapButton.Init(ns.db)
      ns.OptionsPage.Init()
    end
    return
  end
  observe(event, arg1)
  if event == "PLAYER_ENTERING_WORLD" and not App.greeted then
    App.greeted = true
    App.LoginHint()
  end
end)

-- The chat line on login: who to play next, if anyone is full or filling.
function App.LoginHint()
  if not (ns.db and ns.db.settings.loginHint) then
    return
  end
  local _, summary =
    ns.RestedView.Build(ns.db.characters, ns, ns.Game.MaxLevel(), ns.Game.Now(), ns.Game.CurrentKey())
  local line = ns.RestedView.HintText(summary)
  if line then
    ns.Say(line)
  end
end
