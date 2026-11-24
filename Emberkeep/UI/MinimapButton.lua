-- MinimapButton: the LibDBIcon button. Left-click shows or hides the window,
-- right-click opens the options page. Position and visibility live in
-- EmberkeepDB.minimapIcon, in LibDBIcon's own format.
local _, ns = ...
local MinimapButton = {}
ns.MinimapButton = MinimapButton

local NAME = "Emberkeep"
local icon

-- Tooltip lines, kept separate from the frame so tests can read them.
function MinimapButton.TooltipLines(db, now)
  local lines = { "Emberkeep" }
  local rows, summary = ns.RestedView.Build(db.characters, ns, ns.Game.RestContext(db, now))
  local top = summary.next
  if top then
    lines[#lines + 1] = string.format("Play next: %s |cff4da6ff%d%%|r", top.name, top.percent)
  end
  lines[#lines + 1] = "|cff8f98a5" .. ns.RestedView.CountText(rows, summary) .. "|r"
  lines[#lines + 1] = "|cff9fd0ffLeft-click:|r show or hide the window"
  lines[#lines + 1] = "|cff9fd0ffRight-click:|r options"
  lines[#lines + 1] = "|cff9fd0ffCtrl-click:|r report a bug"
  lines[#lines + 1] = "|cff9fd0ffDrag:|r move this button"
  return lines
end

function MinimapButton.Init(db)
  local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
  icon = LibStub and LibStub("LibDBIcon-1.0", true)
  if not (ldb and icon) then
    return
  end
  db.minimapIcon = type(db.minimapIcon) == "table" and db.minimapIcon or {}
  local obj = ldb:NewDataObject(NAME, {
    type = "launcher",
    text = "Emberkeep",
    icon = "Interface\\AddOns\\Emberkeep\\Media\\emberkeep",
    OnClick = function(_, button)
      if IsControlKeyDown and IsControlKeyDown() then
        ns.App.OpenFeedback()
      elseif button == "RightButton" then
        ns.OptionsPage.Open()
      else
        ns.MainWindow.Toggle()
      end
    end,
    OnTooltipShow = function(tt)
      for i, line in ipairs(MinimapButton.TooltipLines(db, ns.Game.Now())) do
        if i == 1 then
          tt:AddLine(line, 0.73, 0.83, 0.96)
        else
          tt:AddLine(line, 1, 1, 1, true)
        end
      end
    end,
  })
  icon:Register(NAME, obj, db.minimapIcon)
  MinimapButton.Apply(db)
end

-- Matches the button to the "Show minimap button" option.
function MinimapButton.Apply(db)
  if not icon then
    return
  end
  db.minimapIcon.hide = not db.settings.minimapButton
  if db.minimapIcon.hide then
    icon:Hide(NAME)
  else
    icon:Show(NAME)
  end
end
