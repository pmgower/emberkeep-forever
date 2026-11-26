-- OptionsPage: Options > AddOns > Emberkeep. Each control writes straight into
-- EmberkeepDB.settings and tells the window, so the page and /emberkeep agree.
-- Saved characters have their own page under it (UI/CharactersPage.lua).
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

local function register(cat, key, kind, label, default, onChange)
  local setting =
    Settings.RegisterAddOnSetting(cat, "Emberkeep_" .. key, key, ns.db.settings, kind, label, default)
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
  ns.MainWindow.RefreshIfShown()
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
  end, "Colors for the Emberkeep window.")
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
  Settings.CreateSlider(cat, setting, options, "Size of the Emberkeep window.")
end

function OptionsPage.Init()
  if not (Settings and Settings.RegisterVerticalLayoutCategory) then
    return
  end
  local layout
  category, layout = Settings.RegisterVerticalLayoutCategory("Emberkeep")
  for _, row in ipairs(CHECKBOXES) do
    local setting = register(category, row[1], "boolean", row[2], ns.Settings.DEFAULTS[row[1]], changed)
    Settings.CreateCheckbox(category, setting, row[3])
  end
  addTheme(category)
  addScale(category)
  if layout and CreateSettingsButtonInitializer then
    layout:AddInitializer(
      CreateSettingsButtonInitializer(
        "",
        "Report a bug",
        function()
          ns.App.OpenFeedback()
        end,
        "Opens a link to a GitHub bug report with your details filled in. Same as /emberkeep feedback.",
        true
      )
    )
  end
  ns.CharactersPage.Init(category)
  Settings.RegisterAddOnCategory(category)
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
