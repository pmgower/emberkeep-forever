local Store = dofile("Kinfolk/Core/Store.lua")

describe("Store.Ensure", function()
  it("builds every part on first run", function()
    local db = Store.Ensure(nil)
    assert.are.same({ characters = {}, settings = { window = {} } }, db)
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
