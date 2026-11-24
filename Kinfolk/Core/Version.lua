-- Version: formats the line the slash command prints. Pure Lua: no WoW API.
local _, ns = ...
ns = ns or {}
local Version = {}
ns.Version = Version

-- metadata is whatever the TOC reported. The packager swaps @project-version@
-- for the tag; a checkout run straight from git still has the token, or nothing,
-- and reads "dev".
function Version.Line(title, metadata)
  local version = "dev"
  if metadata and metadata ~= "" and not metadata:match("^@.*@$") then
    version = metadata
  end
  return string.format("%s %s", title or "Kinfolk", version)
end

return Version
