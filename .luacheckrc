-- Lua 5.1 plus only the WoW API the addon uses. A slice that reaches for a
-- new game API has to add it here, in plain sight.
std = "lua51"
max_line_length = 110
exclude_files = { ".luacheckrc", ".busted", "Kinfolk/Libs/**" }
ignore = { "212" } -- unused arguments (event handlers often ignore some)

files["spec/**"] = { std = "+busted" }

-- Globals the addon creates.
globals = { "KinfolkDB", "SLASH_KINFOLK1", "SlashCmdList" }

-- WoW API the adapters read. Core/ must not use any of these (scripts/core-purity.sh).
read_globals = {
  "C_AddOns", "CreateFrame", "DEFAULT_CHAT_FRAME", "GameTooltip", "GetAddOnMetadata",
  "GetCursorPosition", "GetMoney", "GetRealZoneText", "GetRealmName", "IsMouseButtonDown",
  "IsShiftKeyDown", "LibStub", "MinimalSliderWithSteppersMixin", "CreateSettingsButtonInitializer",
  "Settings", "RAID_CLASS_COLORS", "UIParent", "UISpecialFrames", "UnitClass",
  "UnitFactionGroup", "UnitLevel", "UnitName", "UnitRace", "issecretvalue", "time", "tinsert",
  -- Rested XP (slice 2)
  "C_Traits", "Enum", "GetMaxPlayerLevel", "GetXPExhaustion", "IsResting", "UnitXPMax",
}
