local Gear = dofile("Emberkeep/Core/Gear.lua")

local function link(id, name)
  return "|cffffffff|Hitem:" .. id .. "::::::::34|h[" .. name .. "]|h|r"
end

-- Looks items up by id in a table; unknown ones come back empty, like an item
-- the game hasn't loaded.
local function infoFrom(items)
  return function(l)
    return items[Gear.ItemId(l)]
  end
end

describe("Gear.Observe", function()
  it("saves a link per worn slot with the time", function()
    local c = {}
    assert.is_true(Gear.Observe(c, { [1] = { id = 10, link = link(10, "Cap") } }, 500))
    assert.are.same({ slots = { [1] = link(10, "Cap") }, at = 500 }, c.gear)
  end)

  it("ignores an empty reading, so it never wipes what was saved", function()
    local c = { gear = { slots = { [1] = link(10, "Cap") }, at = 500 } }
    assert.is_false(Gear.Observe(c, {}, 900))
    assert.are.same({ slots = { [1] = link(10, "Cap") }, at = 500 }, c.gear)
  end)

  it("drops a slot that was taken off", function()
    local c = { gear = { slots = { [1] = link(10, "Cap"), [2] = link(11, "Chain") }, at = 500 } }
    Gear.Observe(c, { [2] = { id = 11, link = link(11, "Chain") } }, 900)
    assert.is_nil(c.gear.slots[1])
    assert.are.equal(900, c.gear.at)
  end)

  it("keeps the saved link when the same item's link hasn't loaded", function()
    local c = { gear = { slots = { [1] = link(10, "Cap") }, at = 500 } }
    Gear.Observe(c, { [1] = { id = 10 } }, 900)
    assert.are.equal(link(10, "Cap"), c.gear.slots[1])
  end)

  it("saves a bare item when a different one's link hasn't loaded", function()
    local c = { gear = { slots = { [1] = link(10, "Cap") }, at = 500 } }
    Gear.Observe(c, { [1] = { id = 12 } }, 900)
    assert.are.equal("item:12", c.gear.slots[1])
  end)

  it("says when a link is missing, so it can be read again", function()
    local c = {}
    local _, missing = Gear.Observe(c, { [1] = { id = 12 } }, 900)
    assert.is_true(missing)
    _, missing = Gear.Observe(c, { [1] = { id = 12, link = link(12, "Hood") } }, 902)
    assert.is_false(missing)
    assert.are.equal(link(12, "Hood"), c.gear.slots[1])
  end)
end)

describe("Gear.View", function()
  it("is nil for a character whose gear was never saved", function()
    assert.is_nil(Gear.View({ level = 10 }, infoFrom({})))
  end)

  it("lists every slot, with the item's name, quality and level", function()
    local c = { level = 25, gear = { at = 500, slots = { [5] = link(20, "Robe") } } }
    local view = Gear.View(c, infoFrom({ [20] = { quality = 3, itemLevel = 26 } }))
    local chest = view.slots[5]
    assert.are.equal("Robe", chest.name)
    assert.are.equal(3, chest.quality)
    assert.are.equal(26, chest.itemLevel)
    assert.is_false(chest.outleveled)
    assert.are.equal(16, view.empty)
    assert.are.equal(500, view.at)
  end)

  it("names an item the game hasn't loaded from its link, or says it's loading", function()
    local c = { level = 25, gear = { at = 1, slots = { [1] = link(10, "Cap"), [2] = "item:11" } } }
    local view = Gear.View(c, infoFrom({}))
    assert.are.equal("Cap", view.slots[1].name)
    assert.are.equal("Loading...", view.slots[2].name)
  end)

  it("marks an item more than 8 levels below its wearer, from level 10 on", function()
    local info = infoFrom({ [10] = { itemLevel = 16 }, [11] = { itemLevel = 17 } })
    local slots = { [1] = link(10, "Old Cap"), [2] = link(11, "Chain") }
    local view = Gear.View({ level = 25, gear = { at = 1, slots = slots } }, info)
    assert.is_true(view.slots[1].outleveled)
    assert.is_false(view.slots[2].outleveled)
    assert.are.equal(1, view.outleveled)
    local low = infoFrom({ [10] = { itemLevel = 1 }, [11] = { itemLevel = 1 } })
    assert.are.equal(0, Gear.View({ level = 9, gear = { at = 1, slots = slots } }, low).outleveled)
  end)

  it("doesn't count the off hand as empty behind a two-handed weapon", function()
    local c = { level = 25, gear = { at = 1, slots = { [16] = link(30, "Staff") } } }
    local view = Gear.View(c, infoFrom({ [30] = { twoHanded = true } }))
    assert.is_true(view.slots[17].usedByTwoHander)
    assert.are.equal(15, view.empty)
  end)

  it("places every slot once in the two columns", function()
    local seen = {}
    for _, side in ipairs({ Gear.LEFT, Gear.RIGHT }) do
      for _, id in ipairs(side) do
        assert.is_nil(seen[id])
        seen[id] = true
      end
    end
    for _, slot in ipairs(Gear.SLOTS) do
      assert.is_true(seen[slot.id], slot.label)
    end
  end)
end)

describe("Gear.Summary", function()
  it("counts empty and outleveled slots", function()
    assert.are.equal("4 empty slots, 1 outleveled", Gear.Summary({ empty = 4, outleveled = 1 }))
    assert.are.equal("1 empty slot", Gear.Summary({ empty = 1, outleveled = 0 }))
  end)
end)

describe("Gear.Step", function()
  it("moves along the list and wraps round", function()
    local keys = { "a", "b", "c" }
    assert.are.equal("b", Gear.Step(keys, "a", 1))
    assert.are.equal("a", Gear.Step(keys, "c", 1))
    assert.are.equal("c", Gear.Step(keys, "a", -1))
  end)

  it("starts at the top when the key isn't listed, and copes with no rows", function()
    assert.are.equal("a", Gear.Step({ "a" }, "gone", 1))
    assert.is_nil(Gear.Step({}, "gone", 1))
  end)
end)
