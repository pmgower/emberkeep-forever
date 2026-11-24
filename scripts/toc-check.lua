-- Every file a .toc lists must exist, and every .lua under the addon must be
-- listed (an unlisted file silently never loads in game).
local failed = false
local function fail(msg)
  io.stderr:write("toc-check: " .. msg .. "\n")
  failed = true
end

local toc = arg[1] or "Kinfolk/Kinfolk.toc"
local dir = toc:match("^(.*)/[^/]+$") or "."
local listed = {}
for line in io.lines(toc) do
  line = line:gsub("\r$", "")
  if line ~= "" and not line:match("^#") then
    local path = dir .. "/" .. line:gsub("\\", "/")
    listed[path] = true
    local f = io.open(path, "r")
    if f then
      f:close()
    else
      fail(toc .. " lists " .. line .. " but the file does not exist")
    end
  end
end
local p = io.popen('find "' .. dir .. '" -name "*.lua" -not -path "*/Libs/*"')
for path in p:lines() do
  if not listed[path] then
    fail(path .. " is not listed in " .. toc)
  end
end
p:close()
if failed then
  os.exit(1)
end
print("toc-check: ok")
