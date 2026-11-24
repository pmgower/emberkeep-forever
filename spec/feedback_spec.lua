local Feedback = dofile("Kinfolk/Core/Feedback.lua")

local function ctx()
  return {
    version = "0.1.0",
    client = { version = "1.60.1", build = "60000", date = "Nov 1 2026", interface = 16001, locale = "enUS" },
    character = {
      level = 23,
      race = "Orc",
      class = "HUNTER",
      faction = "Horde",
      realm = "Forever",
      maxLevel = 60,
    },
    rest = { rested = 1390, xpMax = 29400, resting = false },
    wellRested = 2,
    settings = { hideSurnames = false, loginHint = true, theme = "frost", window = { size = { 1, 2 } } },
    saved = 4,
    atMax = 1,
    alts = {
      { level = "25", class = "WARLOCK", percent = 150, full = true, resting = true },
      { level = "21", class = "MAGE", percent = 31, full = false, resting = false },
    },
    addons = { BugSack = true, MapUtils = false },
    errors = {},
  }
end

describe("Feedback.Report", function()
  it("lists the client, character, rest, settings, alts and addons, one fact per line", function()
    local report = Feedback.Report(ctx())
    assert.are.equal(
      table.concat({
        "Kinfolk feedback report",
        "Addon: 0.1.0",
        "Client: 1.60.1 build 60000 (Nov 1 2026), interface 16001, locale enUS",
        "Character: level 23 Orc HUNTER, Horde, realm Forever, max level 60",
        "Rested: 1390 of 29400 XP, not resting",
        "Well Rested: 2 / 5",
        "Settings: hideSurnames=off loginHint=on theme=frost",
        "Alts saved: 4 (2 levelling, 1 at max)",
        "  1: level 25 WARLOCK, 150% (full), inn",
        "  2: level 21 MAGE, 31%, outside",
        "Other addons: BugSack loaded, MapUtils not loaded",
        "Errors this session: none",
      }, "\n"),
      report
    )
  end)

  it("never includes a character name", function()
    local c = ctx()
    c.alts[1].name = "Pheumageddon"
    c.alts[1].key = "Pheumageddon Doombringer-Forever"
    assert.is_nil(Feedback.Report(c):find("Pheumageddon"))
  end)

  it("lists errors and copes with missing facts", function()
    local report = Feedback.Report({ errors = { "boom", "bang" } })
    assert.truthy(report:find("Errors this session: 2\n  boom\n  bang", 1, true))
    assert.truthy(report:find("Rested: no reading", 1, true))
    assert.truthy(report:find("Addon: ?", 1, true))
  end)

  it("caps a long alt list", function()
    local c = ctx()
    c.alts = {}
    for i = 1, 25 do
      c.alts[i] = { level = "10", class = "ROGUE", percent = i, resting = true }
    end
    assert.truthy(Feedback.Report(c):find("...and 5 more", 1, true))
  end)
end)

describe("Feedback errors", function()
  it("knows Kinfolk's errors from other addons'", function()
    assert.is_true(Feedback.IsOurs("Interface/AddOns/Kinfolk/App.lua:12: boom"))
    assert.is_true(Feedback.IsOurs("boom", "Interface\\AddOns\\Kinfolk\\UI\\MainWindow.lua:40"))
    assert.is_false(
      Feedback.IsOurs("Interface/AddOns/BagQuests/App.lua:1: x", "Interface/AddOns/Kinfolkish/a.lua")
    )
  end)

  it("keeps our stack lines only, and cuts long errors", function()
    local stack = "Interface/AddOns/Other/x.lua:1\nInterface/AddOns/Kinfolk/App.lua:9: in function"
    assert.are.equal(
      "boom\n  Interface/AddOns/Kinfolk/App.lua:9: in function",
      Feedback.ShortError("boom", stack)
    )
    local long = Feedback.ShortError(string.rep("x", 900))
    assert.are.equal(Feedback.MAX_ERROR_LEN + 3, #long)
  end)

  it("remembers the last few errors", function()
    local errors = {}
    for i = 1, 7 do
      Feedback.Remember(errors, "e" .. i)
    end
    assert.are.same({ "e3", "e4", "e5", "e6", "e7" }, errors)
  end)
end)

describe("Feedback.IssueUrl", function()
  it("prefills the bug form's report box and the body", function()
    local url, prefilled = Feedback.IssueUrl("a b\nc")
    assert.is_true(prefilled)
    assert.are.equal(
      Feedback.BUG_FORM_URL .. "&feedback=a%20b%0Ac&body=%60%60%60%0Aa%20b%0Ac%0A%60%60%60",
      url
    )
  end)

  it("drops the body, then the prefill, as the report gets too long for a link", function()
    local mid = string.rep("x", 4000)
    local url, prefilled = Feedback.IssueUrl(mid)
    assert.is_true(prefilled)
    assert.is_nil(url:find("&body=", 1, true))
    local url2, prefilled2 = Feedback.IssueUrl(string.rep("x", 8000))
    assert.is_false(prefilled2)
    assert.are.equal(Feedback.BUG_FORM_URL, url2)
  end)
end)
