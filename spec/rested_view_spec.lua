local deps = {
  Roster = dofile("Kinfolk/Core/Roster.lua"),
  Rest = dofile("Kinfolk/Core/Rest.lua"),
  Format = dofile("Kinfolk/Core/Format.lua"),
}
local RestedView = dofile("Kinfolk/Core/RestedView.lua")

local DAY, LEVEL, NOW = 86400, 10000, 30 * 86400

local function alt(store, name, level, rest)
  store[name .. "-Nightfall"] =
    { name = name, realm = "Nightfall", level = level, classFile = "WARRIOR", rest = rest }
end

local function rest(over)
  local r = { rested = 0, xpMax = LEVEL, resting = true, wellRested = 0, at = 0 }
  for k, v in pairs(over or {}) do
    r[k] = v
  end
  return r
end

local function store()
  local s = {}
  alt(s, "Brakka", 34, rest()) -- full
  alt(s, "Elowen", 41, rest({ rested = 11800, at = NOW })) -- 118%
  alt(s, "Quill", 18, rest({ resting = false, at = NOW - DAY })) -- outside: 3.75%
  alt(s, "Saelra", 60, rest()) -- max level
  return s
end

describe("RestedView.Build", function()
  it("ranks the levelling alts and leaves max level out", function()
    local rows, summary = RestedView.Build(store(), deps, 60, NOW)
    local names = {}
    for _, r in ipairs(rows) do
      names[#names + 1] = r.rank .. " " .. r.name
    end
    assert.are.same({ "1 Brakka", "2 Elowen", "3 Quill" }, names)
    assert.are.same({ levelling = 3, atMax = 1, full = 1, next = rows[1] }, summary)
  end)

  it("gives each row its percent, bar fill and time to full", function()
    local rows = RestedView.Build(store(), deps, 60, NOW)
    assert.are.equal(150, rows[1].percent)
    assert.are.equal(1, rows[1].fill)
    assert.are.equal("Full", rows[1].fullIn)
    assert.are.equal(118, rows[2].percent)
    assert.are.near(118 / 150, rows[2].fill, 1e-9)
    assert.are.equal("2d 3h", rows[2].fullIn) -- 32 points at 15% a day
    assert.is_false(rows[3].resting)
  end)

  it("skips the character you're on when picking who to play next", function()
    local _, summary = RestedView.Build(store(), deps, 60, NOW, "Brakka-Nightfall")
    assert.are.equal("Elowen", summary.next.name)
  end)
end)

describe("RestedView text", function()
  it("sums up the title bar and the minimap tooltip", function()
    local rows, summary = RestedView.Build(store(), deps, 60, NOW)
    assert.are.equal("3 levelling · 1 at max", RestedView.RightText(summary))
    assert.are.equal("1 alt full, 2 still resting", RestedView.CountText(rows, summary))
    assert.are.equal("No alts below max level yet", RestedView.CountText({}, { full = 0 }))
  end)

  it("names who to play next on login, or stays quiet", function()
    local _, summary = RestedView.Build(store(), deps, 60, NOW)
    assert.are.equal("play next Brakka (150% rested, full)", RestedView.HintText(summary))
    local quiet = {}
    alt(quiet, "Morvain", 27, rest({ at = NOW }))
    local _, s2 = RestedView.Build(quiet, deps, 60, NOW)
    assert.is_nil(RestedView.HintText(s2))
  end)
end)
