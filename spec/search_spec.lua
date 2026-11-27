local Search = dofile("Emberkeep/Core/Search.lua")

local function link(id, name, hex)
  return "|cff" .. (hex or "ffffff") .. "|Hitem:" .. id .. "::|h[" .. name .. "]|h|r"
end

local LINEN = link(2589, "Linen Cloth")
local SWORD = link(10, "Sword", "a335ee")
local ROBE = link(20, "Silk Robe", "1eff00")
local ITEMS = {
  [2589] = { name = "Linen Cloth", quality = 1, classID = 7, itemLevel = 5 },
  [10] = {
    name = "Sword",
    quality = 4,
    classID = 2,
    itemLevel = 40,
    equipLoc = "INVTYPE_WEAPON",
    bindType = 2,
  },
  [20] = {
    name = "Silk Robe",
    quality = 2,
    classID = 4,
    subclassID = 1,
    itemLevel = 25,
    equipLoc = "INVTYPE_ROBE",
  },
}

local function info(l)
  return ITEMS[tonumber(l:match("item:(%d+)"))]
end

local characters = {
  ["Brakka-Nightfall"] = {
    bags = { items = { { link = LINEN, count = 15 }, { link = SWORD, count = 1 } } },
    bank = { items = { { link = LINEN, count = 5 } } },
    gear = { slots = { [5] = ROBE } },
  },
  ["Quill-Nightfall"] = {
    bags = { items = { { link = LINEN, count = 20 } } },
    mail = {
      inbox = { { items = { { link = LINEN, count = 10 } } } },
      sent = {
        { items = { { link = SWORD, count = 1 } }, expires = 100 },
        { items = { { link = ROBE, count = 1 } }, expires = 5 }, -- gone back by now
      },
    },
  },
}

local function names(result)
  local list = {}
  for i, item in ipairs(result.items) do
    list[i] = item.name
  end
  return list
end

describe("Search.Parse", function()
  it("reads ! before &, & before |, and ( ) first", function()
    local tree = Search.Parse("!a & b | c")
    assert.are.equal("or", tree.op)
    assert.are.equal("and", tree[1].op)
    assert.are.equal("not", tree[1][1].op)
    assert.are.equal("c", tree[2].term)
    assert.are.equal("and", Search.Parse("a & (b | c)").op)
    assert.are.equal("linen cloth", Search.Parse("  Linen Cloth ").term)
  end)

  it("is nil until the search is whole", function()
    assert.is_nil(Search.Parse(""))
    assert.is_nil(Search.Parse("linen &"))
    assert.is_nil(Search.Parse("(linen"))
    assert.is_nil(Search.Parse("linen)"))
    assert.is_nil(Search.Parse("!"))
  end)
end)

describe("Search.Run", function()
  it("finds an item by name on every alt, with how many and where", function()
    local result = Search.Run(characters, "linen", info, 10)
    assert.are.same({ "Linen Cloth" }, names(result))
    local item = result.items[1]
    assert.are.equal(50, item.total)
    assert.are.equal("Quill-Nightfall", item.alts[1].key, "most first")
    assert.are.equal("20 bags, 10 mail", Search.Places(item.alts[1]))
    assert.are.equal("15 bags, 5 bank", Search.Places(item.alts[2]))
    assert.are.equal("bags", Search.Tab(item.alts[2]))
    assert.are.equal(LINEN, item.link)
  end)

  it("matches keywords, with # for a keyword only", function()
    assert.are.same({ "Sword" }, names(Search.Run(characters, "#epic", info, 10)))
    assert.are.same({ "Silk Robe", "Sword" }, names(Search.Run(characters, "#gear", info, 10)))
    assert.are.same({ "Silk Robe" }, names(Search.Run(characters, "cloth & #armor", info, 10)))
    assert.are.same({ "Sword" }, names(Search.Run(characters, "#boe & #onehand", info, 10)))
    assert.are.same({}, names(Search.Run(characters, "#sword", info, 10)), "a name isn't a keyword")
  end)

  it("matches where an item is", function()
    assert.are.same({ "Linen Cloth" }, names(Search.Run(characters, "#bank", info, 10)))
    assert.are.same({ "Silk Robe" }, names(Search.Run(characters, "#equipped", info, 10)))
    local mailbox = Search.Run(characters, "#mailbox", info, 10)
    assert.are.same({ "Linen Cloth", "Sword" }, names(mailbox), "sent mail counts until it would go back")
    local robe = Search.Run(characters, "robe", info, 10).items[1]
    assert.are.equal(1, robe.total, "the robe mailed earlier has gone back")
    assert.are.equal("gear", Search.Tab(robe.alts[1]))
    local away = Search.Run(characters, "!#bags & !#equipped & !#bank & !linen", info, 10)
    assert.are.same({ "Sword" }, names(away))
  end)

  it("matches item levels", function()
    assert.are.same({ "Sword" }, names(Search.Run(characters, ">30", info, 10)))
    assert.are.same({ "Linen Cloth" }, names(Search.Run(characters, "<10", info, 10)))
    assert.are.same({ "Silk Robe" }, names(Search.Run(characters, "20-30", info, 10)))
    assert.are.same({ "Silk Robe" }, names(Search.Run(characters, "25", info, 10)))
    assert.are.same({ "Silk Robe", "Sword" }, names(Search.Run(characters, "#gear & >20", info, 10)))
  end)

  it("reads the name and quality from the link while the item hasn't loaded", function()
    local result = Search.Run(characters, "#epic", function()
      return {}
    end, 10)
    assert.are.same({ "Sword" }, names(result))
    assert.are.equal(4, result.items[1].quality)
  end)

  it("is nil while the search isn't whole, and counts what it doesn't show", function()
    assert.is_nil(Search.Run(characters, "linen |", info, 10))
    local many = { bags = { items = {} } }
    for i = 1, Search.MAX_ITEMS + 5 do
      many.bags.items[i] = { link = link(1000 + i, "Ore " .. i), count = 1 }
    end
    local result = Search.Run({ A = many }, "ore", info, 10)
    assert.are.equal(Search.MAX_ITEMS, #result.items)
    assert.are.equal(5, result.more)
  end)
end)
