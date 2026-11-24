local Roster = dofile("Emberkeep/Core/Roster.lua")

local function sighting(over)
  local s = {
    name = "Brakka",
    realm = "Nightfall",
    class = "Warrior",
    classFile = "WARRIOR",
    race = "Orc",
    faction = "Horde",
    level = 34,
    money = 421800,
    zone = "Orgrimmar",
  }
  for k, v in pairs(over or {}) do
    s[k] = v
  end
  return s
end

describe("Roster.Observe", function()
  it("saves a character under Name-Realm", function()
    local store = {}
    local key = Roster.Observe(store, sighting(), 1000)
    assert.are.equal("Brakka-Nightfall", key)
    assert.are.equal(34, store[key].level)
    assert.are.equal(421800, store[key].money)
    assert.are.equal(1000, store[key].lastSeen)
  end)

  it("keeps the last good values when a read comes back empty", function()
    local store = {}
    Roster.Observe(store, sighting(), 1000)
    Roster.Observe(store, sighting({ level = 0, money = false, zone = "", class = nil }), 2000)
    local c = store["Brakka-Nightfall"]
    assert.are.equal(34, c.level)
    assert.are.equal(421800, c.money)
    assert.are.equal("Orgrimmar", c.zone)
    assert.are.equal("Warrior", c.class)
    assert.are.equal(2000, c.lastSeen)
  end)

  it("keeps the subzone with the zone, and clears it on a new zone without one", function()
    local store = {}
    Roster.Observe(store, sighting({ subzone = "Valley of Strength" }), 1)
    local c = store["Brakka-Nightfall"]
    assert.are.equal("Valley of Strength", c.subzone)
    Roster.Observe(store, sighting({ zone = "", subzone = "" }), 2) -- logout read
    assert.are.equal("Valley of Strength", c.subzone)
    Roster.Observe(store, sighting({ zone = "Durotar", subzone = "" }), 3)
    assert.is_nil(c.subzone)
  end)

  it("ignores zero gold read while logging out, but not at other times", function()
    local store = {}
    Roster.Observe(store, sighting(), 1)
    Roster.Observe(store, sighting({ money = 0, level = 0 }), 2, { loggingOut = true })
    assert.are.equal(421800, store["Brakka-Nightfall"].money)
    assert.are.equal(34, store["Brakka-Nightfall"].level)
    Roster.Observe(store, sighting({ money = 0 }), 3)
    assert.are.equal(0, store["Brakka-Nightfall"].money)
  end)

  it("ignores a sighting with no name or realm", function()
    local store = {}
    assert.is_nil(Roster.Observe(store, sighting({ name = "" }), 1))
    local noRealm = sighting()
    noRealm.realm = nil
    assert.is_nil(Roster.Observe(store, noRealm, 1))
    assert.are.same({}, store)
  end)

  it("updates level and gold as they change", function()
    local store = {}
    Roster.Observe(store, sighting(), 1)
    Roster.Observe(store, sighting({ level = 35, money = 0 }), 2)
    assert.are.equal(35, store["Brakka-Nightfall"].level)
    assert.are.equal(0, store["Brakka-Nightfall"].money)
  end)
end)

describe("Roster.Forget", function()
  it("removes a name on every realm, ignoring case", function()
    local store = {}
    Roster.Observe(store, sighting(), 1)
    Roster.Observe(store, sighting({ realm = "Other" }), 1)
    Roster.Observe(store, sighting({ name = "Quill" }), 1)
    assert.are.equal(2, Roster.Forget(store, "brakka"))
    assert.is_nil(store["Brakka-Nightfall"])
    assert.is_not_nil(store["Quill-Nightfall"])
  end)
end)

describe("Roster.ForgetKey", function()
  it("removes only that realm's character", function()
    local store = {}
    Roster.Observe(store, sighting(), 1)
    Roster.Observe(store, sighting({ realm = "Other" }), 1)
    assert.is_true(Roster.ForgetKey(store, "Brakka-Other"))
    assert.is_false(Roster.ForgetKey(store, "Brakka-Other"))
    assert.is_not_nil(store["Brakka-Nightfall"])
  end)
end)

describe("Roster.Characters", function()
  it("lists highest level first, then by name", function()
    local store = {}
    Roster.Observe(store, sighting({ name = "Quill", level = 18 }), 1)
    Roster.Observe(store, sighting({ name = "Elowen", level = 41 }), 1)
    Roster.Observe(store, sighting({ name = "Aldo", level = 18 }), 1)
    local names = {}
    for _, c in ipairs(Roster.Characters(store)) do
      names[#names + 1] = c.name
    end
    assert.are.same({ "Elowen", "Aldo", "Quill" }, names)
  end)

  it("returns copies, so the saved records stay as they were", function()
    local store = {}
    Roster.Observe(store, sighting(), 1)
    local list = Roster.Characters(store)
    assert.are.equal("Brakka-Nightfall", list[1].key)
    list[1].level = 99
    assert.is_nil(store["Brakka-Nightfall"].key)
    assert.are.equal(34, store["Brakka-Nightfall"].level)
  end)
end)

describe("Roster surnames", function()
  it("keys by full name and shows it, or the first name only", function()
    assert.are.equal("Jango Fett-Forever", Roster.Key("Jango", "Forever", "Fett"))
    assert.are.equal("Jango-Forever", Roster.Key("Jango", "Forever"))
    local c = { name = "Jango", surname = "Fett" }
    assert.are.equal("Jango Fett", Roster.DisplayName(c))
    assert.are.equal("Jango", Roster.DisplayName(c, true))
    assert.are.equal("Quill", Roster.DisplayName({ name = "Quill" }))
  end)

  it("keeps two alts with the same first name apart", function()
    local store = {}
    Roster.Observe(store, { name = "Jango", surname = "Fett", realm = "Forever" }, 1)
    Roster.Observe(store, { name = "Jango", surname = "Reyes", realm = "Forever" }, 1)
    assert.is_not_nil(store["Jango Fett-Forever"])
    assert.is_not_nil(store["Jango Reyes-Forever"])
  end)

  it("forgets by full name too", function()
    local store = {}
    Roster.Observe(store, { name = "Jango", surname = "Fett", realm = "Forever" }, 1)
    assert.are.equal(1, Roster.Forget(store, "jango fett"))
  end)
end)
