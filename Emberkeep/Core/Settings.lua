-- Settings: the options a player can change, with their defaults. Pure Lua.
local _, ns = ...
ns = ns or {}
local Settings = {}
ns.Settings = Settings

Settings.DEFAULTS = {
  minimapButton = true,
  loginHint = true,
  hideSurnames = false,
  locked = false,
  theme = "frost",
  scale = 1.0,
  errorPrompt = true,
  mailWarning = true, -- a chat line at login for mail about to expire
  panelTab = "gear", -- the alt panel's open tab
  gearList = false, -- gear as one list instead of two columns
}

Settings.SCALE_MIN, Settings.SCALE_MAX = 0.7, 1.5

-- Fills in any option the player hasn't set and pulls bad values back in
-- range, so the windows never read a nil or a scale of 0. themeKeys is a set
-- of the color schemes the window has; an unknown one falls back to the default.
function Settings.Apply(settings, themeKeys)
  for key, value in pairs(Settings.DEFAULTS) do
    if settings[key] == nil or type(settings[key]) ~= type(value) then
      settings[key] = value
    end
  end
  if themeKeys and not themeKeys[settings.theme] then
    settings.theme = Settings.DEFAULTS.theme
  end
  settings.scale = math.max(Settings.SCALE_MIN, math.min(Settings.SCALE_MAX, settings.scale))
  return settings
end

-- "100%" for the scale slider's label.
function Settings.ScaleLabel(scale)
  return string.format("%d%%", math.floor(scale * 100 + 0.5))
end

return Settings
