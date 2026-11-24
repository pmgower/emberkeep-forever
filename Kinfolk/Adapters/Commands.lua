-- Commands: /kinfolk and its subcommands. Thin adapter over Core and the windows.
local addonName, ns = ...

local function say(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff9fd0ffKinfolk:|r " .. text)
end
ns.Say = say

local function metadata(field)
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return get and get(addonName, field) or nil
end

local commands = {
  version = function()
    say(ns.Version.Line("version", metadata("Version")))
  end,
  forget = function(name)
    if name == "" then
      return say("type /kinfolk forget <name>")
    end
    local me = ns.Game.Sighting().name
    if me and me:lower() == name:lower() then
      return say(
        "you're logged in on "
          .. me
          .. ", so they'd be added straight back. Forget them from another character."
      )
    end
    local n = ns.Roster.Forget(ns.db.characters, name)
    say(string.format("forgot %d character(s) named %s", n, name))
    ns.MainWindow.RefreshIfShown()
  end,
  -- What the game reports and what Kinfolk saved, for bug reports.
  debug = function()
    local s = ns.Game.Sighting()
    say(
      string.format(
        "you: name=%s realm=%s level=%s class=%s",
        tostring(s.name),
        tostring(s.realm),
        tostring(s.level),
        tostring(s.classFile)
      )
    )
    local ok, rest = pcall(ns.Game.RestObservation)
    if ok then
      say(
        string.format(
          "rest: rested=%s xpMax=%s resting=%s maxLevel=%s",
          tostring(rest.rested),
          tostring(rest.xpMax),
          tostring(rest.resting),
          tostring(ns.Game.MaxLevel())
        )
      )
    else
      say("rest read failed: " .. tostring(rest))
    end
    local db = ns.db
    if not db then
      return say("no saved data loaded (ADDON_LOADED didn't finish)")
    end
    local count = 0
    for key, c in pairs(db.characters) do
      count = count + 1
      say(string.format("saved %s: level=%s rest=%s", key, tostring(c.level), c.rest and "yes" or "no"))
    end
    say(count .. " character(s) saved")
    for _, e in ipairs(ns.App.errors) do
      say("|cffff6060error|r " .. e)
    end
  end,
  options = function()
    ns.OptionsPage.Open()
  end,
  reset = function()
    ns.Window.ResetAll()
    say("window moved back to the middle of the screen")
  end,
}

SLASH_KINFOLK1 = "/kinfolk"
SlashCmdList.KINFOLK = function(input)
  local cmd, rest = tostring(input or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  if cmd == "" then
    return ns.MainWindow.Toggle()
  end
  local fn = commands[cmd]
  if fn then
    return fn(rest)
  end
  say("/kinfolk opens the window. Also: options, version, forget <name>, reset")
end
