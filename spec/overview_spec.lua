local Roster = dofile("Emberkeep/Core/Roster.lua")
local Format = dofile("Emberkeep/Core/Format.lua")
local Overview = dofile("Emberkeep/Core/Overview.lua")

describe("Overview.Build", function()
  it("makes one row per character and totals the gold", function()
    local store = {}
    Roster.Observe(
      store,
      { name = "Saelra", realm = "R", classFile = "MAGE", level = 60, money = 12040000 },
      0
    )
    Roster.Observe(
      store,
      { name = "Quill", realm = "R", classFile = "ROGUE", level = 18, money = 36100, zone = "The Barrens" },
      0
    )
    local rows, summary = Overview.Build(store, Roster, Format, 4 * 86400)
    assert.are.equal(2, summary.count)
    assert.are.equal("1,207g", summary.money.gold)
    assert.are.equal("Saelra", rows[1].name)
    assert.are.equal("60", rows[1].level)
    assert.are.equal("Quill", rows[2].name)
    assert.are.equal("The Barrens", rows[2].zone)
    assert.are.equal("4 days ago", rows[2].seen)
  end)

  it("shows time played, counting on for the character you're on, and totals it", function()
    local Played = dofile("Emberkeep/Core/Played.lua")
    local store = {}
    Roster.Observe(store, { name = "Saelra", realm = "R", level = 60 }, 0)
    Roster.Observe(store, { name = "Quill", realm = "R", level = 18 }, 0)
    Roster.Observe(store, { name = "New", realm = "R", level = 1 }, 0)
    Played.Observe(store["Saelra-R"], 3 * 86400, 0)
    Played.Observe(store["Quill-R"], 3600, 0)
    local rows, summary = Overview.Build(store, Roster, Format, 1800, { currentKey = "Quill-R" }, Played)
    assert.are.equal("3d 0h", rows[1].played)
    assert.are.equal("1h 30m", rows[2].played)
    assert.are.equal("", rows[3].played, "not read yet")
    assert.are.equal("3d 1h", summary.played)
  end)

  it("shows ? for a level never read", function()
    local store = {}
    Roster.Observe(store, { name = "New", realm = "R" }, 0)
    local rows = Overview.Build(store, Roster, Format, 0)
    assert.are.equal("?", rows[1].level)
  end)
end)
