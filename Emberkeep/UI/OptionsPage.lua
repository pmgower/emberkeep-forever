-- OptionsPage: Options > AddOns > Emberkeep. Each control writes straight into
-- EmberkeepDB.settings and tells the window, so the page and /emberkeep agree.
-- Saved characters have their own page under it (UI/CharactersPage.lua).
--
-- The page is Emberkeep's own panel (a canvas page), not built from the
-- Settings window's shared controls. Those controls are reused from page to
-- page, and once they had shown Emberkeep's options they carried its taint
-- onto Blizzard's pages: scrolling the Social page then failed with
-- "Emberkeep tried to call the protected function IsUserOAuthed()".
-- Skipped quietly on clients without canvas settings pages; the slash
-- commands still work.
local _, ns = ...
local OptionsPage = {}
ns.OptionsPage = OptionsPage

local CHECKBOXES = {
  {
    "minimapButton",
    "Show minimap button",
    "Left-click shows or hides the window, right-click opens this page, ctrl-click reports a bug.",
  },
  {
    "loginHint",
    "Suggest an alt at login",
    "When you log in, one chat line names the alt with the most rested XP to play next.",
  },
  { "hideSurnames", "First names only", "Show 'Jango' instead of 'Jango Fett'." },
  { "locked", "Lock window position and size", "Stops the window from being dragged or resized." },
  {
    "errorPrompt",
    "Offer a bug report on errors",
    "If Emberkeep hits an error, a small window offers to report it, once per session.",
  },
  {
    "mailWarning",
    "Warn about expiring mail",
    "When you log in, one chat line for each alt with items or gold in the mail that expires within 3 days.",
  },
}

local LEFT, CONTROL_X, ROW_H, TOP = 20, 260, 30, 60
local SCALE_STEP = 0.05

local category, page
-- The controls, by setting key, so the page can show the saved values when it
-- opens and specs can work them.
OptionsPage.controls = {}

local function settings()
  return ns.db.settings
end

local function changed()
  ns.MinimapButton.Apply(ns.db)
  ns.MainWindow.ApplySettings()
  ns.MainWindow.RefreshIfShown()
end

-- Saves one option and applies it.
function OptionsPage.Set(key, value)
  settings()[key] = value
  changed()
  OptionsPage.Refresh()
end

local function label(text, y)
  local fs = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT, y)
  fs:SetText(text)
  return fs
end

local function tooltip(frame, title, text)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

local function button(text, width)
  local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  return b
end

local function addCheckbox(row, y)
  local key, text, help = row[1], row[2], row[3]
  label(text, y - 6)
  local box = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  box:SetPoint("TOPLEFT", page, "TOPLEFT", CONTROL_X, y)
  box:SetScript("OnClick", function(self)
    OptionsPage.Set(key, self:GetChecked() and true or false)
  end)
  tooltip(box, text, help)
  box.refresh = function()
    box:SetChecked(settings()[key] and true or false)
  end
  OptionsPage.controls[key] = box
end

-- A value with a button either side: the color scheme and the window scale.
local function addStepper(key, text, help, y, show, step)
  label(text, y - 4)
  local back, forward = button("<", 28), button(">", 28)
  back:SetPoint("TOPLEFT", page, "TOPLEFT", CONTROL_X, y)
  local value = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  value:SetPoint("LEFT", back, "RIGHT", 8, 0)
  value:SetWidth(120)
  forward:SetPoint("LEFT", value, "RIGHT", 8, 0)
  back:SetScript("OnClick", function()
    OptionsPage.Set(key, step(settings()[key], -1))
  end)
  forward:SetScript("OnClick", function()
    OptionsPage.Set(key, step(settings()[key], 1))
  end)
  tooltip(back, text, help)
  tooltip(forward, text, help)
  local control = { back = back, forward = forward, value = value }
  control.refresh = function()
    value:SetText(show(settings()[key]))
  end
  OptionsPage.controls[key] = control
end

-- The next color scheme along, wrapping round.
local function stepTheme(current, by)
  local themes, at = ns.Window.THEMES, 1
  for i, t in ipairs(themes) do
    if t.key == current then
      at = i
    end
  end
  return themes[(at - 1 + by) % #themes + 1].key
end

local function themeName(key)
  for _, t in ipairs(ns.Window.THEMES) do
    if t.key == key then
      return t.name
    end
  end
  return tostring(key)
end

local function stepScale(current, by)
  local scale = (tonumber(current) or 1) + by * SCALE_STEP
  scale = math.floor(scale / SCALE_STEP + 0.5) * SCALE_STEP
  return math.max(ns.Settings.SCALE_MIN, math.min(ns.Settings.SCALE_MAX, scale))
end

local function build()
  page = CreateFrame("Frame")
  local title = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", LEFT, -16)
  title:SetText("Emberkeep")
  local y = -TOP
  for _, row in ipairs(CHECKBOXES) do
    addCheckbox(row, y)
    y = y - ROW_H
  end
  addStepper("theme", "Color scheme", "Colors for the Emberkeep window.", y - 4, themeName, stepTheme)
  y = y - ROW_H - 4
  local scaleHelp = "Size of the Emberkeep window."
  addStepper("scale", "Window scale", scaleHelp, y - 4, ns.Settings.ScaleLabel, stepScale)
  y = y - ROW_H - 12
  local report = button("Report a bug", 160)
  report:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT, y)
  report:SetScript("OnClick", function()
    ns.App.OpenFeedback()
  end)
  local reportHelp = "Opens a link to a GitHub bug report with your details filled in."
    .. " Same as /emberkeep feedback."
  tooltip(report, "Report a bug", reportHelp)
  OptionsPage.reportButton = report
  page:SetScript("OnShow", OptionsPage.Refresh)
end

-- Shows the saved values, when the page opens and after a change.
function OptionsPage.Refresh()
  if not (page and ns.db) then
    return
  end
  for _, control in pairs(OptionsPage.controls) do
    control.refresh()
  end
end

function OptionsPage.Init()
  if not (Settings and Settings.RegisterCanvasLayoutCategory) then
    return
  end
  build()
  category = Settings.RegisterCanvasLayoutCategory(page, "Emberkeep")
  ns.CharactersPage.Init(category)
  Settings.RegisterAddOnCategory(category)
  OptionsPage.Refresh()
end

function OptionsPage.Open()
  if category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(category:GetID())
    return true
  end
  DEFAULT_CHAT_FRAME:AddMessage(
    "|cff9fd0ffEmberkeep:|r the options page isn't available; type /emberkeep help"
  )
  return false
end
