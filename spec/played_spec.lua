local Played = dofile("Emberkeep/Core/Played.lua")

describe("Played", function()
  it("keeps the game's answer and counts on for the character you're on", function()
    local c = {}
    assert.is_true(Played.Observe(c, 7200, 1000))
    assert.are.equal(7200, Played.Total(c, 1600, false))
    assert.are.equal(7800, Played.Total(c, 1600, true))
  end)

  it("knows nothing until the game answers, and ignores a bad answer", function()
    local c = {}
    assert.is_nil(Played.Total(c, 0, true))
    assert.is_false(Played.Observe(c, nil, 1000))
    assert.is_false(Played.Observe(c, -5, 1000))
    assert.is_nil(c.played)
  end)

  it("folds the session into the total on logout", function()
    local c = {}
    Played.Observe(c, 7200, 1000)
    Played.Settle(c, 1600)
    assert.are.same({ total = 7800, at = 1600 }, c.played)
    assert.are.equal(7800, Played.Total(c, 99999, false), "an alt you're not on doesn't count on")
    local never = {}
    Played.Settle(never, 1600)
    assert.is_nil(never.played)
  end)
end)
