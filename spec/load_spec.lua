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
    assert.are.equal("v0.1.0", ns.versionText)
  end)

  it("saves the character's rested XP, and keeps it when logout reads XP to level as 0", function()
    local r = EmberkeepDB.characters["Brakka-Nightfall"].rest
    assert.are.same({ rested = 2500, xpMax = 10000, resting = true, wellRested = 0, at = 1000 }, r)
    state.xpMax, state.rested = 0, nil
    wow.fire("PLAYER_LOGOUT")
    assert.are.equal(2500, EmberkeepDB.characters["Brakka-Nightfall"].rest.rested)
  end)

  it("says who to play next on login, skipping the character you're on", function()
    -- You're on Brakka, who is full; Quill is next at 60%.
    EmberkeepDB.characters["Brakka-Nightfall"].rest.rested = 15000
    local partly = { rested = 6000, xpMax = 10000, resting = true, wellRested = 0, at = 1000 }
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
    assert.is_true(seen["25%"], "Brakka's 25% rested should be drawn")
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
    local partly = { rested = 6000, xpMax = 10000, resting = true, wellRested = 0, at = 1000 }
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
    assert.are.equal(3, EmberkeepDB.wellRested)
    assert.are.equal(3, EmberkeepDB.characters["Brakka-Nightfall"].rest.wellRested)
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

  it("won't remove the logged-in character", function()
    assert.is_false(ns.CharactersPage.Remove("Brakka-Nightfall"))
    assert.is_not_nil(EmberkeepDB.characters["Brakka-Nightfall"])
  end)

  it("won't forget the character you're logged in on", function()
    SlashCmdList.EMBERKEEP("forget Brakka")
    assert.is_not_nil(EmberkeepDB.characters["Brakka-Nightfall"])
  end)

  it("answers version, forget and reset", function()
    EmberkeepDB.characters["Quill-Nightfall"] = { name = "Quill", realm = "Nightfall", level = 18 }
    SlashCmdList.EMBERKEEP("")
    SlashCmdList.EMBERKEEP("version")
    SlashCmdList.EMBERKEEP("forget quill")
    SlashCmdList.EMBERKEEP("reset")
    SlashCmdList.EMBERKEEP("nonsense")
    local lines = DEFAULT_CHAT_FRAME.lines
    assert.truthy(lines[1]:find("Emberkeep:|r version 0.1.0", 1, true), lines[1])
    assert.truthy(lines[2]:find("forgot 1", 1, true))
    assert.is_nil(EmberkeepDB.characters["Quill-Nightfall"])
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
