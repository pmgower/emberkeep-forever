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

function Game.Sighting()
  local class, classFile = UnitClass("player")
  return {
    name = plain(UnitName("player")),
    realm = plain(GetRealmName()),
    class = plain(class),
    classFile = plain(classFile),
    race = plain(UnitRace("player")),
    faction = plain(UnitFactionGroup("player")),
    level = plain(UnitLevel("player")),
    money = plain(GetMoney()),
    zone = plain(GetRealZoneText()),
  }
end

-- The roster key of the character you're logged in on.
function Game.CurrentKey()
  local s = Game.Sighting()
  if not (s.name and s.realm) then
    return nil
  end
  return ns.Roster.Key(s.name, s.realm)
end

function Game.Now()
  return time()
end

function Game.MaxLevel()
  return plain(GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
end

-- Legacy's Well Rested perk: trait node 110301 in the account's Legacy trees
-- (a trait config of type Generic). Node id as found in game by the author of
-- Alts Forever (MIT). Returns nil when it can't be read.
local WELL_RESTED_NODE = 110301

local function wellRestedRank()
  local T = C_Traits
  if not (T and T.GetConfigsByType and T.GetNodeInfo) then
    return nil
  end
  local generic = Enum and Enum.TraitConfigType and Enum.TraitConfigType.Generic or 3
  local ok, configs = pcall(T.GetConfigsByType, generic)
  local config = ok and type(configs) == "table" and plain(configs[1])
  if not config then
    return nil
  end
  local ok2, info = pcall(T.GetNodeInfo, config, WELL_RESTED_NODE)
  local rank = ok2
    and type(info) == "table"
    and plain(info.ID) == WELL_RESTED_NODE
    and plain(info.currentRank)
  return type(rank) == "number" and rank or nil
end

function Game.RestObservation()
  return {
    rested = plain(GetXPExhaustion()),
    xpMax = plain(UnitXPMax("player")),
    resting = plain(IsResting()),
    wellRested = wellRestedRank(),
    at = time(),
  }
end
