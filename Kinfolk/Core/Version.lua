-- Version: formats the line the slash command prints. Pure Lua: no WoW API.
local _, ns = ...
ns = ns or {}
local Version = {}
ns.Version = Version

-- metadata is whatever the TOC reported; anything missing reads "dev" so a
-- checkout run straight from git still says something useful.
function Version.Line(title, metadata)
  local version = metadata and metadata ~= "" and metadata or "dev"
  return string.format("%s %s", title or "Kinfolk", version)
end

return Version
