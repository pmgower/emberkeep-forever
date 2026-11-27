-- Lua 5.1 plus only the WoW API the addon uses. A slice that reaches for a
-- new game API has to add it here, in plain sight.
std = "lua51"
max_line_length = 110
exclude_files = { ".luacheckrc", ".busted", "Emberkeep/Libs/**" }
ignore = { "212" } -- unused arguments (event handlers often ignore some)

files["spec/**"] = { std = "+busted" }

-- Globals the addon creates.
globals = { "EmberkeepDB", "SLASH_EMBERKEEP1", "SlashCmdList" }

-- WoW API the adapters read. Core/ must not use any of these (scripts/core-purity.sh).
read_globals = {
  "C_AddOns", "CreateFrame", "DEFAULT_CHAT_FRAME", "GameTooltip", "GetAddOnMetadata",
  "GetCursorPosition", "GetMoney", "GetRealZoneText", "GetRealmName", "IsMouseButtonDown",
  "IsShiftKeyDown", "LibStub", "MinimalSliderWithSteppersMixin", "CreateSettingsButtonInitializer",
  "Settings", "RAID_CLASS_COLORS", "UIParent", "UISpecialFrames", "UnitClass",
  "UnitFactionGroup", "UnitLevel", "UnitName", "UnitRace", "issecretvalue", "time", "tinsert",
  -- Rested XP (slice 2)
  "C_Traits", "Enum", "GetMaxPlayerLevel", "GetXPExhaustion", "IsResting", "UnitXPMax", "geterrorhandler",
  "GetNormalizedRealmName", "UnitFullName",
  -- Bug reports
  "seterrorhandler", "debugstack", "GetBuildInfo", "GetLocale", "IsControlKeyDown", "C_Timer", "BugSack", "BugGrabber",
  -- Right-click menu
  "MenuUtil",
  -- Time played
  "RequestTimePlayed", "NUM_CHAT_WINDOWS",
  -- Location column
  "GetSubZoneText",
  -- Gear
  "C_Item", "GetInventoryItemID", "GetInventoryItemLink", "HandleModifiedItemClick", "IsModifiedClick",
  "ITEM_QUALITY_COLORS",
  -- Professions
  "GetProfessions", "GetProfessionInfo", "strlenutf8",
  -- Bags
  "C_Container", "GetKeyRingSize", "NUM_TOTAL_EQUIPPED_BAG_SLOTS",
  -- Mail
  "ATTACHMENTS_MAX_RECEIVE", "ATTACHMENTS_MAX_SEND", "GetInboxHeaderInfo", "GetInboxItem", "GetInboxItemLink",
  "GetInboxNumItems", "GetSendMailItem", "GetSendMailItemLink", "GetSendMailMoney", "hooksecurefunc",
  "RegionalUniqueNamesEnabled",
  -- Bank
  "BANK_CONTAINER", "NUM_BAG_SLOTS", "NUM_BANKBAGSLOTS", "C_Bank",
  -- Sleeping bag rest
  "C_UnitAuras", "UnitBuff",
  -- Button on the Character window
  "CharacterFrame",
}
