local Columns = dofile("Emberkeep/Core/Columns.lua")

local cols = { { "#", 20 }, { "Character", 140, grow = 2 }, { "Lvl", 34 }, { "Rested", 130, grow = 1 } }

describe("Columns.Fit", function()
  it("keeps the set widths when there is no extra room", function()
    assert.are.same({ 20, 140, 34, 130 }, (Columns.Fit(cols, 0)))
    assert.are.same({ 20, 140, 34, 130 }, (Columns.Fit(cols, 300)))
    assert.are.same({ 20, 140, 34, 130 }, (Columns.Fit(cols, nil)))
  end)

  it("shares extra room between the growing columns by weight", function()
    local widths, total = Columns.Fit(cols, 324 + 90)
    assert.are.same({ 20, 200, 34, 160 }, widths)
    assert.are.equal(414, total)
  end)

  it("gives the rounding leftover to the first growing column, so the total is exact", function()
    local widths, total = Columns.Fit(cols, 324 + 10)
    assert.are.same({ 20, 147, 34, 133 }, widths)
    assert.are.equal(334, total)
  end)

  it("leaves the widths alone when no column grows", function()
    local fixed = { { "a", 50 }, { "b", 60 } }
    assert.are.same({ 50, 60 }, (Columns.Fit(fixed, 500)))
  end)
end)
