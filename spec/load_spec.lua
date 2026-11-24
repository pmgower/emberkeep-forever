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

  it("keeps saved data when logout reads come back empty", function()
    state.level, state.money, state.zone = 0, 0, ""
    wow.fire("PLAYER_LOGOUT")
    local c = KinfolkDB.characters["Brakka-Nightfall"]
    assert.are.equal(34, c.level)
    assert.are.equal(421800, c.money)
  end)

  it("opens and closes the window with /kinfolk, and refreshes it while open", function()
    assert.is_false(ns.MainWindow.IsShown())
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
    assert.are.equal(5, #wow.settings.controls) -- 2 checkboxes, scheme, scale, character
    SlashCmdList.KINFOLK("")
    local theme = wow.settings.controls[3]
    theme:SetValue("twilight")
    assert.are.equal("twilight", ns.Window.Current().key)
    wow.settings.controls[4]:SetValue(1.5)
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
    local picker = wow.settings.controls[5]
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
    local picker = wow.settings.controls[5]
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
    assert.truthy(lines[1]:find("Kinfolk: Forever 0.1.0", 1, true))
    assert.truthy(lines[2]:find("forgot 1", 1, true))
    assert.is_nil(KinfolkDB.characters["Quill-Nightfall"])
  end)
end)
