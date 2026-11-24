-- Commands: /kinfolk and its subcommands. Thin adapter over Core and the windows.
local addonName, ns = ...

local function say(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff9fd0ffKinfolk:|r " .. text)
end

local function metadata(field)
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return get and get(addonName, field) or nil
end

local commands = {
  version = function()
    say(ns.Version.Line("Kinfolk: Forever", metadata("Version")))
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
