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
        local rank = plain(info.currentRank)
        return type(rank) == "number" and rank or nil
      end
    end
  end
  return nil
end

-- wellRested is the account's rank, read once and passed in, so this cheap
-- read can run on every XP change.
function Game.RestObservation(wellRested)
  return {
    rested = plain(GetXPExhaustion()),
    xpMax = plain(UnitXPMax("player")),
    resting = plain(IsResting()),
    wellRested = wellRested,
    at = time(),
  }
end

-- What the Rested views need to know about this moment.
function Game.RestContext(db, now)
  return {
    maxLevel = Game.MaxLevel(),
    now = now or time(),
    currentKey = Game.CurrentKey(),
    wellRested = db.wellRested,
  }
end
