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
    state.level, state.money, state.zone = 0, nil, ""
    wow.fire("PLAYER_LOGOUT")
    local c = KinfolkDB.characters["Brakka-Nightfall"]
    assert.are.equal(34, c.level)
    assert.are.equal(421800, c.money)
  end)

  it("opens and closes the window with /kinfolk", function()
    SlashCmdList.KINFOLK("")
    state.money = 500000
    wow.fire("PLAYER_MONEY")
    SlashCmdList.KINFOLK("")
  end)

  it("answers version, forget and reset", function()
    SlashCmdList.KINFOLK("")
    SlashCmdList.KINFOLK("version")
    SlashCmdList.KINFOLK("forget brakka")
    SlashCmdList.KINFOLK("reset")
    SlashCmdList.KINFOLK("nonsense")
    local lines = DEFAULT_CHAT_FRAME.lines
    assert.truthy(lines[1]:find("Kinfolk: Forever 0.1.0", 1, true))
    assert.truthy(lines[2]:find("forgot 1", 1, true))
    assert.is_nil(KinfolkDB.characters["Brakka-Nightfall"])
  end)
end)
