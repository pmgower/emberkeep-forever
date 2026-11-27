local Version = dofile("Emberkeep/Core/Version.lua")

describe("Version.Line", function()
  it("shows the title and the TOC version", function()
    assert.are.equal("Emberkeep: Forever 0.1.0", Version.Line("Emberkeep: Forever", "0.1.0"))
  end)

  it("reads dev when the TOC has no version", function()
    assert.are.equal("Emberkeep: Forever dev", Version.Line("Emberkeep: Forever", nil))
    assert.are.equal("Emberkeep: Forever dev", Version.Line("Emberkeep: Forever", ""))
  end)

  it("reads dev for an unpackaged checkout", function()
    assert.are.equal("Emberkeep: Forever dev", Version.Line("Emberkeep: Forever", "@project-version@"))
  end)

  it("has a short form for the window header", function()
    assert.are.equal("v0.1.0", Version.Short("0.1.0"))
    assert.are.equal("v0.5.0", Version.Short("v0.5.0"), "a tag already has its v")
    assert.are.equal("dev", Version.Short("@project-version@"))
  end)
end)
