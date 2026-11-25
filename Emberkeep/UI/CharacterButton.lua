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
  -- In the title bar, beside the close button. The border (NineSlice, 500) and
  -- title (510) are drawn far above the window itself (1), so go above both.
  local close = CharacterFrame.CloseButton
  local level = CharacterFrame:GetFrameLevel() or 1
  for _, part in ipairs({ "NineSlice", "TitleContainer", "CloseButton" }) do
    local f = CharacterFrame[part]
    if type(f) == "table" then
      level = math.max(level, f:GetFrameLevel() or 1)
    end
  end
  if type(close) == "table" then
    button:SetPoint("RIGHT", close, "LEFT", -2, 0)
  else
    button:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -28, -2)
  end
  button:SetFrameLevel(level + 1)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture("Interface\\AddOns\\Emberkeep\\Media\\emberkeep")
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Emberkeep")
    GameTooltip:AddLine("Click to see your alts' gear", 0.79, 0.81, 0.84)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  button:SetScript("OnClick", function()
    ns.MainWindow.ShowAlt(ns.Game.CurrentKey())
  end)
end
