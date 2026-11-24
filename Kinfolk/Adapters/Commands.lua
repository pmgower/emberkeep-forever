-- Commands: the /kinfolk slash command. Thin adapter: reads the TOC version
-- from the game and prints what Core formats.
local addonName, ns = ...

local function metadata(field)
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return get and get(addonName, field) or nil
end

SLASH_KINFOLK1 = "/kinfolk"
SlashCmdList.KINFOLK = function()
  local line = ns.Version.Line("Kinfolk: Forever", metadata("Version"))
  DEFAULT_CHAT_FRAME:AddMessage("|cff9fd0ff" .. line .. "|r")
end
