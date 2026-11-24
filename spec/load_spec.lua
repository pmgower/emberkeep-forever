-- Smoke test: the whole addon loads in TOC order against a stand-in WoW API,
-- saves the character on login, and the window and commands run without errors.
local wow = dofile("spec/support/wow.lua")

describe("the addon in a stand-in client", function()
  local state, ns

  before_each(function()
    state = {
      version = "0.1.0",
      name = "Brakka",
      realm = "Nightfall",
      level = 34,
      money = 421800,
      zone = "Orgrimmar",
      now = 1000,
      xpMax = 10000,
      rested = 2500,
      resting = true,
    }
    _G.KinfolkDB = nil
    wow.install(state)
    ns = wow.loadToc("Kinfolk/Kinfolk.toc", "Kinfolk")
    wow.fire("ADDON_LOADED", "Kinfolk")
    wow.fire("PLAYER_LOGIN")
  end)

  it("saves the logged-in character", function()
    local c = KinfolkDB.characters["Brakka-Nightfall"]
    assert.are.equal(34, c.level)
    assert.are.equal("Orgrimmar", c.zone)
    assert.are.equal("v0.1.0", ns.versionText)
  end)

  it("saves the character's rested XP, and keeps it when logout reads XP to level as 0", function()
    local r = KinfolkDB.characters["Brakka-Nightfall"].rest
    assert.are.same({ rested = 2500, xpMax = 10000, resting = true, wellRested = 0, at = 1000 }, r)
    state.xpMax, state.rested = 0, nil
    wow.fire("PLAYER_LOGOUT")
    assert.are.equal(2500, KinfolkDB.characters["Brakka-Nightfall"].rest.rested)
  end)

  it("says who to play next on login, skipping the character you're on", function()
    -- You're on Brakka, who is full; Quill is next at 60%.
    KinfolkDB.characters["Brakka-Nightfall"].rest.rested = 15000
    local partly = { rested = 6000, xpMax = 10000, resting = true, wellRested = 0, at = 1000 }
    KinfolkDB.characters["Quill-Nightfall"] =
      { name = "Quill", realm = "Nightfall", level = 18, rest = partly }
    state.rested = 15000
    wow.fire("PLAYER_ENTERING_WORLD", true, false)
    local last = DEFAULT_CHAT_FRAME.lines[#DEFAULT_CHAT_FRAME.lines]
    assert.truthy(last and last:find("play next Quill (60% rested)", 1, true), tostring(last))
    local count = #DEFAULT_CHAT_FRAME.lines
    wow.fire("PLAYER_ENTERING_WORLD", false, true) -- a /reload doesn't repeat it
    wow.fire("PLAYER_ENTERING_WORLD", false, false) -- nor does zoning
    assert.are.equal(count, #DEFAULT_CHAT_FRAME.lines)
  end)

  it("opens on the Rested tab with each alt's rested percent", function()
    SlashCmdList.KINFOLK("")
    local seen = {}
    for _, f in ipairs(wow.frames) do
      if f._text then
        seen[tostring(f._text)] = true
      end
    end
    assert.is_true(seen["25%"], "Brakka's 25% rested should be drawn")
    -- Hovering each row builds its tooltip without an error, full or not.
    KinfolkDB.characters["Brakka-Nightfall"].rest.rested = 15000
    local hovered = 0
    for _, f in ipairs(wow.frames) do
      if f.key and f._scripts.OnEnter then
        f._scripts.OnEnter(f)
        hovered = hovered + 1
      end
    end
    assert.is_true(hovered > 0)
  end)

  it("names who to play next in the minimap tooltip, not the character you're on", function()
    KinfolkDB.characters["Brakka-Nightfall"].rest.rested = 15000
    local partly = { rested = 6000, xpMax = 10000, resting = true, wellRested = 0, at = 1000 }
    KinfolkDB.characters["Quill-Nightfall"] =
      { name = "Quill", realm = "Nightfall", level = 18, rest = partly }
    local lines = ns.MinimapButton.TooltipLines(KinfolkDB, 1000)
    assert.truthy(lines[2]:find("Play next: Quill", 1, true), lines[2])
    assert.truthy(lines[3]:find("1 alt full, 1 still resting", 1, true), lines[3])
  end)

  it("doesn't save a rested reading on level-up, when XP to level can be stale", function()
    state.xpMax, state.rested = 12000, 9999
    wow.fire("PLAYER_LEVEL_UP", 35)
    assert.are.equal(10000, KinfolkDB.characters["Brakka-Nightfall"].rest.xpMax)
  end)

  it("reads the account's Well Rested rank from whichever Generic tree has it", function()
    _G.Enum = { TraitConfigType = { Generic = 3 } }
    _G.C_Traits = {
      GetConfigsByType = function()
        return { 11, 22 } -- Skyriding first, Legacy second
      end,
      GetNodeInfo = function(config, node)
        if config == 22 then
          return { ID = node, currentRank = 3 }
        end
        return { ID = 0, currentRank = 0 }
      end,
    }
    wow.fire("TRAIT_CONFIG_UPDATED")
    _G.C_Traits, _G.Enum = nil, nil
    assert.are.equal(3, KinfolkDB.wellRested)
    assert.are.equal(3, KinfolkDB.characters["Brakka-Nightfall"].rest.wellRested)
  end)

  it("saves the character when the game reports no realm name, as WoW Forever does", function()
    state.realm = ""
    KinfolkDB.characters = {}
    wow.fire("PLAYER_LOGIN")
    local c = KinfolkDB.characters["Brakka-Forever"]
    assert.is_not_nil(c, "the character should be saved under the fallback realm")
    assert.are.equal(34, c.level)
    assert.is_not_nil(c.rest)
  end)

  it("saves the surname, keys by full name, and moves an entry saved without it", function()
    local old = KinfolkDB.characters["Brakka-Nightfall"]
    state.surname = "Stonefist"
    wow.fire("PLAYER_LOGIN")
    assert.is_nil(KinfolkDB.characters["Brakka-Nightfall"])
    local c = KinfolkDB.characters["Brakka Stonefist-Nightfall"]
    assert.are.equal(old, c, "the earlier entry should move, not be duplicated")
    assert.are.equal("Stonefist", c.surname)
  end)

  it("shows full names, or first names only when that option is on", function()
    state.surname = "Stonefist"
    wow.fire("PLAYER_LOGIN")
    local function drawn(text)
      for _, f in ipairs(wow.frames) do
        if f._text and tostring(f._text):find(text, 1, true) then
          return true
        end
      end
      return false
    end
    SlashCmdList.KINFOLK("")
    assert.is_true(drawn("Brakka Stonefist"))
    wow.settings.controls[3]:SetValue(true) -- First names only
    for _, f in ipairs(wow.frames) do
      if f._text and tostring(f._text):find("Brakka Stonefist", 1, true) then
        f._text = nil -- clear what the first draw left behind
      end
    end
    ns.MainWindow.Render()
    assert.is_false(drawn("Brakka Stonefist"))
    assert.is_true(drawn("Brakka"))
  end)

  it("puts the account's gold total on its own row with no character name", function()
    KinfolkDB.characters["Quill-Nightfall"] =
      { name = "Quill", realm = "Nightfall", level = 18, money = 10000 }
    KinfolkDB.settings.focus = "overview"
    SlashCmdList.KINFOLK("")
    local total = false
    for _, f in ipairs(wow.frames) do
      if f._text and tostring(f._text):find("All characters", 1, true) then
        total = true
      end
      if f._text and tostring(f._text):find("alts", 1, true) then
        assert.is_nil(tostring(f._text):find("g", 1, true) and tostring(f._text):find("|cffffd100", 1, true))
      end
    end
    assert.is_true(total)
  end)

  it("keeps saved data when logout reads come back empty", function()
    state.level, state.money, state.zone = 0, 0, ""
    wow.fire("PLAYER_LOGOUT")
    local c = KinfolkDB.characters["Brakka-Nightfall"]
    assert.are.equal(34, c.level)
    assert.are.equal(421800, c.money)
  end)

  it("opens and closes the window with /kinfolk, and refreshes it while open", function()
    assert.is_false(ns.MainWindow.IsShown())
    KinfolkDB.settings.focus = "overview" -- the gold column is on Overview
    SlashCmdList.KINFOLK("")
    assert.is_true(ns.MainWindow.IsShown())
    state.money = 12345678
    wow.fire("PLAYER_MONEY")
    local seen = false
    for _, f in ipairs(wow.frames) do
      if f._text and tostring(f._text):find("1,234g", 1, true) then
        seen = true
      end
    end
    assert.is_true(seen, "the new gold total should be drawn in the open window")
    SlashCmdList.KINFOLK("")
    assert.is_false(ns.MainWindow.IsShown())
  end)

  it("saves the new level from PLAYER_LEVEL_UP even if the game still reports the old one", function()
    wow.fire("PLAYER_LEVEL_UP", 35)
    assert.are.equal(35, KinfolkDB.characters["Brakka-Nightfall"].level)
  end)

  it("does not save a value the client hides from addons", function()
    state.zone = "Hidden"
    state.secret = "Hidden"
    wow.fire("ZONE_CHANGED_NEW_AREA")
    assert.are.equal("Orgrimmar", KinfolkDB.characters["Brakka-Nightfall"].zone)
  end)

  it("shows the minimap button and hides it when the option is off", function()
    local button = wow.icons.Kinfolk
    assert.is_true(button.shown)
    KinfolkDB.settings.minimapButton = false
    ns.MinimapButton.Apply(KinfolkDB)
    assert.is_false(button.shown)
    assert.is_true(button.db.hide)
  end)

  it("opens the window from a minimap left-click", function()
    wow.icons.Kinfolk.obj.OnClick(nil, "LeftButton")
    assert.is_true(ns.MainWindow.IsShown())
  end)

  it("builds the options page and applies a changed color scheme and scale", function()
    assert.are.equal("Kinfolk", wow.settings.name)
    assert.are.equal(7, #wow.settings.controls) -- 4 checkboxes, scheme, scale, character
    SlashCmdList.KINFOLK("")
    local theme = wow.settings.controls[5]
    theme:SetValue("twilight")
    assert.are.equal("twilight", ns.Window.Current().key)
    wow.settings.controls[6]:SetValue(1.5)
    local scaled
    for _, f in ipairs(wow.frames) do
      if f._scale == 1.5 then
        scaled = f
      end
    end
    assert.is_not_nil(scaled, "the window should take the new scale")
    -- Centre 600,400 at scale 1 is 400,266.7 at scale 1.5: same spot on screen.
    assert.are.equal("CENTER", scaled._point[1])
    assert.are.equal(400, scaled._point[4])
    wow.fire("PLAYER_MONEY")
    SlashCmdList.KINFOLK("options")
    assert.are.equal(7, wow.settings.opened)
  end)

  it("forgets a character picked on the options page", function()
    KinfolkDB.characters["Quill-Nightfall"] = { name = "Quill", realm = "Nightfall", level = 18 }
    local picker = wow.settings.controls[7]
    local names = {}
    for _, o in ipairs(picker.options()) do
      names[#names + 1] = o.value
    end
    assert.are.same({ "Brakka-Nightfall", "Quill-Nightfall" }, names)
    picker:SetValue("Quill-Nightfall")
    wow.settings.buttons[1].onClick()
    assert.is_nil(KinfolkDB.characters["Quill-Nightfall"])
    assert.are.equal("", picker.tbl.forget, "the picker should clear after a forget")
  end)

  it("won't forget the logged-in character from the options page", function()
    local picker = wow.settings.controls[7]
    picker:SetValue("Brakka-Nightfall")
    wow.settings.buttons[1].onClick()
    assert.is_not_nil(KinfolkDB.characters["Brakka-Nightfall"])
  end)

  it("won't forget the character you're logged in on", function()
    SlashCmdList.KINFOLK("forget Brakka")
    assert.is_not_nil(KinfolkDB.characters["Brakka-Nightfall"])
  end)

  it("answers version, forget and reset", function()
    KinfolkDB.characters["Quill-Nightfall"] = { name = "Quill", realm = "Nightfall", level = 18 }
    SlashCmdList.KINFOLK("")
    SlashCmdList.KINFOLK("version")
    SlashCmdList.KINFOLK("forget quill")
    SlashCmdList.KINFOLK("reset")
    SlashCmdList.KINFOLK("nonsense")
    local lines = DEFAULT_CHAT_FRAME.lines
    assert.truthy(lines[1]:find("Kinfolk:|r version 0.1.0", 1, true), lines[1])
    assert.truthy(lines[2]:find("forgot 1", 1, true))
    assert.is_nil(KinfolkDB.characters["Quill-Nightfall"])
  end)
end)
