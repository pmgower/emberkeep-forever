-- Game: reads what the game knows about the logged-in character right now and
-- hands it to Core as a sighting. The only file that asks the game about the
-- character, so a Forever API change lands here alone.
local _, ns = ...
local Game = {}
ns.Game = Game

local secret = issecretvalue or function()
  return false
end

-- A value the client hides from addons (a "secret value") reads as nil.
local function plain(v)
  if v == nil or secret(v) then
    return nil
  end
  return v
end

-- WoW Forever reports an empty realm name, so try the other ways the client
-- names the realm and fall back to one fixed name. Every character then
-- still gets a stable key ("Jango-Forever").
Game.DEFAULT_REALM = "Forever"

local function nonEmpty(v)
  v = plain(v)
  return type(v) == "string" and v ~= "" and v or nil
end

function Game.Realm()
  local fromFull = UnitFullName and select(2, UnitFullName("player"))
  return nonEmpty(GetRealmName())
    or nonEmpty(GetNormalizedRealmName and GetNormalizedRealmName())
    or nonEmpty(fromFull)
    or Game.DEFAULT_REALM
end

-- On Forever, UnitName's second value is the character's surname, not a
-- realm (Forever names have two parts; AllTheThings issue #2630).
function Game.Sighting()
  local class, classFile = UnitClass("player")
  local first, second = UnitName("player")
  return {
    name = plain(first),
    surname = nonEmpty(second),
    realm = Game.Realm(),
    class = plain(class),
    classFile = plain(classFile),
    race = plain(UnitRace("player")),
    faction = plain(UnitFactionGroup("player")),
    level = plain(UnitLevel("player")),
    money = plain(GetMoney()),
    zone = plain(GetRealZoneText()),
    subzone = plain(GetSubZoneText and GetSubZoneText()),
  }
end

-- The roster key of the character you're logged in on.
function Game.CurrentKey()
  local s = Game.Sighting()
  if not (s.name and s.realm) then
    return nil
  end
  return ns.Roster.Key(s.name, s.realm, s.surname)
end

function Game.Now()
  return time()
end

function Game.MaxLevel()
  return plain(GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
end

-- Legacy's Well Rested perk: trait node 110301 in the Legacy trees
-- (a trait config of type Generic). Node id as found in game by the author of
-- Alts Forever (MIT). Returns nil when it can't be read.
local WELL_RESTED_NODE = 110301

-- Several trees are Generic (Skyriding is one), so look in each for the node.
function Game.WellRestedRank()
  local T = C_Traits
  if not (T and T.GetConfigsByType and T.GetNodeInfo) then
    return nil
  end
  local generic = Enum and Enum.TraitConfigType and Enum.TraitConfigType.Generic or 3
  local ok, configs = pcall(T.GetConfigsByType, generic)
  if not (ok and type(configs) == "table") then
    return nil
  end
  for _, config in ipairs(configs) do
    config = plain(config)
    if config then
      local ok2, info = pcall(T.GetNodeInfo, config, WELL_RESTED_NODE)
      if ok2 and type(info) == "table" and plain(info.ID) == WELL_RESTED_NODE then
        -- activeRank is what's committed; currentRank can include points
        -- placed in the window but not applied.
        local rank = plain(info.activeRank)
        if type(rank) ~= "number" then
          rank = plain(info.currentRank)
        end
        return type(rank) == "number" and rank or nil
      end
    end
  end
  return nil
end

-- A cheap read, so it can run on every XP change.
function Game.RestObservation()
  return {
    rested = plain(GetXPExhaustion()),
    xpMax = plain(UnitXPMax("player")),
    resting = plain(IsResting()),
    at = time(),
  }
end

-- /played time. The game answers RequestTimePlayed with TIME_PLAYED_MSG, and
-- every chat window prints that answer as two lines. Asking on each login
-- would spam chat, so while our own request is out the chat windows stop
-- listening for the answer, and listen again once it arrives (or after 10
-- seconds, if it never does).
local muted

function Game.PlayedAnswered()
  if not muted then
    return
  end
  for _, f in ipairs(muted) do
    f:RegisterEvent("TIME_PLAYED_MSG")
  end
  muted = nil
end

function Game.RequestPlayed()
  if not RequestTimePlayed or muted then
    return false
  end
  muted = {}
  for i = 1, NUM_CHAT_WINDOWS or 10 do
    local f = _G["ChatFrame" .. i]
    if f and f.IsEventRegistered and f:IsEventRegistered("TIME_PLAYED_MSG") then
      f:UnregisterEvent("TIME_PLAYED_MSG")
      muted[#muted + 1] = f
    end
  end
  RequestTimePlayed()
  if C_Timer and C_Timer.After then
    C_Timer.After(10, Game.PlayedAnswered)
  end
  return true
end

-- What the Rested views need to know about this moment.
function Game.RestContext(db, now)
  return {
    maxLevel = Game.MaxLevel(),
    now = now or time(),
    currentKey = Game.CurrentKey(),
    hideSurnames = db.settings.hideSurnames,
  }
end
