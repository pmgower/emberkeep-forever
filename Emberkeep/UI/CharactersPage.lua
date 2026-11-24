-- CharactersPage: Options > AddOns > Emberkeep > Characters. A table of every
-- saved character (name, level, class, last seen) with a Remove button on
-- each row. Rebuilt each time the page opens, so it always matches the
-- saved list. Skipped quietly on clients without canvas settings pages.
local _, ns = ...
local CharactersPage = {}
ns.CharactersPage = CharactersPage

local ROW_H, TOP = 24, 56
local DIM = "|cff8f98a5"
-- x offset of each column, then the Remove button.
local COLS = { name = 16, level = 210, class = 250, seen = 350, button = 450 }

local page, child, rows, empty = nil, nil, {}, nil

local function classColored(name, classFile)
  local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if c and c.colorStr then
    return "|c" .. c.colorStr .. name .. "|r"
  end
  return name
end

local function text(parent, x, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
  fs:SetPoint("LEFT", parent, "LEFT", x, 0)
  fs:SetJustifyH("LEFT")
  return fs
end

-- Removes the character on a row, unless it's the one you're logged in on
-- (they'd be added straight back).
function CharactersPage.Remove(key)
  local c = ns.db.characters[key]
  if not c then
    return false
  end
  local who = ns.Roster.DisplayName(c)
  if key == ns.Game.CurrentKey() then
    ns.Say("you're logged in on " .. who .. ", so they'd be added straight back.")
    return false
  end
  ns.Roster.ForgetKey(ns.db.characters, key)
  ns.Say("removed " .. who)
  ns.MainWindow.RefreshIfShown()
  CharactersPage.Refresh()
  return true
end

local function makeRow(i)
  local r = CreateFrame("Frame", nil, child)
  r:SetSize(COLS.button + 90, ROW_H)
  r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * ROW_H)
  r.name = text(r, COLS.name)
  r.level = text(r, COLS.level)
  r.class = text(r, COLS.class)
  r.seen = text(r, COLS.seen)
  r.button = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
  r.button:SetSize(80, 20)
  r.button:SetPoint("LEFT", r, "LEFT", COLS.button, 0)
  r.button:SetText("Remove")
  r.button:SetScript("OnClick", function()
    CharactersPage.Remove(r.key)
  end)
  return r
end

-- Redraws the table from the saved characters.
function CharactersPage.Refresh()
  if not (page and ns.db) then
    return
  end
  local list = ns.Roster.Characters(ns.db.characters)
  local current, now = ns.Game.CurrentKey(), ns.Game.Now()
  for i, ch in ipairs(list) do
    local r = rows[i] or makeRow(i)
    rows[i] = r
    r.key = ch.key
    local name = classColored(ns.Roster.DisplayName(ch), ch.classFile)
    r.name:SetText(ch.key == current and (name .. DIM .. " (you)|r") or name)
    r.level:SetText(tostring(ch.level or "?"))
    r.class:SetText(ch.class or "")
    r.seen:SetText(DIM .. ns.Format.Ago(ch.lastSeen, now) .. "|r")
    if ch.key == current then
      r.button:Disable()
    else
      r.button:Enable()
    end
    r:Show()
  end
  for i = #list + 1, #rows do
    rows[i]:Hide()
  end
  child:SetHeight(math.max(1, #list * ROW_H))
  if #list == 0 then
    empty:Show()
  else
    empty:Hide()
  end
end

local function build()
  page = CreateFrame("Frame")
  local title = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Saved characters")
  local note = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  note:SetText("Remove characters you deleted. They come back if you log in on them again.")
  local header = CreateFrame("Frame", nil, page)
  header:SetSize(COLS.button + 90, 18)
  header:SetPoint("TOPLEFT", 0, -TOP)
  for col, label in pairs({ name = "Character", level = "Lvl", class = "Class", seen = "Last seen" }) do
    text(header, COLS[col], "GameFontNormalSmall"):SetText(label)
  end
  local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -(TOP + 22))
  scroll:SetPoint("BOTTOMRIGHT", -30, 10)
  child = CreateFrame("Frame", nil, scroll)
  child:SetSize(COLS.button + 90, 1)
  scroll:SetScrollChild(child)
  empty = text(child, COLS.name, "GameFontDisableSmall")
  empty:SetPoint("TOPLEFT", child, "TOPLEFT", COLS.name, -4)
  empty:SetText("No characters saved yet.")
  page:SetScript("OnShow", CharactersPage.Refresh)
end

-- Adds the page under the Emberkeep category.
function CharactersPage.Init(category)
  if not (Settings and Settings.RegisterCanvasLayoutSubcategory and category) then
    return
  end
  build()
  Settings.RegisterCanvasLayoutSubcategory(category, page, "Characters")
end
