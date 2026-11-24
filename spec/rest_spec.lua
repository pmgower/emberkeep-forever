local Rest = dofile("Emberkeep/Core/Rest.lua")

local HOUR, DAY = 3600, 86400
local LEVEL = 10000 -- XP to level, a round number

local function rest(over)
  local r = { rested = 0, xpMax = LEVEL, resting = true, wellRested = 0, at = 0 }
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
    local p = Rest.Project(rest({ wellRested = 5 }), 8 * HOUR)
    assert.are.near(6, p.percent, 1e-9) -- 5% x 1.2
    local full = Rest.Project(rest({ wellRested = 5 }), 60 * DAY)
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
    assert.is_true(Rest.Observe(c, { rested = 500, xpMax = LEVEL, resting = 1, wellRested = 2, at = 5 }))
    assert.are.same({ rested = 500, xpMax = LEVEL, resting = true, wellRested = 2, at = 5 }, c.rest)
  end)

  it("ignores the zero XP-to-level the game reports while logging out", function()
    local c = {}
    Rest.Observe(c, { rested = 500, xpMax = LEVEL, resting = true, at = 5 })
    assert.is_false(Rest.Observe(c, { rested = 0, xpMax = 0, resting = false, at = 9 }))
    assert.are.equal(500, c.rest.rested)
  end)

  it("keeps the last Well Rested rank when it couldn't be read", function()
    local c = {}
    Rest.Observe(c, { rested = 0, xpMax = LEVEL, wellRested = 3, at = 1 })
    Rest.Observe(c, { rested = 10, xpMax = LEVEL, at = 2 })
    assert.are.equal(3, c.rest.wellRested)
  end)

  it("treats no rested XP (nil from the game) as 0", function()
    local c = {}
    Rest.Observe(c, { xpMax = LEVEL, at = 1 })
    assert.are.equal(0, c.rest.rested)
  end)
end)

describe("Rest.Ranking", function()
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
