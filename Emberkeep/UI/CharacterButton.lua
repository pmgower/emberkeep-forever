-- CharacterButton: a small Emberkeep button on the game's own Character window
-- that opens the alt panel. Skipped quietly if the client has no such window.
local _, ns = ...
local CharacterButton = {}
ns.CharacterButton = CharacterButton

local button

-- Safe to call more than once. The Character window may load after us, so
-- App calls it again as other addons load.
function CharacterButton.Init()
  if button or not CharacterFrame then
    return
  end
  button = CreateFrame("Button", "EmberkeepCharacterButton", CharacterFrame)
  button:SetSize(20, 20)
  -- Beside the close button, in the title bar.
  button:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -28, -2)
  button:SetFrameLevel((CharacterFrame:GetFrameLevel() or 1) + 20)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture("Interface\\AddOns\\Emberkeep\\Media\\emberkeep")
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Emberkeep")
    GameTooltip:AddLine("Click to see your gear and bags, and your alts'", 0.79, 0.81, 0.84)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  button:SetScript("OnClick", function()
    ns.MainWindow.ShowAlt(ns.Game.CurrentKey())
  end)
end
