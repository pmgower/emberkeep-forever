local Version = dofile("Kinfolk/Core/Version.lua")

describe("Version.Line", function()
  it("shows the title and the TOC version", function()
    assert.are.equal("Kinfolk: Forever 0.1.0", Version.Line("Kinfolk: Forever", "0.1.0"))
  end)

  it("reads dev when the TOC has no version", function()
    assert.are.equal("Kinfolk: Forever dev", Version.Line("Kinfolk: Forever", nil))
    assert.are.equal("Kinfolk: Forever dev", Version.Line("Kinfolk: Forever", ""))
  end)

  it("reads dev for an unpackaged checkout", function()
    assert.are.equal("Kinfolk: Forever dev", Version.Line("Kinfolk: Forever", "@project-version@"))
  end)

  it("has a short form for the window header", function()
    assert.are.equal("v0.1.0", Version.Short("0.1.0"))
    assert.are.equal("dev", Version.Short("@project-version@"))
  end)
end)
