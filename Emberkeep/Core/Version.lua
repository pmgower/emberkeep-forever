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
  return string.format("%s %s", title or "Emberkeep", version)
end

-- The short form the window header shows: "v0.1.0", or "dev".
function Version.Short(metadata)
  -- The packager fills in the tag, which already starts with "v" (v0.5.0).
  local version = Version.Line("", metadata):gsub("^%s+", ""):gsub("^[vV]", "")
  return version == "dev" and "dev" or ("v" .. version)
end

return Version
