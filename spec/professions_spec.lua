local Professions = dofile("Emberkeep/Core/Professions.lua")
local Roster = dofile("Emberkeep/Core/Roster.lua")

local function prof(line, name, skill, max)
  return { line = line, name = name, skill = skill, max = max }
end

local function alt(name, level, list)
  local c = { name = name, realm = "Nightfall", level = level }
  if list then
    Professions.Observe(c, { list = list }, 500)
  end
  return c
end

local function store()
  return {
    a = alt("Brakka", 34, { prof(186, "Mining", 120, 150), prof(185, "Cooking", 40, 75) }),
    b = alt("Quill", 18, { prof(186, "Mining", 60, 75), prof(356, "Fishing", 12, 75) }),
    c = alt("Saelra", 12),
  }
end

local function names(rows)
  local out = {}
  for i, r in ipairs(rows) do
    out[i] = r.name
  end
  return out
end

describe("Professions.Observe", function()
  it("saves each skill under its column with the time", function()
    local c = alt("Brakka", 34, { prof(186, "Mining", 120, 150) })
    assert.are.same({ Mining = { name = "Mining", skill = 120, max = 150 } }, c.professions.skills)
    assert.are.equal(500, c.professions.at)
  end)

  it("ignores an empty or partial reading, so it never wipes what was saved", function()
    local c = alt("Brakka", 34, { prof(186, "Mining", 120, 150) })
    assert.is_false(Professions.Observe(c, { list = {} }, 900))
    assert.is_false(Professions.Observe(c, { list = { prof(185, "Cooking", 1, 75) }, unread = true }, 900))
    assert.is_false(Professions.Observe(c, nil, 900))
    assert.are.equal(120, c.professions.skills.Mining.skill)
  end)

  it("saves none for a character who has none, once the game has settled", function()
    local c = {}
    assert.is_false(Professions.Observe(c, { list = {} }, 900, false))
    assert.is_nil(c.professions)
    assert.is_true(Professions.Observe(c, { list = {} }, 901, true))
    assert.are.same({ skills = {}, at = 901 }, c.professions)
    local had = alt("Brakka", 34, { prof(186, "Mining", 120, 150) })
    assert.is_false(Professions.Observe(had, { list = {} }, 902, true))
    assert.are.equal(120, had.professions.skills.Mining.skill)
  end)

  it("says whether anything changed", function()
    local c = alt("Brakka", 34, { prof(186, "Mining", 120, 150) })
    assert.is_false(Professions.Observe(c, { list = { prof(186, "Mining", 120, 150) } }, 900))
    assert.are.equal(900, c.professions.at)
    assert.is_true(Professions.Observe(c, { list = { prof(186, "Mining", 121, 150) } }, 901))
    assert.is_true(Professions.Observe(c, { list = { prof(185, "Cooking", 1, 75) } }, 902))
  end)

  it("drops a profession that was unlearned", function()
    local c = alt("Brakka", 34, { prof(186, "Mining", 120, 150), prof(185, "Cooking", 40, 75) })
    Professions.Observe(c, { list = { prof(185, "Cooking", 41, 75) } }, 900)
    assert.is_nil(c.professions.skills.Mining)
    assert.are.equal(41, c.professions.skills.Cooking.skill)
  end)

  it("finds the column by skill line in any language, or by name", function()
    assert.are.equal("Mining", Professions.Key(186, "Bergbau"))
    assert.are.equal("Mining", Professions.Key(2575, "Mining"))
    assert.are.equal("Jewelcrafting", Professions.Key(755, "Jewelcrafting"))
  end)
end)

describe("Professions.Columns", function()
  it("has every standard profession and marks the ones nobody has", function()
    local columns = Professions.Columns(Roster.Characters(store()))
    assert.are.equal(12, #columns)
    local missing = {}
    for _, c in ipairs(columns) do
      missing[c.key] = c.missing
    end
    assert.is_true(missing.Alchemy)
    assert.is_false(missing.Mining)
    assert.is_false(missing.Fishing)
  end)

  it("adds a column for any other profession, and uses the game's names", function()
    local c = alt("Quill", 18, { prof(755, "Jewelcrafting", 5, 75), prof(186, "Bergbau", 9, 75) })
    local columns = Professions.Columns({ c })
    assert.are.equal(13, #columns)
    assert.are.equal("Jewelcrafting", columns[13].title)
    assert.are.equal("Jewelcrafting", columns[13].short)
    assert.are.equal("Leather", columns[6].short)
    assert.are.equal("Bergbau", columns[7].short, "only English names are shortened")
    assert.are.equal("Bergbau", columns[7].title)
    assert.are.equal("Mining", columns[7].key)
  end)
end)

describe("Professions.Build", function()
  it("lists characters by level, with no skills for one never read", function()
    local _, rows = Professions.Build(store(), Roster)
    assert.are.same({ "Brakka", "Quill", "Saelra" }, names(rows))
    assert.are.equal("120/150", Professions.Text(rows[1].skills.Mining))
    assert.is_nil(rows[3].skills)
  end)

  it("sorts by a column both ways, with those who don't have it last", function()
    local s = store()
    local function sorted(key, ascending)
      local _, rows = Professions.Build(s, Roster, { sort = { key = key, ascending = ascending } })
      return names(rows)
    end
    assert.are.same({ "Brakka", "Quill", "Saelra" }, sorted("Mining", false))
    assert.are.same({ "Quill", "Brakka", "Saelra" }, sorted("Mining", true))
    assert.are.same({ "Quill", "Brakka", "Saelra" }, sorted("Fishing", false))
  end)
end)

describe("Professions.NextSort", function()
  it("goes highest, lowest, then back to by level, and starts over on another column", function()
    local first = Professions.NextSort(nil, "Mining")
    assert.are.same({ key = "Mining", ascending = false }, first)
    local second = Professions.NextSort(first, "Mining")
    assert.are.same({ key = "Mining", ascending = true }, second)
    assert.is_nil(Professions.NextSort(second, "Mining"))
    assert.are.same({ key = "Fishing", ascending = false }, Professions.NextSort(second, "Fishing"))
  end)
end)

describe("Professions.Text", function()
  it("shows the skill and its limit, when there is one", function()
    assert.are.equal("142/150", Professions.Text({ skill = 142, max = 150 }))
    assert.are.equal("142", Professions.Text({ skill = 142 }))
  end)
end)
