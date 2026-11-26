local Bags = dofile("Emberkeep/Core/Bags.lua")

local reading = {
  items = { { link = "item:1", count = 5 }, { link = "item:2", count = 1 } },
  free = 14,
  total = 16,
}

describe("Bags.Observe", function()
  it("saves the items, free and total slots with the time", function()
    local c = {}
    assert.is_true(Bags.Observe(c, reading, 500))
    assert.are.same({ items = reading.items, free = 14, total = 16, at = 500 }, c.bags)
    assert.are_not.equal(reading.items, c.bags.items)
  end)

  it("ignores a reading with no bag slots, so it never wipes what was saved", function()
    local c = { bags = { items = {}, free = 3, total = 16, at = 500 } }
    assert.is_false(Bags.Observe(c, { items = {}, free = 0, total = 0 }, 900))
    assert.is_false(Bags.Observe(c, nil, 900))
    assert.are.equal(500, c.bags.at)
  end)

  it("keeps the saved link while the same item's link hasn't loaded", function()
    local c = {}
    local ring = { id = 7, link = "|Hitem:7:99|h[Ring]|h", count = 1 }
    Bags.Observe(c, { items = { ring }, free = 1, total = 2 }, 1)
    Bags.Observe(c, { items = { { id = 8, count = 1 }, { id = 7, count = 1 } }, free = 0, total = 2 }, 2)
    assert.are.equal("item:8", c.bags.items[1].link)
    assert.are.equal("|Hitem:7:99|h[Ring]|h", c.bags.items[2].link)
  end)

  it("saves bags that are really empty", function()
    local c = { bags = { items = reading.items, free = 14, total = 16, at = 500 } }
    assert.is_true(Bags.Observe(c, { items = {}, free = 16, total = 16 }, 900))
    assert.are.same({}, c.bags.items)
  end)
end)

describe("the bank", function()
  it("is saved and shown on its own, apart from the bags", function()
    local c = {}
    Bags.Observe(c, reading, 500)
    local bank = { items = { { id = 9, link = "item:9", count = 20 } }, free = 27, total = 28 }
    assert.is_true(Bags.Observe(c, bank, 600, "bank"))
    assert.are.equal(16, c.bags.total)
    assert.are.equal(28, c.bank.total)
    local view = Bags.View(c, function() end, "bank")
    assert.are.equal(20, view.rows[1].count)
    assert.are.equal(600, view.at)
    assert.is_nil(Bags.View({ bags = c.bags }, function() end, "bank"))
    local partial = { items = {}, free = 28, total = 28, incomplete = true }
    assert.is_false(Bags.Observe(c, partial, 700, "bank"), "part of the bank not loaded")
    assert.are.equal(600, c.bank.at)
  end)
end)

describe("Bags.View", function()
  it("is nil for a character whose bags were never saved", function()
    assert.is_nil(Bags.View({}, function() end))
  end)

  it("lists items in order with what the game knows about them", function()
    local c = {}
    Bags.Observe(c, reading, 500)
    local view = Bags.View(c, function(link)
      return link == "item:1" and { name = "Linen", quality = 1, icon = 7 } or nil
    end)
    assert.are.same({ link = "item:1", count = 5, name = "Linen", quality = 1, icon = 7 }, view.rows[1])
    assert.are.same({ link = "item:2", count = 1 }, view.rows[2])
    assert.are.equal("14 of 16 slots free", Bags.Summary(view))
  end)
end)
