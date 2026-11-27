local Rest = dofile("Emberkeep/Core/Rest.lua")

local HOUR, DAY = 3600, 86400
local LEVEL = 10000 -- XP to level, a round number

local function rest(over)
  local r = { rested = 0, xpMax = LEVEL, resting = true, at = 0 }
  for k, v in pairs(over or {}) do
    r[k] = v
  end
  return r
end

describe("Rest.Project", function()
  it("builds 5% of a level per 8 hours in an inn", function()
    local p = Rest.Project(rest(), 8 * HOUR)
    assert.are.near(5, p.percent, 1e-9)
    assert.is_false(p.full)
  end)

  it("builds a quarter as fast outside an inn", function()
    local p = Rest.Project(rest({ resting = false }), 8 * HOUR)
    assert.are.near(1.25, p.percent, 1e-9)
  end)

  it("stops at 150% of a level and says when it filled", function()
    local p = Rest.Project(rest(), 30 * DAY)
    assert.are.near(150, p.percent, 1e-9)
    assert.is_true(p.full)
    assert.are.near(10 * DAY, p.fullAt, 1e-6) -- 150% / 15% a day
    assert.are.equal(0, p.secondsToFull)
  end)

  it("counts down to full", function()
    local p = Rest.Project(rest({ rested = 14000 }), 0) -- 140%, 10 points to go at 15% a day
    assert.are.near(DAY * 10 / 15, p.secondsToFull, 1e-6)
  end)

  it("raises the rate and the cap with Well Rested", function()
    local p = Rest.Project(rest(), 8 * HOUR, 5)
    assert.are.near(6, p.percent, 1e-9) -- 5% x 1.2
    local full = Rest.Project(rest(), 60 * DAY, 5)
    assert.are.near(180, full.percent, 1e-9) -- 150% x 1.2
  end)

  it("never shows more than the cap even if the game reported more", function()
    local p = Rest.Project(rest({ rested = 99999 }), 0)
    assert.are.near(150, p.percent, 1e-9)
    assert.is_true(p.full)
  end)
end)

describe("Rest.Observe", function()
  it("saves a good reading", function()
    local c = {}
    assert.is_true(Rest.Observe(c, { rested = 500, xpMax = LEVEL, resting = 1, at = 5 }))
    assert.are.same({ rested = 500, xpMax = LEVEL, resting = true, at = 5 }, c.rest)
  end)

  it("notes a sleeping bag only while resting in one", function()
    local c = {}
    Rest.Observe(c, { rested = 500, xpMax = LEVEL, resting = true, bag = true, at = 5 })
    assert.is_true(c.rest.bag)
    assert.are.equal("bag", Rest.Where(c.rest))
    Rest.Observe(c, { rested = 500, xpMax = LEVEL, resting = false, bag = true, at = 6 })
    assert.is_nil(c.rest.bag)
    assert.are.equal("outside", Rest.Where(c.rest))
    Rest.Observe(c, { rested = 500, xpMax = LEVEL, resting = true, at = 7 })
    assert.are.equal("inn", Rest.Where(c.rest))
    assert.are.equal("outside", Rest.Where(nil))
  end)

  it("fills a sleeping bag at the inn rate", function()
    local inn = Rest.Project({ rested = 0, xpMax = LEVEL, resting = true, at = 0 }, 8 * 3600)
    local bag = Rest.Project({ rested = 0, xpMax = LEVEL, resting = true, bag = true, at = 0 }, 8 * 3600)
    assert.are.equal(inn.rested, bag.rested)
  end)

  it("ignores the zero XP-to-level the game reports while logging out", function()
    local c = {}
    Rest.Observe(c, { rested = 500, xpMax = LEVEL, resting = true, at = 5 })
    assert.is_false(Rest.Observe(c, { rested = 0, xpMax = 0, resting = false, at = 9 }))
    assert.are.equal(500, c.rest.rested)
  end)

  it("treats no rested XP (nil from the game) as 0", function()
    local c = {}
    Rest.Observe(c, { xpMax = LEVEL, at = 1 })
    assert.are.equal(0, c.rest.rested)
  end)
end)

describe("Rest.PercentText", function()
  local function text(xp)
    return Rest.PercentText(Rest.Project(rest({ rested = xp }), 0))
  end

  it("shows one decimal, rounded", function()
    assert.are.equal("12.5%", text(1246))
    assert.are.equal("0.0%", text(0))
  end)

  it("shows a full alt as a whole number, and only a full one at the cap", function()
    assert.are.equal("150%", text(15000))
    assert.are.equal("149.9%", text(14999))
  end)
end)

describe("Rest.ObserveRank", function()
  it("saves a character's own rank, 0 included", function()
    local c = {}
    assert.is_true(Rest.ObserveRank(c, 3))
    assert.are.equal(3, c.wellRested)
    assert.is_true(Rest.ObserveRank(c, 0))
    assert.are.equal(0, c.wellRested)
  end)

  it("keeps the last rank when it couldn't be read", function()
    local c = { wellRested = 3 }
    assert.is_false(Rest.ObserveRank(c, nil))
    assert.is_false(Rest.ObserveRank(c, 9))
    assert.are.equal(3, c.wellRested)
  end)

  it("says what a rank does", function()
    assert.are.equal("Fills 8% faster, holds up to 162%", Rest.RankEffect(2))
    assert.are.equal("Fills 20% faster, holds up to 180%", Rest.RankEffect(5))
  end)
end)

describe("a rank never read", function()
  it("counts as 0, whatever was saved before 0.3.1", function()
    assert.are.near(150, Rest.Project(rest({ wellRested = 5 }), 60 * DAY).percent, 1e-9)
  end)
end)

describe("Rest.Ranking", function()
  it("uses each character's own Well Rested rank", function()
    local list = {
      { name = "None", level = 20, rest = rest(), wellRested = 0 },
      { name = "Five", level = 20, rest = rest(), wellRested = 5 },
      { name = "Unread", level = 20, rest = rest() },
    }
    local percents = {}
    for _, row in ipairs(Rest.Ranking(list, 60, DAY)) do
      percents[row.character.name] = row.projection.percent
    end
    assert.are.near(15, percents.None, 1e-9)
    assert.are.near(18, percents.Five, 1e-9)
    assert.are.near(15, percents.Unread, 1e-9)
  end)

  local function char(name, level, r)
    return { name = name, level = level, rest = r }
  end

  it("puts full alts first alphabetically, then the rest by how full", function()
    local now = 30 * DAY
    local list = {
      char("Morvain", 27, rest({ at = now - 1 * DAY })), -- 15%
      char("Thistle", 22, rest({ at = 0 })), -- full
      char("Elowen", 41, rest({ rested = 11800, at = now })), -- 118%
      char("Brakka", 34, rest({ at = 0 })), -- full
      char("Saelra", 60, rest({ at = 0 })), -- max level: left out
      char("New", 5, nil), -- never observed: left out
    }
    local names = {}
    for _, row in ipairs(Rest.Ranking(list, 60, now)) do
      names[#names + 1] = row.character.name
    end
    assert.are.same({ "Brakka", "Thistle", "Elowen", "Morvain" }, names)
  end)
end)
