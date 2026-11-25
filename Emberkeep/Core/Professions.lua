-- Professions: each character's profession skills, as a table with a column per
-- profession. Pure Lua. The adapter hands over a reading of the skill list;
-- this keeps the last good one.
local _, ns = ...
ns = ns or {}
local Professions = {}
ns.Professions = Professions

-- Every profession gets a column, so one nobody has shows up as missing.
-- Keyed by skill line, which is the same in every language. short is the
-- column title; the full one shows when it's hovered.
Professions.STANDARD = {
  { line = 171, title = "Alchemy", short = "Alch" },
  { line = 164, title = "Blacksmithing", short = "Smith" },
  { line = 333, title = "Enchanting", short = "Ench" },
  { line = 202, title = "Engineering", short = "Eng" },
  { line = 182, title = "Herbalism", short = "Herb" },
  { line = 165, title = "Leatherworking", short = "Leather" },
  { line = 186, title = "Mining", short = "Mining" },
  { line = 393, title = "Skinning", short = "Skin" },
  { line = 197, title = "Tailoring", short = "Tailor" },
  { line = 185, title = "Cooking", short = "Cook" },
  { line = 356, title = "Fishing", short = "Fish" },
  { line = 129, title = "First Aid", short = "Aid" },
}

-- The column a profession belongs in: its standard title, or its own name for
-- one that isn't in the list.
function Professions.Key(line, name)
  for _, p in ipairs(Professions.STANDARD) do
    if p.line == line or p.title == name then
      return p.title
    end
  end
  return name
end

-- reading: { list = { { line, name, skill, max }, ... }, unread = true when one
-- couldn't be read }. Saves it on the character and returns true if it changed
-- anything. A partial reading is ignored, and an empty one never replaces
-- skills: it would look like professions were dropped. settled says the game
-- has had time to load, so an empty list can mean a character with none.
function Professions.Observe(c, reading, now, settled)
  if not reading or reading.unread then
    return false
  end
  local old = c.professions and c.professions.skills
  if #reading.list == 0 and (old and next(old) or not settled) then
    return false
  end
  local skills, count, same = {}, 0, old ~= nil
  for _, p in ipairs(reading.list) do
    local key = Professions.Key(p.line, p.name)
    local was = old and old[key]
    same = same and was ~= nil and was.skill == p.skill and was.max == p.max
    skills[key] = { name = p.name, skill = p.skill, max = p.max }
    count = count + 1
  end
  for _ in pairs(old or {}) do
    count = count - 1
  end
  c.professions = { skills = skills, at = now }
  return not same or count ~= 0
end

-- "142/150", or just "142" when the limit isn't known.
function Professions.Text(p)
  if p.max and p.max > 0 then
    return p.skill .. "/" .. p.max
  end
  return tostring(p.skill)
end

-- Columns: { key, title, short, missing = no character has it }, the standard
-- ones first, then any others by name. The title is the game's own name for it
-- when a character has it, so it's in the player's language; only an English
-- one is shortened.
function Professions.Columns(characters)
  local names = {}
  for _, c in ipairs(characters) do
    for key, p in pairs(c.professions and c.professions.skills or {}) do
      names[key] = p.name
    end
  end
  local columns = {}
  for _, p in ipairs(Professions.STANDARD) do
    local title = names[p.title] or p.title
    columns[#columns + 1] = {
      key = p.title,
      title = title,
      short = title == p.title and p.short or title,
      missing = not names[p.title],
    }
    names[p.title] = nil
  end
  local others = {}
  for key, name in pairs(names) do
    others[#others + 1] = { key = key, title = name, short = name, missing = false }
  end
  table.sort(others, function(a, b)
    return a.title < b.title
  end)
  for _, column in ipairs(others) do
    columns[#columns + 1] = column
  end
  return columns
end

-- Sorts by one column's skill, characters without it always last. Those that
-- tie keep the order they came in.
local function sortBy(rows, key, ascending)
  for i, row in ipairs(rows) do
    row.order = i
  end
  table.sort(rows, function(a, b)
    local x, y = a.skills and a.skills[key], b.skills and b.skills[key]
    if x and y and x.skill ~= y.skill then
      if ascending then
        return x.skill < y.skill
      end
      return x.skill > y.skill
    elseif (x ~= nil) ~= (y ~= nil) then
      return x ~= nil
    end
    return a.order < b.order
  end)
end

-- sort: { key = column key, ascending } or nil for highest level first.
-- Returns columns and rows: { key, name, classFile, level, skills = { [column
-- key] = { name, skill, max } } or nil when never read }.
function Professions.Build(store, Roster, opts)
  local characters = Roster.Characters(store)
  local rows = {}
  for _, c in ipairs(characters) do
    rows[#rows + 1] = {
      key = c.key,
      name = Roster.DisplayName(c, opts and opts.hideSurnames),
      classFile = c.classFile,
      level = c.level and tostring(c.level) or "?",
      skills = c.professions and c.professions.skills,
    }
  end
  local sort = opts and opts.sort
  if sort then
    sortBy(rows, sort.key, sort.ascending)
  end
  return Professions.Columns(characters), rows
end

-- What clicking a column title does: highest first, then lowest first, then
-- back to by level (nil).
function Professions.NextSort(sort, key)
  if not sort or sort.key ~= key then
    return { key = key, ascending = false }
  elseif not sort.ascending then
    return { key = key, ascending = true }
  end
  return nil
end

return Professions
