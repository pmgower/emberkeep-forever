local Version = dofile("Kinfolk/Core/Version.lua")

describe("Version.Line", function()
  it("shows the title and the TOC version", function()
    assert.are.equal("Kinfolk: Forever 0.1.0", Version.Line("Kinfolk: Forever", "0.1.0"))
  end)

  it("reads dev when the TOC has no version", function()
    assert.are.equal("Kinfolk: Forever dev", Version.Line("Kinfolk: Forever", nil))
    assert.are.equal("Kinfolk: Forever dev", Version.Line("Kinfolk: Forever", ""))
  end)
end)
