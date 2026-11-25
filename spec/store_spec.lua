local Store = dofile("Emberkeep/Core/Store.lua")

describe("Store.Ensure", function()
  it("builds every part on first run", function()
    local db = Store.Ensure(nil)
    assert.are.same({ characters = {}, settings = { window = {} } }, db)
  end)

  it("drops the one Well Rested rank for every character", function()
    local rest = { rested = 5, xpMax = 10, wellRested = 2 }
    local db = Store.Ensure({ wellRested = 2, characters = { ["A-R"] = { wellRested = 1, rest = rest } } })
    assert.is_nil(db.wellRested)
    assert.are.equal(2, db.characters["A-R"].rest.wellRested, "kept as a guess until it's read")
    assert.are.equal(1, db.characters["A-R"].wellRested)
  end)

  it("keeps saved data", function()
    local db = Store.Ensure({ characters = { ["A-R"] = { name = "A" } }, settings = { locked = true } })
    assert.are.equal("A", db.characters["A-R"].name)
    assert.is_true(db.settings.locked)
    assert.are.same({}, db.settings.window)
  end)

  it("keeps the minimap button's saved place and the player's options", function()
    local saved = {
      characters = {},
      minimapIcon = { hide = true, minimapPos = 200 },
      settings = { theme = "twilight", scale = 1.2, window = { point = { "CENTER" } } },
    }
    local db = Store.Ensure(saved)
    assert.are.same({ hide = true, minimapPos = 200 }, db.minimapIcon)
    assert.are.equal("twilight", db.settings.theme)
    assert.are.equal(1.2, db.settings.scale)
    assert.are.same({ "CENTER" }, db.settings.window.point)
  end)

  it("replaces parts that are the wrong type", function()
    local db = Store.Ensure({ characters = "oops" })
    assert.are.same({}, db.characters)
  end)
end)
