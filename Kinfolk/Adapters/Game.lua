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

function Game.Now()
  return time()
end
