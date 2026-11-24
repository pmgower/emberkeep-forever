-- OptionsPage: Options > AddOns > Kinfolk. Each control writes straight into
-- KinfolkDB.settings and tells the window, so the page and /kinfolk agree.
-- Every part checks the client has that Settings API first and is skipped
-- quietly if not; the slash commands still work.
local _, ns = ...
local OptionsPage = {}
ns.OptionsPage = OptionsPage

local category

local CHECKBOXES = {
  {
    "minimapButton",
    "Show minimap button",
    "Left-click shows or hides the window, right-click opens this page.",
  },
  { "locked", "Lock window position and size", "Stops the window from being dragged or resized." },
}

local function register(cat, key, kind, label, default, onChange)
  local setting =
    Settings.RegisterAddOnSetting(cat, "Kinfolk_" .. key, key, ns.db.settings, kind, label, default)
  if setting.SetValueChangedCallback then
    setting:SetValueChangedCallback(function()
      onChange()
    end)
  end
  return setting
end

local function changed()
  ns.MinimapButton.Apply(ns.db)
  ns.MainWindow.ApplySettings()
end

local function addTheme(cat)
  local create = Settings.CreateDropdown or Settings.CreateDropDown
  if not (create and Settings.CreateControlTextContainer) then
    return
  end
  local setting = register(cat, "theme", "string", "Color scheme", ns.Settings.DEFAULTS.theme, changed)
  create(cat, setting, function()
    local c = Settings.CreateControlTextContainer()
    for _, t in ipairs(ns.Window.THEMES) do
      c:Add(t.key, t.name)
    end
    return c:GetData()
  end, "Colors for the Kinfolk window.")
end

local function addScale(cat)
  if not (Settings.CreateSlider and Settings.CreateSliderOptions) then
    return
  end
  local setting = register(cat, "scale", "number", "Window scale", ns.Settings.DEFAULTS.scale, changed)
  local options = Settings.CreateSliderOptions(ns.Settings.SCALE_MIN, ns.Settings.SCALE_MAX, 0.05)
  local mixin = MinimalSliderWithSteppersMixin
  if options.SetLabelFormatter and mixin and mixin.Label then
    options:SetLabelFormatter(mixin.Label.Right, ns.Settings.ScaleLabel)
  end
  Settings.CreateSlider(cat, setting, options, "Size of the Kinfolk window.")
end

-- A dropdown of saved characters and a Forget button.
local function addForget(cat, layout)
  local create = Settings.CreateDropdown or Settings.CreateDropDown
  if not (create and Settings.CreateControlTextContainer and layout and CreateSettingsButtonInitializer) then
    return
  end
  local pick = { forget = "" }
  local setting =
    Settings.RegisterAddOnSetting(cat, "Kinfolk_forget", "forget", pick, "string", "Character", "")
  create(cat, setting, function()
    local c = Settings.CreateControlTextContainer()
    for _, ch in ipairs(ns.Roster.Characters(ns.db.characters)) do
      c:Add(ch.name, string.format("%s (%s)", ch.name, tostring(ch.level or "?")))
    end
    return c:GetData()
  end, "Pick a character you deleted or don't want listed, then press Forget.")
  layout:AddInitializer(CreateSettingsButtonInitializer("", "Forget", function()
    if pick.forget ~= "" then
      SlashCmdList.KINFOLK("forget " .. pick.forget)
      pick.forget = ""
    end
  end, "Removes the picked character from Kinfolk. They come back if you log in on them again.", true))
end

function OptionsPage.Init()
  if not (Settings and Settings.RegisterVerticalLayoutCategory) then
    return
  end
  local layout
  category, layout = Settings.RegisterVerticalLayoutCategory("Kinfolk")
  for _, row in ipairs(CHECKBOXES) do
    local setting = register(category, row[1], "boolean", row[2], ns.Settings.DEFAULTS[row[1]], changed)
    Settings.CreateCheckbox(category, setting, row[3])
  end
  addTheme(category)
  addScale(category)
  addForget(category, layout)
  Settings.RegisterAddOnCategory(category)
end

function OptionsPage.Open()
  if category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(category:GetID())
    return true
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cff9fd0ffKinfolk:|r the options page isn't available; type /kinfolk help")
  return false
end
