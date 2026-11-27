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
      subzone = "Valley of Strength",
      now = 1000,
      xpMax = 10000,
      rested = 2500,
      resting = true,
    }
    _G.EmberkeepDB = nil
    wow.install(state)
    ns = wow.loadToc("Emberkeep/Emberkeep.toc", "Emberkeep")
    wow.fire("ADDON_LOADED", "Emberkeep")
    wow.fire("PLAYER_LOGIN")
  end)

  it("saves the logged-in character", function()
    local c = EmberkeepDB.characters["Brakka-Nightfall"]
    assert.are.equal(34, c.level)
    assert.are.equal("Orgrimmar", c.zone)
    assert.are.equal("Valley of Strength", c.subzone)
    assert.are.equal("v0.1.0", ns.versionText)
  end)

  it("saves the character's rested XP, and keeps it when logout reads XP to level as 0", function()
    local r = EmberkeepDB.characters["Brakka-Nightfall"].rest
    assert.are.same({ rested = 2500, xpMax = 10000, resting = true, at = 1000 }, r)
    state.xpMax, state.rested = 0, nil
    wow.fire("PLAYER_LOGOUT")
    assert.are.equal(2500, EmberkeepDB.characters["Brakka-Nightfall"].rest.rested)
  end)

  it("says who to play next on login, skipping the character you're on", function()
    -- You're on Brakka, who is full; Quill is next at 60%.
    EmberkeepDB.characters["Brakka-Nightfall"].rest.rested = 15000
    local partly = { rested = 6000, xpMax = 10000, resting = true, at = 1000 }
    EmberkeepDB.characters["Quill-Nightfall"] =
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
    SlashCmdList.EMBERKEEP("")
    local seen = {}
    for _, f in ipairs(wow.frames) do
      if f._text then
        seen[tostring(f._text)] = true
      end
    end
    assert.is_true(seen["25.0%"], "Brakka's 25% rested should be drawn")
    -- Hovering each row builds its tooltip without an error, full or not.
    EmberkeepDB.characters["Brakka-Nightfall"].rest.rested = 15000
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
    EmberkeepDB.characters["Brakka-Nightfall"].rest.rested = 15000
    local partly = { rested = 6000, xpMax = 10000, resting = true, at = 1000 }
    EmberkeepDB.characters["Quill-Nightfall"] =
      { name = "Quill", realm = "Nightfall", level = 18, rest = partly }
    local lines = ns.MinimapButton.TooltipLines(EmberkeepDB, 1000)
    assert.truthy(lines[2]:find("Play next: Quill", 1, true), lines[2])
    assert.truthy(lines[3]:find("1 alt full, 1 still resting", 1, true), lines[3])
  end)

  it("doesn't save a rested reading on level-up, when XP to level can be stale", function()
    state.xpMax, state.rested = 12000, 9999
    wow.fire("PLAYER_LEVEL_UP", 35)
    assert.are.equal(10000, EmberkeepDB.characters["Brakka-Nightfall"].rest.xpMax)
  end)

  it("reads the character's own Well Rested rank from whichever Generic tree has it", function()
    _G.Enum = { TraitConfigType = { Generic = 3 } }
    _G.C_Traits = {
      GetConfigsByType = function()
        return { 11, 22 } -- Skyriding first, Legacy second
      end,
      GetNodeInfo = function(config, node)
        if config == 22 then
          return { ID = node, activeRank = 3, currentRank = 5 } -- 2 points not applied
        end
        return { ID = 0, currentRank = 0 }
      end,
    }
    local partly = { rested = 6000, xpMax = 10000, resting = true, at = 1000 }
    EmberkeepDB.characters["Quill-Nightfall"] =
      { name = "Quill", realm = "Nightfall", level = 18, rest = partly, wellRested = 1 }
    EmberkeepDB.characters["Morvain-Nightfall"] =
      { name = "Morvain", realm = "Nightfall", level = 12, rest = partly }
    wow.fire("TRAIT_CONFIG_UPDATED")
    _G.C_Traits, _G.Enum = nil, nil
    assert.are.equal(3, EmberkeepDB.characters["Brakka-Nightfall"].wellRested)
    assert.are.equal(1, EmberkeepDB.characters["Quill-Nightfall"].wellRested, "another alt keeps its own")
    assert.is_nil(EmberkeepDB.wellRested)
    EmberkeepDB.settings.focus = "rested"
    SlashCmdList.EMBERKEEP("")
    local drawn = {}
    for _, f in ipairs(wow.frames) do
      drawn[tostring(f._text)] = true
    end
    assert.is_true(drawn["3 / 5"])
    assert.is_true(drawn["1 / 5"])
    assert.is_true(drawn["|cff8f98a5Not read yet|r"])
    local function shownPips()
      local n = 0
      for _, f in ipairs(wow.frames) do
        if rawget(f, "pip") and f._shown then
          n = n + 1
        end
      end
      return n
    end
    assert.are.equal(10, shownPips(), "five each for the two alts with a rank")
    for _, f in ipairs(wow.frames) do
      if rawget(f, "label") and f.label._text == "Overview" then
        f._scripts.OnClick(f)
      end
    end
    assert.are.equal(0, shownPips())
  end)

  it("reads the rank a moment after entering the world, and not while leaving it", function()
    local rank, later = 0, {}
    _G.C_Traits = {
      GetConfigsByType = function()
        return { 22 }
      end,
      GetNodeInfo = function(_, node)
        return { ID = node, currentRank = rank }
      end,
    }
    _G.C_Timer = {
      After = function(delay, fn)
        later[#later + 1] = { delay = delay, fn = fn }
      end,
    }
    local c = EmberkeepDB.characters["Brakka-Nightfall"]
    c.wellRested = 4
    local function runRankTimers()
      local due = later
      later = {}
      for _, t in ipairs(due) do
        if t.delay == 3 then
          pcall(t.fn)
        end
      end
    end
    wow.fire("PLAYER_ENTERING_WORLD", true, false)
    assert.are.equal(4, c.wellRested, "a 0 from trees that aren't loaded is never saved")
    rank = 2
    runRankTimers()
    assert.are.equal(2, c.wellRested)
    wow.fire("PLAYER_ENTERING_WORLD", false, false)
    wow.fire("PLAYER_LEAVING_WORLD")
    rank = 0
    runRankTimers()
    assert.are.equal(2, c.wellRested)
    _G.C_Traits, _G.C_Timer = nil, nil
  end)

  it("saves the character when the game reports no realm name, as WoW Forever does", function()
    state.realm = ""
    EmberkeepDB.characters = {}
    wow.fire("PLAYER_LOGIN")
    local c = EmberkeepDB.characters["Brakka-Forever"]
    assert.is_not_nil(c, "the character should be saved under the fallback realm")
    assert.are.equal(34, c.level)
    assert.is_not_nil(c.rest)
  end)

  it("saves the surname, keys by full name, and moves an entry saved without it", function()
    local old = EmberkeepDB.characters["Brakka-Nightfall"]
    state.surname = "Stonefist"
    wow.fire("PLAYER_LOGIN")
    assert.is_nil(EmberkeepDB.characters["Brakka-Nightfall"])
    local c = EmberkeepDB.characters["Brakka Stonefist-Nightfall"]
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
    SlashCmdList.EMBERKEEP("")
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

  it("tells a sleeping bag from an inn by its Resting aura, and follows getting in and out", function()
    state.resting = true
    wow.fire("PLAYER_ENTERING_WORLD", false, true)
    local c = EmberkeepDB.characters["Brakka-Nightfall"]
    assert.are.equal("inn", ns.Rest.Where(c.rest))
    state.buffs = { 16609, 1331671 }
    wow.fire("UNIT_AURA", "player")
    assert.is_true(c.rest.bag)
    local at = c.rest.at
    wow.fire("UNIT_AURA", "player")
    assert.are.equal(at, c.rest.at, "an aura change that isn't the bag saves nothing")
    SlashCmdList.EMBERKEEP("")
    local shown = false
    for _, f in ipairs(wow.frames) do
      if f._text and tostring(f._text):find("Sleeping bag", 1, true) then
        shown = true
      end
    end
    assert.is_true(shown)
    state.buffs = { 16609 }
    wow.fire("UNIT_AURA", "player")
    assert.is_true(c.rest.bag, "logging out sits you up; the bag still counts for a moment")
    wow.fire("PLAYER_LEAVING_WORLD")
    wow.fire("PLAYER_LOGOUT")
    assert.are.equal("bag", ns.Rest.Where(c.rest), "logged out in the bag, saved as the bag")
    wow.fire("PLAYER_ENTERING_WORLD", false, false)
    state.now = state.now + ns.Game.BAG_GRACE + 1
    wow.fire("UNIT_AURA", "player")
    assert.is_nil(c.rest.bag, "out of the bag for longer than that: an inn again")
    state.buffs, state.resting = nil, nil
  end)

  it("puts the account's gold total on its own row with no character name", function()
    EmberkeepDB.characters["Quill-Nightfall"] =
      { name = "Quill", realm = "Nightfall", level = 18, money = 10000 }
    EmberkeepDB.settings.focus = "overview"
    SlashCmdList.EMBERKEEP("")
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
    local c = EmberkeepDB.characters["Brakka-Nightfall"]
    assert.are.equal(34, c.level)
    assert.are.equal(421800, c.money)
  end)

  it("opens and closes the window with /emberkeep, and refreshes it while open", function()
    assert.is_false(ns.MainWindow.IsShown())
    EmberkeepDB.settings.focus = "overview" -- the gold column is on Overview
    SlashCmdList.EMBERKEEP("")
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
    SlashCmdList.EMBERKEEP("")
    assert.is_false(ns.MainWindow.IsShown())
  end)

  it("saves the new level from PLAYER_LEVEL_UP even if the game still reports the old one", function()
    wow.fire("PLAYER_LEVEL_UP", 35)
    assert.are.equal(35, EmberkeepDB.characters["Brakka-Nightfall"].level)
  end)

  it("does not save a value the client hides from addons", function()
    state.zone = "Hidden"
    state.secret = "Hidden"
    wow.fire("ZONE_CHANGED_NEW_AREA")
    assert.are.equal("Orgrimmar", EmberkeepDB.characters["Brakka-Nightfall"].zone)
  end)

  it("shows the minimap button and hides it when the option is off", function()
    local button = wow.icons.Emberkeep
    assert.is_true(button.shown)
    EmberkeepDB.settings.minimapButton = false
    ns.MinimapButton.Apply(EmberkeepDB)
    assert.is_false(button.shown)
    assert.is_true(button.db.hide)
  end)

  it("opens the window from a minimap left-click", function()
    wow.icons.Emberkeep.obj.OnClick(nil, "LeftButton")
    assert.is_true(ns.MainWindow.IsShown())
  end)

  it("builds the options page and applies a changed color scheme and scale", function()
    assert.are.equal("Emberkeep", wow.settings.name)
    assert.are.equal(8, #wow.settings.controls) -- 6 checkboxes, scheme, scale
    SlashCmdList.EMBERKEEP("")
    local theme = wow.settings.controls[7]
    theme:SetValue("twilight")
    assert.are.equal("twilight", ns.Window.Current().key)
    wow.settings.controls[8]:SetValue(1.5)
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
    SlashCmdList.EMBERKEEP("options")
    assert.are.equal(7, wow.settings.opened)
  end)

  -- The Characters page: one row per saved character, with Remove.
  local function charactersPage()
    local page = wow.settings.pages.Characters
    assert.is_not_nil(page, "the Characters page should be registered")
    page._scripts.OnShow(page)
    local rows = {}
    for _, f in ipairs(wow.frames) do
      if f._text == "Remove" then
        rows[#rows + 1] = f
      end
    end
    return rows
  end

  it("lists saved characters on a Characters page, each with Remove", function()
    EmberkeepDB.characters["Quill-Nightfall"] =
      { name = "Quill", realm = "Nightfall", level = 18, lastSeen = 1000 }
    local buttons = charactersPage()
    assert.are.equal(2, #buttons) -- Brakka (34) first, then Quill (18)
    assert.is_true(buttons[1]._disabled, "you can't remove the character you're on")
    assert.is_false(buttons[2]._disabled)
    buttons[2]._scripts.OnClick(buttons[2])
    assert.is_nil(EmberkeepDB.characters["Quill-Nightfall"])
    local last = DEFAULT_CHAT_FRAME.lines[#DEFAULT_CHAT_FRAME.lines]
    assert.truthy(last:find("removed Quill", 1, true), last)
  end)

  it("removes a character from the window's right-click menu", function()
    EmberkeepDB.characters["Quill-Nightfall"] =
      { name = "Quill", realm = "Nightfall", level = 18, lastSeen = 1000 }
    EmberkeepDB.settings.focus = "overview"
    SlashCmdList.EMBERKEEP("")
    local quillRow, brakkaRow
    for _, f in ipairs(wow.frames) do
      if f.key == "Quill-Nightfall" and f._scripts.OnClick then
        quillRow = f
      elseif f.key == "Brakka-Nightfall" and f._scripts.OnClick then
        brakkaRow = f
      end
    end
    brakkaRow._scripts.OnClick(brakkaRow, "RightButton")
    assert.is_nil(wow.menu.buttons.Remove, "no Remove for the character you're on")
    quillRow._scripts.OnClick(quillRow, "LeftButton")
    assert.are.equal(brakkaRow, wow.menu.owner, "left-click opens no menu")
    quillRow._scripts.OnClick(quillRow, "RightButton")
    assert.are.same({ "Quill" }, wow.menu.titles)
    wow.menu.buttons.Remove()
    assert.is_nil(EmberkeepDB.characters["Quill-Nightfall"])
  end)

  it("won't remove the logged-in character", function()
    assert.is_false(ns.CharactersPage.Remove("Brakka-Nightfall"))
    assert.is_not_nil(EmberkeepDB.characters["Brakka-Nightfall"])
  end)

  it("asks for /played once a session without printing it, and keeps the answer", function()
    wow.fire("PLAYER_ENTERING_WORLD", true, false)
    wow.fire("PLAYER_ENTERING_WORLD", false, false) -- zoning doesn't ask again
    assert.are.equal(1, wow.playedRequests)
    assert.is_false(_G.ChatFrame1:IsEventRegistered("TIME_PLAYED_MSG"), "chat shouldn't print our answer")
    wow.fire("TIME_PLAYED_MSG", 7200, 600)
    assert.is_true(_G.ChatFrame1:IsEventRegistered("TIME_PLAYED_MSG"), "chat should hear /played again")
    local c = EmberkeepDB.characters["Brakka-Nightfall"]
    assert.are.same({ total = 7200, at = 1000 }, c.played)
    state.now = 1600
    wow.fire("PLAYER_LOGOUT")
    assert.are.same({ total = 7800, at = 1600 }, c.played)
  end)

  it("shows time played on the Overview tab", function()
    EmberkeepDB.characters["Brakka-Nightfall"].played = { total = 90000, at = 400 }
    EmberkeepDB.settings.focus = "overview"
    SlashCmdList.EMBERKEEP("")
    local drawn = 0
    for _, f in ipairs(wow.frames) do
      if f._text == "1d 1h" then
        drawn = drawn + 1 -- 90000s plus the 600s since, on the character you're on
      end
    end
    assert.are.equal(2, drawn, "Brakka's row and the All characters total")
  end)

  it("won't forget the character you're logged in on", function()
    SlashCmdList.EMBERKEEP("forget Brakka")
    assert.is_not_nil(EmberkeepDB.characters["Brakka-Nightfall"])
  end)

  it("answers version, remove (by its old name, forget) and reset", function()
    EmberkeepDB.characters["Quill-Nightfall"] = { name = "Quill", realm = "Nightfall", level = 18 }
    SlashCmdList.EMBERKEEP("")
    SlashCmdList.EMBERKEEP("version")
    SlashCmdList.EMBERKEEP("forget quill")
    SlashCmdList.EMBERKEEP("reset")
    SlashCmdList.EMBERKEEP("nonsense")
    local lines = DEFAULT_CHAT_FRAME.lines
    assert.truthy(lines[1]:find("Emberkeep:|r version 0.1.0", 1, true), lines[1])
    assert.truthy(lines[2]:find("removed 1", 1, true))
    assert.is_nil(EmberkeepDB.characters["Quill-Nightfall"])
  end)

  describe("the alt panel", function()
    after_each(function()
      _G.C_Timer, _G.C_Bank = nil, nil
      if _G.Enum then
        _G.Enum.PlayerInteractionType, _G.Enum.BankType = nil, nil
      end
    end)

    local function drawn(text)
      for _, f in ipairs(wow.frames) do
        if f._shown and f._text and tostring(f._text):find(text, 1, true) then
          return true
        end
      end
      return false
    end
    local function row(key)
      for _, f in ipairs(wow.frames) do
        if rawget(f, "key") == key and f._scripts.OnClick then
          return f
        end
      end
    end
    local function click(key)
      local r = row(key)
      r._scripts.OnClick(r, "LeftButton")
    end

    before_each(function()
      state.worn = { [1] = { id = 10, name = "Old Cap", level = 12, quality = 1 } }
      wow.fire("PLAYER_EQUIPMENT_CHANGED", 1, false)
      EmberkeepDB.characters["Quill-Nightfall"] =
        { name = "Quill", realm = "Nightfall", level = 18, lastSeen = 1000 }
      EmberkeepDB.settings.focus = "overview"
      SlashCmdList.EMBERKEEP("")
    end)

    it("saves worn gear, and keeps it when a reading comes back empty", function()
      local gear = EmberkeepDB.characters["Brakka-Nightfall"].gear
      assert.truthy(gear.slots[1]:find("[Old Cap]", 1, true))
      state.worn = {}
      wow.fire("PLAYER_EQUIPMENT_CHANGED", 1, true)
      wow.fire("PLAYER_LOGOUT")
      assert.are.equal(gear, EmberkeepDB.characters["Brakka-Nightfall"].gear)
    end)

    it("keeps the link when the game hasn't loaded it yet", function()
      local saved = EmberkeepDB.characters["Brakka-Nightfall"].gear.slots[1]
      state.unloaded = true
      wow.fire("PLAYER_ENTERING_WORLD", true, false)
      assert.are.equal(saved, EmberkeepDB.characters["Brakka-Nightfall"].gear.slots[1])
    end)

    it("opens on a clicked row with its gear, and closes on a second click", function()
      click("Brakka-Nightfall")
      assert.are.equal("Brakka-Nightfall", ns.AltPanel.Key())
      assert.is_true(ns.AltPanel.IsShown())
      assert.is_true(drawn("Old Cap"))
      assert.is_true(drawn("16 empty slots, 1 outleveled"))
      click("Brakka-Nightfall")
      assert.is_nil(ns.AltPanel.Key())
      assert.is_false(ns.AltPanel.IsShown())
    end)

    it("steps through the alts in row order, and says when no gear is saved", function()
      click("Brakka-Nightfall")
      ns.AltPanel.Step(1)
      assert.are.equal("Quill-Nightfall", ns.AltPanel.Key())
      assert.is_true(drawn("No gear saved yet"))
      ns.AltPanel.Step(1)
      assert.are.equal("Brakka-Nightfall", ns.AltPanel.Key())
    end)

    it("switches to a list and remembers it", function()
      click("Brakka-Nightfall")
      for _, f in ipairs(wow.frames) do
        if rawget(f, "label") and f.label._text == "List" then
          f._scripts.OnClick(f)
        end
      end
      assert.is_true(EmberkeepDB.settings.gearList)
      assert.is_true(drawn("Two columns"))
    end)

    it("links an item on shift-click, and does nothing on a plain click", function()
      click("Brakka-Nightfall")
      for _, f in ipairs(wow.frames) do
        if rawget(f, "link") then
          f._scripts.OnEnter(f)
          f._scripts.OnClick(f)
          state.shift = true
          f._scripts.OnClick(f)
        end
      end
      assert.are.equal(1, #wow.linked)
    end)

    it("closes when the alt it shows is removed", function()
      click("Quill-Nightfall")
      ns.CharactersPage.Remove("Quill-Nightfall")
      assert.is_nil(ns.AltPanel.Key())
      assert.is_false(ns.AltPanel.IsShown())
    end)

    it("redraws when an item loads, but not when a load fails", function()
      click("Brakka-Nightfall")
      state.worn[1].level = 33
      wow.fire("GET_ITEM_INFO_RECEIVED", 10, false)
      assert.is_false(drawn("Head  33"))
      wow.fire("GET_ITEM_INFO_RECEIVED", 10, true)
      assert.is_true(drawn("Head  33"))
    end)

    it("opens from a button on the game's Character window, and closes from it", function()
      SlashCmdList.EMBERKEEP("") -- close it
      local before = #wow.frames
      local charFrame = _G.CreateFrame("Frame")
      charFrame.NineSlice = {
        GetFrameLevel = function()
          return 500
        end,
      }
      _G.CharacterFrame = charFrame
      wow.fire("ADDON_LOADED", "Blizzard_SomethingElse")
      wow.fire("ADDON_LOADED", "Blizzard_Another")
      local made = {}
      for i = before + 2, #wow.frames do
        if wow.frames[i]._kind == "Button" then
          made[#made + 1] = wow.frames[i]
        end
      end
      _G.CharacterFrame = nil
      assert.are.equal(1, #made, "one button, however many addons load")
      assert.is_true(made[1]._level > 500, "above the window's border")
      made[1]._scripts.OnEnter(made[1])
      made[1]._scripts.OnClick(made[1])
      assert.is_true(ns.MainWindow.IsShown())
      assert.are.equal("Brakka-Nightfall", ns.AltPanel.Key())
      made[1]._scripts.OnClick(made[1])
      assert.is_false(ns.MainWindow.IsShown())
    end)

    it("shows bags on their own tab, and keeps the tab while stepping between alts", function()
      state.bag = { size = 16, [1] = { id = 50, name = "Linen", count = 187 } }
      state.quiver = { size = 8, [1] = { id = 60, name = "Arrow", count = 200 } }
      wow.fire("PLAYER_ENTERING_WORLD", false, true)
      wow.fire("BAG_UPDATE_DELAYED")
      click("Brakka-Nightfall")
      for _, f in ipairs(wow.frames) do
        if rawget(f, "label") and f.label._text == "Bags" then
          f._scripts.OnClick(f)
        end
      end
      assert.is_true(drawn("15 of 16 slots free"))
      local function shownLinks()
        local n = 0
        for _, f in ipairs(wow.frames) do
          if f._shown and rawget(f, "link") and rawget(f, "count") then
            n = n + 1
          end
        end
        return n
      end
      assert.is_true(drawn("187"))
      assert.are.equal(2, shownLinks(), "the quiver's arrows are listed, its slots aren't counted")
      ns.AltPanel.Step(1)
      assert.is_true(drawn("No bags saved yet"))
      assert.are.equal(0, shownLinks())
      ns.AltPanel.Step(1)
      state.bag[2] = { id = 51, name = "Wool", count = 4 }
      wow.fire("BAG_UPDATE_DELAYED")
      assert.is_true(drawn("14 of 16 slots free"), "the open panel follows the bags")
    end)

    it("saves the bank only while it's open, and shows it on its own tab", function()
      wow.fire("PLAYER_ENTERING_WORLD", false, true)
      state.bank = { size = 28, [1] = { id = 70, name = "Wool", count = 19 } }
      wow.fire("BAG_UPDATE_DELAYED")
      local c = EmberkeepDB.characters["Brakka-Nightfall"]
      assert.is_nil(c.bank, "the bank can't be read from out here")
      wow.fire("BANKFRAME_OPENED")
      assert.are.equal(28, c.bank.total)
      assert.truthy(c.bank.items[1].link:find("[Wool]", 1, true))
      state.bank[2] = { id = 71, name = "Silk", count = 3 }
      wow.fire("BAG_UPDATE_DELAYED")
      assert.are.equal(2, #c.bank.items)
      wow.fire("BANKFRAME_CLOSED")
      state.bank = { size = 28 }
      wow.fire("BAG_UPDATE_DELAYED")
      assert.are.equal(2, #c.bank.items, "closed: kept as it was")
      click("Brakka-Nightfall")
      for _, f in ipairs(wow.frames) do
        if rawget(f, "label") and f.label._text == "Bank" then
          f._scripts.OnClick(f)
        end
      end
      assert.is_true(drawn("26 of 28 slots free"))
      assert.is_true(drawn("19"))
      ns.AltPanel.Step(1)
      assert.is_true(drawn("No bank saved yet"))
      assert.is_true(drawn("Open the bank once on them to save it."))
    end)

    it("reads the bank a moment after it opens, again for moves inside it, and keeps a full one", function()
      wow.fire("PLAYER_ENTERING_WORLD", false, true)
      local later = {}
      _G.C_Timer = {
        After = function(_, fn)
          later[#later + 1] = fn
        end,
      }
      local function run()
        local due = later
        later = {}
        for _, fn in ipairs(due) do
          fn()
        end
      end
      local c = EmberkeepDB.characters["Brakka-Nightfall"]
      state.bank = { size = 28, [1] = { id = 70, name = "Wool", count = 19 } }
      wow.fire("BANKFRAME_OPENED")
      assert.is_nil(c.bank, "not before the bank has loaded")
      run()
      assert.are.equal(1, #c.bank.items)
      state.bank[2] = { id = 71, name = "Silk", count = 3 }
      wow.fire("PLAYERBANKSLOTS_CHANGED", 2)
      run()
      assert.are.equal(2, #c.bank.items)
      -- A bought tab that still has no slots: part of the bank isn't loaded.
      _G.Enum.BankType = { Character = 0 }
      _G.C_Bank = {
        FetchPurchasedBankTabIDs = function()
          return { 6, 7 }
        end,
      }
      state.bank = { size = 28 }
      wow.fire("PLAYERBANKSLOTS_CHANGED", 1)
      run()
      assert.are.equal(2, #c.bank.items, "an incomplete read doesn't replace it")
      _G.C_Bank, _G.Enum.BankType = nil, nil
      wow.fire("BANKFRAME_CLOSED")
      run()
      _G.C_Timer = nil
    end)

    it("reads the bank from the banker interaction too, but not other ones", function()
      _G.Enum.PlayerInteractionType = { Banker = 8, Merchant = 5 }
      wow.install(state)
      ns = wow.loadToc("Emberkeep/Emberkeep.toc", "Emberkeep")
      wow.fire("ADDON_LOADED", "Emberkeep")
      wow.fire("PLAYER_LOGIN")
      wow.fire("PLAYER_ENTERING_WORLD", false, true)
      state.bank = { size = 28, [1] = { id = 70, name = "Wool", count = 19 } }
      wow.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5)
      local c = EmberkeepDB.characters["Brakka-Nightfall"]
      assert.is_nil(c.bank)
      wow.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
      assert.are.equal(28, c.bank.total)
      wow.fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 5) -- a merchant closing
      state.bank[2] = { id = 71, name = "Silk", count = 3 }
      wow.fire("BAG_UPDATE_DELAYED")
      assert.are.equal(2, #c.bank.items, "still open")
      wow.fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 8)
      state.bank = { size = 28 }
      wow.fire("BAG_UPDATE_DELAYED")
      assert.are.equal(2, #c.bank.items, "closed by the banker's hide")
      state.bank[1] = { id = 70, name = "Wool", count = 19 }
      state.bank[2] = { id = 71, name = "Silk", count = 3 }
      wow.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
      wow.fire("PLAYER_LEAVING_WORLD")
      state.bank = { size = 28 }
      wow.fire("PLAYER_ENTERING_WORLD", false, false)
      wow.fire("BAG_UPDATE_DELAYED")
      assert.are.equal(2, #c.bank.items, "leaving the world closes it")
    end)

    it("doesn't read bags while zoning or logging out", function()
      state.bag = { size = 16, [1] = { id = 50, name = "Linen", count = 18 } }
      wow.fire("BAG_UPDATE_DELAYED")
      assert.is_nil(EmberkeepDB.characters["Brakka-Nightfall"].bags, "not before entering the world")
      wow.fire("PLAYER_ENTERING_WORLD", false, true)
      local saved = EmberkeepDB.characters["Brakka-Nightfall"].bags
      wow.fire("PLAYER_LEAVING_WORLD")
      state.bag = { size = 16 }
      wow.fire("BAG_UPDATE_DELAYED")
      assert.are.equal(saved, EmberkeepDB.characters["Brakka-Nightfall"].bags)
      wow.fire("PLAYER_ENTERING_WORLD", false, false)
      assert.are.equal(16, EmberkeepDB.characters["Brakka-Nightfall"].bags.free)
    end)

    it("reads bags once for changes close together, and again for a missing link", function()
      wow.fire("PLAYER_ENTERING_WORLD", false, true)
      local later = {}
      _G.C_Timer = {
        After = function(_, fn)
          later[#later + 1] = fn
        end,
      }
      state.unloaded = true
      state.bag = { size = 16, [1] = { id = 50, name = "Linen", count = 18 } }
      wow.fire("BAG_UPDATE_DELAYED")
      wow.fire("BAG_UPDATE_DELAYED")
      assert.are.equal(1, #later)
      later[1]()
      local c = EmberkeepDB.characters["Brakka-Nightfall"]
      assert.are.equal("item:50", c.bags.items[1].link)
      state.unloaded = false
      later[2]()
      _G.C_Timer = nil
      assert.truthy(c.bags.items[1].link:find("[Linen]", 1, true))
      assert.are.equal(2, #later)
    end)

    it("reads again until every link has loaded", function()
      local later = {}
      _G.C_Timer = {
        After = function(_, fn)
          later[#later + 1] = fn
        end,
      }
      state.worn = { [1] = { id = 11, name = "New Cap", level = 30, quality = 2 } }
      state.unloaded = true
      wow.fire("PLAYER_EQUIPMENT_CHANGED", 1, false)
      local c = EmberkeepDB.characters["Brakka-Nightfall"]
      assert.are.equal("item:11", c.gear.slots[1])
      state.unloaded = false
      later[1]()
      _G.C_Timer = nil
      assert.truthy(c.gear.slots[1]:find("[New Cap]", 1, true))
      assert.are.equal(1, #later, "nothing left to read again")
    end)
  end)

  describe("mail", function()
    local function drawn(text)
      for _, f in ipairs(wow.frames) do
        if f._shown and f._text and tostring(f._text):find(text, 1, true) then
          return true
        end
      end
      return false
    end

    before_each(function()
      wow.fire("PLAYER_ENTERING_WORLD", false, true)
      EmberkeepDB.characters["Quill-Nightfall"] = { name = "Quill", realm = "Nightfall", level = 18 }
      local cloth = { { id = 2589, name = "Linen Cloth", count = 20 } }
      state.inbox = {
        { sender = "Auction House", subject = "Expired", days = 2, returned = true, items = cloth },
        { sender = "Gamon", subject = "Loan", days = 9, money = 50000 },
        { sender = "Magtoor", subject = "Hey", days = 12 },
      }
      state.inboxTotal = nil
    end)

    it("saves mail with items or gold only while the mailbox is open", function()
      local c = EmberkeepDB.characters["Brakka-Nightfall"]
      wow.fire("MAIL_INBOX_UPDATE")
      assert.is_nil(c.mail, "not without the mailbox open")
      wow.fire("MAIL_SHOW")
      wow.fire("MAIL_INBOX_UPDATE")
      assert.are.equal(2, #c.mail.inbox)
      assert.is_false(c.mail.inbox[1].returns, "returned once already: deleted next time")
      state.inbox[1].returned, state.inbox[1].canReply = false, false
      wow.fire("MAIL_INBOX_UPDATE")
      assert.is_false(c.mail.inbox[1].returns, "from a mailbox that takes no reply: deleted")
      state.inbox[1].returned, state.inbox[1].canReply = false, true
      wow.fire("MAIL_INBOX_UPDATE")
      assert.is_true(c.mail.inbox[1].returns, "from a player: goes back")
      wow.fire("MAIL_CLOSED")
      state.inbox = {}
      wow.fire("MAIL_INBOX_UPDATE")
      assert.are.equal(2, #c.mail.inbox)
    end)

    it("adds mail you send to an alt, once it has gone", function()
      state.outgoing = { { id = 2589, name = "Linen Cloth", count = 5 } }
      wow.hooks.SendMail("quill")
      local quill = EmberkeepDB.characters["Quill-Nightfall"]
      assert.is_nil(quill.mail, "not until it has gone")
      wow.fire("MAIL_SEND_SUCCESS")
      assert.are.equal(1, #quill.mail.sent)
      assert.are.equal("Brakka", quill.mail.sent[1].from)
      wow.hooks.SendMail("Quill")
      wow.fire("MAIL_FAILED")
      wow.fire("MAIL_SEND_SUCCESS")
      assert.are.equal(1, #quill.mail.sent, "a failed send adds nothing")
      wow.hooks.SendMail("Somebody Else")
      wow.fire("MAIL_SEND_SUCCESS")
      assert.are.equal(1, #quill.mail.sent)
    end)

    it("shows the Mail tab and a Mail column on Overview, soonest first", function()
      wow.fire("MAIL_SHOW")
      wow.fire("MAIL_INBOX_UPDATE")
      EmberkeepDB.settings.focus = "overview"
      SlashCmdList.EMBERKEEP("")
      assert.is_true(drawn("|cffff60602d|r"), "Brakka's mail expires in 2 days")
      for _, f in ipairs(wow.frames) do
        if rawget(f, "key") == "Brakka-Nightfall" and f._scripts.OnClick then
          f._scripts.OnClick(f, "LeftButton")
        end
      end
      for _, f in ipairs(wow.frames) do
        if rawget(f, "label") and f.label._text == "Mail" then
          f._scripts.OnClick(f)
        end
      end
      assert.are.equal("mail", EmberkeepDB.settings.panelTab)
      assert.is_true(drawn("2 mails to collect, 1 expiring within 3 days"))
      assert.is_true(drawn("Auction House"))
      assert.is_true(drawn("2 days left, deleted"))
      for _, f in ipairs(wow.frames) do
        if rawget(f, "mail") and f._shown and f.mail.sender == "Auction House" then
          f._scripts.OnEnter(f)
        end
      end
      local tip = table.concat(GameTooltip._lines or {}, " | ")
      assert.truthy(tip:find("From Auction House", 1, true), tip)
      assert.truthy(tip:find("Linen Cloth", 1, true), tip)
      assert.truthy(tip:find("x20", 1, true), tip)
      assert.truthy(tip:find("then it's deleted", 1, true), tip)
      ns.AltPanel.Step(1)
      assert.is_true(drawn("No mail saved yet"))
    end)

    it("reads the inbox again while the game is still loading it", function()
      local later = {}
      _G.C_Timer = {
        After = function(_, fn)
          later[#later + 1] = fn
        end,
      }
      local full = state.inbox
      state.inbox, state.inboxTotal = {}, 3
      wow.fire("MAIL_SHOW")
      wow.fire("MAIL_INBOX_UPDATE")
      wow.fire("MAIL_INBOX_UPDATE")
      assert.are.equal(1, #later, "one read for updates close together")
      later[1]()
      local c = EmberkeepDB.characters["Brakka-Nightfall"]
      assert.is_nil(c.mail, "not an empty read while the game says there's mail")
      state.inbox, state.inboxTotal = full, nil
      later[2]()
      _G.C_Timer = nil
      assert.are.equal(2, #c.mail.inbox)
    end)

    it("adds mail you send back to the alt who sent it, once it has gone", function()
      local ore = { { id = 2770, name = "Ore", count = 8 } }
      state.inbox[2] = { sender = "Quill", subject = "Ore", days = 6, items = ore }
      wow.fire("MAIL_SHOW")
      wow.hooks.ReturnInboxItem(2)
      local quill = EmberkeepDB.characters["Quill-Nightfall"]
      wow.fire("MAIL_SEND_SUCCESS")
      assert.is_nil(quill.mail, "a send back is confirmed by MAIL_SUCCESS")
      wow.fire("MAIL_SUCCESS")
      assert.are.equal(1, #quill.mail.sent)
      local back = ns.Mail.View(quill, ns.Game.Now()).rows[1]
      assert.are.equal("Sent back by you", back.subject)
      assert.is_false(back.returns, "sent back once: deleted when it runs out")
      wow.fire("MAIL_SUCCESS")
      assert.are.equal(1, #quill.mail.sent, "taking an item later adds nothing")
      wow.hooks.ReturnInboxItem(2)
      wow.fire("MAIL_CLOSED")
      wow.fire("MAIL_SUCCESS")
      assert.are.equal(1, #quill.mail.sent, "forgotten when the mailbox closes")
      wow.hooks.ReturnInboxItem(3) -- from someone else
      wow.fire("MAIL_SUCCESS")
      assert.are.equal(1, #quill.mail.sent)
    end)

    it("ignores the realm when names are unique across the region", function()
      EmberkeepDB.characters["Zed-Elsewhere"] = { name = "Zed", realm = "Elsewhere", level = 5 }
      state.outgoing = { { id = 2589, name = "Linen Cloth", count = 5 } }
      wow.hooks.SendMail("Zed")
      wow.fire("MAIL_SEND_SUCCESS")
      assert.is_nil(EmberkeepDB.characters["Zed-Elsewhere"].mail, "a bare name is on your realm")
      _G.RegionalUniqueNamesEnabled = function()
        return true
      end
      wow.hooks.SendMail("Zed")
      wow.fire("MAIL_SEND_SUCCESS")
      _G.RegionalUniqueNamesEnabled = nil
      assert.are.equal(1, #EmberkeepDB.characters["Zed-Elsewhere"].mail.sent)
    end)

    it("knows the mailbox is open from the interaction events too", function()
      _G.Enum.PlayerInteractionType = { Banker = 8, MailInfo = 17 }
      wow.install(state)
      ns = wow.loadToc("Emberkeep/Emberkeep.toc", "Emberkeep")
      wow.fire("ADDON_LOADED", "Emberkeep")
      wow.fire("PLAYER_LOGIN")
      wow.fire("PLAYER_ENTERING_WORLD", false, true)
      _G.Enum.PlayerInteractionType = nil
      local c = EmberkeepDB.characters["Brakka-Nightfall"]
      wow.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
      wow.fire("MAIL_INBOX_UPDATE")
      assert.is_nil(c.mail, "the banker is not the mailbox")
      wow.fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 17)
      wow.fire("MAIL_INBOX_UPDATE")
      assert.are.equal(2, #c.mail.inbox)
      wow.fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 17)
      state.inbox = {}
      wow.fire("MAIL_INBOX_UPDATE")
      assert.are.equal(2, #c.mail.inbox)
    end)

    it("shows mail you sent to an alt on another realm only for that realm", function()
      EmberkeepDB.characters["Quill-Elsewhere"] = { name = "Quill", realm = "Elsewhere", level = 9 }
      state.outgoing = { { id = 2589, name = "Linen Cloth", count = 5 } }
      wow.hooks.SendMail("Quill")
      wow.fire("MAIL_SEND_SUCCESS")
      assert.are.equal(1, #EmberkeepDB.characters["Quill-Nightfall"].mail.sent)
      assert.is_nil(EmberkeepDB.characters["Quill-Elsewhere"].mail)
      wow.hooks.SendMail("Quill-Elsewhere")
      wow.fire("MAIL_SEND_SUCCESS")
      assert.are.equal(1, #EmberkeepDB.characters["Quill-Elsewhere"].mail.sent)
    end)

    it("shows at most 14 mails on the Mail tab, with how many more", function()
      state.inbox = {}
      for i = 1, 20 do
        state.inbox[i] = { sender = "Gamon", subject = "Loan " .. i, days = i, money = 100 }
      end
      wow.fire("MAIL_SHOW")
      wow.fire("MAIL_INBOX_UPDATE")
      EmberkeepDB.settings.panelTab, EmberkeepDB.settings.focus = "mail", "overview"
      SlashCmdList.EMBERKEEP("")
      for _, f in ipairs(wow.frames) do
        if rawget(f, "key") == "Brakka-Nightfall" and f._scripts.OnClick then
          f._scripts.OnClick(f, "LeftButton")
        end
      end
      assert.is_true(drawn("+6 more, expiring later"))
      local rows = 0
      for _, f in ipairs(wow.frames) do
        if rawget(f, "mail") and f._shown then
          rows = rows + 1
        end
      end
      assert.are.equal(14, rows)
    end)

    it("warns at login about mail that's about to expire, unless that's turned off", function()
      wow.fire("MAIL_SHOW")
      wow.fire("MAIL_INBOX_UPDATE")
      local before = #DEFAULT_CHAT_FRAME.lines
      ns.App.MailWarnings()
      local line = DEFAULT_CHAT_FRAME.lines[before + 1]
      local expected = "Brakka has mail with items or gold that expires in 2d 0h"
      assert.truthy(line and line:find(expected, 1, true), line)
      assert.truthy(line:find("deleted", 1, true))
      assert.are.equal(before + 1, #DEFAULT_CHAT_FRAME.lines, "Gamon's mail is 9 days out")
      EmberkeepDB.settings.mailWarning = false
      ns.App.MailWarnings()
      assert.are.equal(before + 1, #DEFAULT_CHAT_FRAME.lines)
    end)
  end)

  describe("the Professions tab", function()
    local function drawn(text)
      for _, f in ipairs(wow.frames) do
        if f._shown and f._text == text then
          return true
        end
      end
      return false
    end
    local function rowOrder()
      local seen = {}
      for _, f in ipairs(wow.frames) do
        if rawget(f, "key") and f._shown and f._scripts.OnEnter then
          seen[#seen + 1] = { key = f.key, y = f._point[5] }
        end
      end
      table.sort(seen, function(a, b)
        return a.y > b.y
      end)
      return seen
    end

    local later
    -- Runs the timers due after this many seconds (3: settled, 1: a skill change).
    local function run(delay)
      local due = later
      later = {}
      for _, t in ipairs(due) do
        if t.delay == delay then
          t.fn()
        end
      end
    end

    after_each(function()
      _G.C_Timer = nil
    end)

    before_each(function()
      later = {}
      _G.C_Timer = {
        After = function(delay, fn)
          later[#later + 1] = { delay = delay, fn = fn }
        end,
      }
      state.professions = {
        { line = 186, name = "Mining", skill = 120, max = 150 },
        { line = 164, name = "Blacksmithing", skill = 88, max = 150 },
        { line = 185, name = "Cooking", skill = 41, max = 75 },
      }
      wow.fire("PLAYER_ENTERING_WORLD", false, true)
      wow.fire("SKILL_LINES_CHANGED") -- too early: waits for the settled read
      run(1)
      assert.is_nil(EmberkeepDB.characters["Brakka-Nightfall"].professions)
      wow.fire("PLAYER_ENTERING_WORLD", false, true)
      run(3)
      EmberkeepDB.characters["Quill-Nightfall"] = { name = "Quill", realm = "Nightfall", level = 40 }
      EmberkeepDB.settings.focus = "professions"
      SlashCmdList.EMBERKEEP("")
    end)

    it("saves the skills and shows a column per profession, even one nobody has", function()
      assert.are.equal(120, EmberkeepDB.characters["Brakka-Nightfall"].professions.skills.Mining.skill)
      for _, text in ipairs({ "Mining", "Alch", "Smith", "Aid", "120/150", "88/150", "41/75" }) do
        assert.is_true(drawn(text), text)
      end
      assert.is_true(drawn("|cff8f98a5-|r"))
      assert.is_true(drawn("|cff8f98a5Not read yet|r"))
    end)

    it("sorts by a clicked title, and keeps Up and Down in that order", function()
      assert.are.equal("Quill-Nightfall", rowOrder()[1].key)
      for _, f in ipairs(wow.frames) do
        if rawget(f, "sort") == "Mining" then
          f._scripts.OnClick(f)
        end
      end
      assert.are.equal("Brakka-Nightfall", rowOrder()[1].key)
      assert.are.same({ "Brakka-Nightfall", "Quill-Nightfall" }, ns.MainWindow.Keys())
    end)

    it("shows title buttons on this tab only, and lists professions in the tooltip", function()
      local function shownTitles()
        local n = 0
        for _, f in ipairs(wow.frames) do
          if rawget(f, "sort") and f._shown then
            n = n + 1
          end
        end
        return n
      end
      assert.are.equal(12, shownTitles())
      for _, f in ipairs(wow.frames) do
        if rawget(f, "sort") == "First Aid" then
          assert.are.equal("First Aid", f.full)
          assert.is_true(f._point[5] <= 0, "nothing above the table, or it scrolls")
          f._scripts.OnEnter(f)
          f._scripts.OnLeave(f)
        end
      end
      local lines = {}
      _G.GameTooltip.AddDoubleLine = function(_, left, right)
        lines[left] = right
      end
      for _, f in ipairs(wow.frames) do
        if rawget(f, "key") == "Brakka-Nightfall" and f._shown and f._scripts.OnEnter then
          f._scripts.OnEnter(f)
        end
      end
      assert.are.equal("120/150", lines.Mining)
      assert.is_nil(lines.Rested)
      for _, f in ipairs(wow.frames) do
        if rawget(f, "label") and f.label._text == "Rested" then
          f._scripts.OnClick(f)
        end
      end
      assert.are.equal("rested", EmberkeepDB.settings.focus)
      assert.are.equal(0, shownTitles())
    end)

    it("keeps the saved skills when a read comes back empty, or while leaving the world", function()
      local c = EmberkeepDB.characters["Brakka-Nightfall"]
      local saved = c.professions
      local function change(list)
        state.professions = list
        wow.fire("SKILL_LINES_CHANGED")
        wow.fire("SKILL_LINES_CHANGED")
        run(1)
      end
      change({})
      change({ { nothing = true }, { line = 185, name = "Cooking", skill = 1, max = 75 } })
      change({ { line = 186, name = "Mining", skill = 0, max = 0 } })
      state.secret = "Hidden"
      change({ { line = 186, name = "Hidden", skill = 5, max = 75 } })
      assert.are.equal(saved, c.professions)
      state.secret = nil
      change({ { line = 186, name = "Mining", skill = 121, max = 150 } })
      assert.are.equal(121, c.professions.skills.Mining.skill)
      state.professions = { { line = 185, name = "Cooking", skill = 1, max = 75 } }
      wow.fire("SKILL_LINES_CHANGED")
      wow.fire("PLAYER_LEAVING_WORLD")
      run(1)
      assert.are.equal(121, c.professions.skills.Mining.skill)
    end)
  end)

  describe("bug reports", function()
    it("opens a report with a prefilled GitHub link and no character names", function()
      SlashCmdList.EMBERKEEP("feedback")
      local fw = ns.FeedbackWindow
      assert.is_true(fw.IsShown())
      assert.truthy(fw.url:find("issues/new?template=bug_report.yml&feedback=", 1, true))
      assert.truthy(fw.report:find("Addon: 0.1.0", 1, true))
      assert.truthy(
        fw.report:find("Character: level 34 Orc WARRIOR, Horde, realm Nightfall, max level 60", 1, true)
      )
      assert.truthy(fw.report:find("Rested: 2500 of 10000 XP, resting", 1, true))
      assert.is_nil(fw.report:find("Brakka", 1, true))
    end)

    it("opens from the options page button and a minimap ctrl-click", function()
      local button
      for _, b in ipairs(wow.settings.buttons) do
        if b.label == "Report a bug" then
          button = b
        end
      end
      assert.is_not_nil(button)
      button.onClick()
      assert.is_true(ns.FeedbackWindow.IsShown())
      state.ctrl = true
      ns.FeedbackWindow.url = nil
      wow.icons.Emberkeep.obj.OnClick(nil, "LeftButton")
      assert.is_not_nil(ns.FeedbackWindow.url)
      assert.is_false(ns.MainWindow.IsShown(), "ctrl-click reports a bug instead of opening the window")
    end)

    it("notes an event error, offers a report once and still passes it to the game's handler", function()
      ns.Game.Sighting = function()
        error("Interface/AddOns/Emberkeep/Adapters/Game.lua:40: boom")
      end
      wow.fire("PLAYER_MONEY")
      wow.fire("PLAYER_MONEY")
      assert.are.equal(2, #ns.App.errors)
      assert.truthy(ns.App.errors[1]:find("PLAYER_MONEY: ", 1, true))
      assert.are.equal(2, #wow.caught, "each error should reach the game's handler once")
      assert.is_true(ns.FeedbackWindow.IsPromptShown())
      assert.truthy(ns.FeedbackWindow.promptMessage:find("boom", 1, true))
    end)

    it("notes our errors that reach the game's handler, but not other addons'", function()
      geterrorhandler()("Interface/AddOns/OtherAddon/x.lua:1: not ours")
      assert.are.equal(0, #ns.App.errors)
      state.stack = "Interface/AddOns/Emberkeep/UI/MainWindow.lua:200: in function"
      geterrorhandler()("attempt to index a nil value")
      assert.are.equal(1, #ns.App.errors)
      assert.are.equal(2, #wow.caught, "both still reach the game's handler")
    end)

    it("doesn't take another addon's error for ours because our handler is on the stack", function()
      state.stack = "Interface/AddOns/WeakAuras/x.lua:1: in function"
      geterrorhandler()("Interface/AddOns/WeakAuras/x.lua:1: oops")
      assert.are.equal(0, #ns.App.errors)
    end)

    it("still opens a report when the thing being reported is broken", function()
      ns.Game.Sighting = function()
        error("boom")
      end
      ns.App.OpenFeedback()
      assert.is_true(ns.FeedbackWindow.IsShown())
      assert.truthy(ns.FeedbackWindow.report:find("Alts saved:", 1, true))
    end)

    it("listens to BugGrabber when BugSack owns the error handler", function()
      local listeners = {}
      _G.BugGrabber = {
        RegisterCallback = function(owner, name, fn)
          listeners[#listeners + 1] = { owner = owner, name = name, fn = fn }
        end,
      }
      wow.install(state)
      local handler = geterrorhandler()
      _G.seterrorhandler = function() end -- BugGrabber blocks it
      ns = wow.loadToc("Emberkeep/Emberkeep.toc", "Emberkeep")
      wow.fire("ADDON_LOADED", "Emberkeep")
      assert.are.equal(handler, geterrorhandler())
      assert.are.equal("BugGrabber_BugGrabbed", listeners[1].name)
      listeners[1].fn("BugGrabber_BugGrabbed", { message = "Interface/AddOns/Emberkeep/UI/X.lua:3: boom" })
      listeners[1].fn("BugGrabber_BugGrabbed", { message = "Interface/AddOns/Other/x.lua:1: nope" })
      assert.are.equal(1, #ns.App.errors)
      _G.BugGrabber = nil
    end)

    it("says it in chat instead when the offer is turned off", function()
      EmberkeepDB.settings.errorPrompt = false
      state.stack = "Interface/AddOns/Emberkeep/App.lua:1"
      geterrorhandler()("boom")
      assert.is_false(ns.FeedbackWindow.IsPromptShown())
      local last = DEFAULT_CHAT_FRAME.lines[#DEFAULT_CHAT_FRAME.lines]
      assert.truthy(last:find("/emberkeep feedback", 1, true))
    end)
  end)

  describe("the Search tab", function()
    local function drawn(text)
      for _, f in ipairs(wow.frames) do
        if f._shown and f._text and tostring(f._text):find(text, 1, true) then
          return true
        end
      end
      return false
    end

    local function row(key)
      for _, f in ipairs(wow.frames) do
        if f._shown and rawget(f, "link") and rawget(f, "key") == key then
          return f
        end
      end
    end

    before_each(function()
      wow.fire("PLAYER_ENTERING_WORLD", false, true)
      local linen = "|cffffffff|Hitem:2589::|h[Linen Cloth]|h|r"
      local brakka = EmberkeepDB.characters["Brakka-Nightfall"]
      brakka.bags = { items = { { link = linen, count = 15 } }, free = 1, total = 2 }
      EmberkeepDB.characters["Quill-Nightfall"] = {
        name = "Quill",
        realm = "Nightfall",
        level = 18,
        bank = { items = { { link = linen, count = 7 } }, free = 0, total = 1 },
      }
    end)

    it("finds an item on every alt, in the window and not in chat", function()
      local lines = #DEFAULT_CHAT_FRAME.lines
      SlashCmdList.EMBERKEEP("search linen")
      assert.are.equal("search", EmberkeepDB.settings.focus)
      assert.is_true(drawn("Linen Cloth"))
      assert.is_true(drawn("15 bags"))
      assert.is_true(drawn("7 bank"))
      assert.is_true(drawn("2 alts"))
      assert.are.equal(lines, #DEFAULT_CHAT_FRAME.lines, "nothing printed")
      local quill = row("Quill-Nightfall")
      quill._scripts.OnEnter(quill)
      assert.truthy(table.concat(GameTooltip._lines or {}, " "):find("alt panel", 1, true))
      quill._scripts.OnClick(quill, "LeftButton")
      assert.are.equal("Quill-Nightfall", ns.AltPanel.Key())
      assert.are.equal("bank", EmberkeepDB.settings.panelTab, "opens where the item is")
    end)

    it("searches as you type, and shows how to search while the box is empty", function()
      SlashCmdList.EMBERKEEP("search linen")
      local box
      for _, f in ipairs(wow.frames) do
        if f._kind == "EditBox" and f._text == "linen" then
          box = f
        end
      end
      box._text = "linen &"
      box._scripts.OnTextChanged(box, true)
      assert.is_true(drawn("Not a whole search yet"))
      box._text = "nothing like it"
      box._scripts.OnTextChanged(box, true)
      assert.is_true(drawn("No alt has anything that matches"))
      box._text = ""
      box._scripts.OnTextChanged(box, true)
      assert.is_true(drawn("Type in the box to find an item"))
      assert.is_true(drawn("Where: bags, bank, mailbox, equipped"))
    end)
  end)
end)
