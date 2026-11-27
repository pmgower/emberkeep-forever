-- Commands: /emberkeep and its subcommands. Thin adapter over Core and the windows.
local addonName, ns = ...

local function say(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff9fd0ffEmberkeep:|r " .. text)
end
ns.Say = say

local function metadata(field)
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return get and get(addonName, field) or nil
end

local commands
commands = {
  version = function()
    say(ns.Version.Line("version", metadata("Version")))
  end,
  remove = function(name)
    if name == "" then
      return say("type /emberkeep remove <name>")
    end
    local s = ns.Game.Sighting()
    local me = s.name and ns.Roster.DisplayName(s)
    local wanted = name:lower()
    if me and (wanted == me:lower() or wanted == s.name:lower()) then
      return say(
        "you're logged in on "
          .. me
          .. ", so they'd be added straight back. Remove them from another character."
      )
    end
    local n = ns.Roster.Forget(ns.db.characters, name)
    say(string.format("removed %d character(s) named %s", n, name))
    ns.MainWindow.RefreshIfShown()
  end,
  -- The command's old name, still accepted.
  forget = function(name)
    return commands.remove(name)
  end,
  -- What the game reports and what Emberkeep saved, for bug reports.
  debug = function()
    local s = ns.Game.Sighting()
    say(
      string.format(
        "you: name=%s surname=%s realm=%s level=%s class=%s",
        tostring(s.name),
        tostring(s.surname),
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
    local ok2, buff = pcall(ns.Game.BagXpBuff)
    if ok2 and buff then
      local line = "sleeping bag buff: %d stack(s), %ds left, spell %s"
      say(string.format(line, buff.stacks, buff.left, tostring(buff.spellId)))
    else
      say("sleeping bag buff: not on you")
    end
    say("its timer while logged out: " .. (db.bagBuffOffline or "not measured yet"))
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
  feedback = function()
    ns.App.OpenFeedback()
  end,
  options = function()
    ns.OptionsPage.Open()
  end,
  search = function(text)
    ns.MainWindow.Search(text)
  end,
  reset = function()
    ns.Window.ResetAll()
    say("window moved back to the middle of the screen")
  end,
}

SLASH_EMBERKEEP1 = "/emberkeep"
SlashCmdList.EMBERKEEP = function(input)
  local cmd, rest = tostring(input or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  if cmd == "" then
    return ns.MainWindow.Toggle()
  end
  local fn = commands[cmd]
  if fn then
    return fn(rest)
  end
  say("/emberkeep opens the window. Also: search <item>, options, feedback, version, remove <name>, reset")
end
