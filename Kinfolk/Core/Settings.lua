-- Settings: the options a player can change, with their defaults. Pure Lua.
local _, ns = ...
ns = ns or {}
local Settings = {}
ns.Settings = Settings

Settings.DEFAULTS = {
  minimapButton = true,
  locked = false,
  theme = "frost",
  scale = 1.0,
}

Settings.SCALE_MIN, Settings.SCALE_MAX = 0.7, 1.5

-- Fills in any option the player hasn't set and pulls bad values back in
-- range, so the windows never read a nil or a scale of 0.
function Settings.Apply(settings)
  for key, value in pairs(Settings.DEFAULTS) do
    if settings[key] == nil or type(settings[key]) ~= type(value) then
      settings[key] = value
    end
  end
  settings.scale = math.max(Settings.SCALE_MIN, math.min(Settings.SCALE_MAX, settings.scale))
  return settings
end

-- "100%" for the scale slider's label.
function Settings.ScaleLabel(scale)
  return string.format("%d%%", math.floor(scale * 100 + 0.5))
end

return Settings
