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
    assert.is_nil(c.rest.bag)
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
    assert.are.equal(7, #wow.settings.controls) -- 5 checkboxes, scheme, scale
    SlashCmdList.EMBERKEEP("")
    local theme = wow.settings.controls[6]
    theme:SetValue("twilight")
    assert.are.equal("twilight", ns.Window.Current().key)
    wow.settings.controls[7]:SetValue(1.5)
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
end)
