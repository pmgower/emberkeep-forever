-- MainWindow: the Emberkeep window. A tab per focus along the top, and the
-- active focus's table below. Each focus says what its columns are and builds
-- its rows from Core, so a new focus is a new entry in `focuses`, nothing else.
local _, ns = ...
local MainWindow = {}
ns.MainWindow = MainWindow

local ROW_H, TAB_H, TAB_GAP = 18, 20, 4
-- A bar column keeps BAR_TEXT px for its "150%" text; the rest is bar, up to BAR_MAX.
local BAR_TEXT, BAR_MAX = 50, 220
local GOLD, SILVER, COPPER, DIM = "|cffffd100", "|cffc7c7cf", "|cffeda55f", "|cff8f98a5"
local BLUE, WARN = "|cff4da6ff", "|cffe0a040"
-- Bar colors: full (wasting rest), filling in an inn, filling outside.
local BAR_FULL, BAR_INN, BAR_OUT = { 0.30, 0.65, 1 }, { 0.50, 0.78, 0.50 }, { 0.88, 0.63, 0.25 }

local function classColored(name, classFile)
  local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if c and c.colorStr then
    return "|c" .. c.colorStr .. name .. "|r"
  end
  return name
end

local function moneyText(m)
  local parts = {}
  if m.gold ~= "" then
    parts[#parts + 1] = GOLD .. m.gold .. "|r"
  end
  if m.silver ~= "" then
    parts[#parts + 1] = SILVER .. m.silver .. "|r"
  end
  if m.copper ~= "" then
    parts[#parts + 1] = COPPER .. m.copper .. "|r"
  end
  return #parts > 0 and table.concat(parts, " ") or (DIM .. "0|r")
end

-- Who the last Rested build said to play next, for the row tooltips.
local nextKey

local function restedBuild(db, now)
  local rows, summary = ns.RestedView.Build(db.characters, ns, ns.Game.RestContext(db, now))
  nextKey = summary.next and summary.next.key
  return rows, summary
end

local focuses = {
  {
    key = "rested",
    title = "Rested",
    columns = {
      { "", 20 },
      { "Character", 140, grow = 2 },
      { "Lvl", 34 },
      { "Rested", 130, grow = 1 },
      { "Full in", 64 },
      { "Resting", 70 },
      { "Zone", 130, grow = 1 },
    },
    bar = 4, -- the column that draws a fill bar before its text
    build = function(db, now)
      local rows, summary = restedBuild(db, now)
      local grid = {}
      for _, r in ipairs(rows) do
        grid[#grid + 1] = {
          key = r.key,
          fill = r.fill,
          color = r.full and BAR_FULL or (r.resting and BAR_INN or BAR_OUT),
          cells = {
            DIM .. r.rank .. "|r",
            classColored(r.name, r.classFile),
            r.level,
            (r.full and BLUE or "") .. r.percent .. "%" .. (r.full and "|r" or ""),
            r.full and (BLUE .. r.fullIn .. "|r") or r.fullIn,
            r.resting and (DIM .. "Inn|r") or (WARN .. "Outside|r"),
            r.zone,
          },
        }
      end
      if #grid == 0 then
        grid[1] = { cells = { "", DIM .. "No levelling alts yet|r" } }
      end
      return grid, ns.RestedView.RightText(summary)
    end,
  },
  {
    key = "overview",
    title = "Overview",
    columns = {
      { "Character", 150, grow = 2 },
      { "Lvl", 34 },
      { "Played", 70 },
      { "Gold", 100 },
      { "Zone", 130, grow = 1 },
      { "Last seen", 90 },
    },
    build = function(db, now)
      local rows, summary = ns.Overview.Build(
        db.characters,
        ns.Roster,
        ns.Format,
        now,
        { hideSurnames = db.settings.hideSurnames, currentKey = ns.Game.CurrentKey() },
        ns.Played
      )
      local grid = {}
      for _, r in ipairs(rows) do
        grid[#grid + 1] = {
          key = r.key,
          cells = {
            classColored(r.name, r.classFile),
            r.level,
            r.played,
            moneyText(r.money),
            r.zone,
            DIM .. r.seen .. "|r",
          },
        }
      end
      -- The account total gets its own row with no character name, so it
      -- can't be read as one character's gold.
      if #rows > 0 then
        grid[#grid + 1] = {
          cells = { DIM .. "All characters|r", "", summary.played, moneyText(summary.money), "", "" },
        }
      end
      return grid, summary.count == 1 and "1 alt" or (summary.count .. " alts")
    end,
  },
}

local win, tabs, cells, stripes, headerLine, hovers, bars = nil, {}, {}, {}, nil, {}, {}
local active = focuses[1]
-- The rows on screen, top to bottom, as character keys, and the selected row's mark.
local keys, selected = {}, nil

local function settings()
  return ns.db.settings
end

local function tooltip(owner, key)
  local c = ns.db.characters[key]
  if not c then
    return
  end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local shown = ns.Roster.DisplayName(c, settings().hideSurnames)
  GameTooltip:AddLine(classColored(shown, c.classFile))
  local who = string.format("Level %s %s %s", tostring(c.level or "?"), c.race or "", c.class or "")
  GameTooltip:AddLine(who, 0.79, 0.81, 0.84)
  local now = ns.Game.Now()
  local levelling = c.rest and (c.level or 0) < ns.Game.MaxLevel()
  if levelling then
    local p = ns.Rest.Project(c.rest, now, ns.db.wellRested)
    local pct = (p.full and math.floor(p.percent + 0.5) or math.floor(p.percent)) .. "%"
    GameTooltip:AddDoubleLine("Rested", p.full and (BLUE .. pct .. " (full)|r") or pct, 1, 0.82, 0, 1, 1, 1)
    if p.full then
      -- At least this long: a reading taken already full can't say when it filled.
      GameTooltip:AddDoubleLine("Full for", ns.Format.Duration(now - p.fullAt), 1, 0.82, 0, 1, 1, 1)
    else
      GameTooltip:AddDoubleLine("Full in", ns.Format.Duration(p.secondsToFull), 1, 0.82, 0, 1, 1, 1)
    end
    local rank = ns.db.wellRested or c.rest.wellRested or 0
    GameTooltip:AddDoubleLine("Well Rested", rank .. " / 5", 1, 0.82, 0, 1, 1, 1)
  end
  GameTooltip:AddDoubleLine("Gold", moneyText(ns.Format.Money(c.money)), 1, 0.82, 0)
  local played = ns.Played.Total(c, now, key == ns.Game.CurrentKey())
  if played then
    GameTooltip:AddDoubleLine("Played", ns.Format.Duration(played), 1, 0.82, 0, 1, 1, 1)
  end
  local place = ns.Format.Place(c)
  if place then
    local where = place
    if levelling then
      where = where .. (c.rest.resting and " (inn)" or " (outside)")
    end
    GameTooltip:AddDoubleLine("Last zone", where, 1, 0.82, 0, 1, 1, 1)
  end
  GameTooltip:AddDoubleLine("Last seen", ns.Format.Ago(c.lastSeen, now), 1, 0.82, 0, 1, 1, 1)
  if levelling and key == nextKey and ns.Rest.Project(c.rest, now, ns.db.wellRested).full then
    GameTooltip:AddLine("Rested XP past full is wasted: play " .. shown .. " next.", 0.62, 0.82, 1, true)
  end
  GameTooltip:AddLine("Click to see gear", 0.56, 0.6, 0.65)
  if MenuUtil and key ~= ns.Game.CurrentKey() then
    GameTooltip:AddLine("Right-click to remove", 0.56, 0.6, 0.65)
  end
  GameTooltip:Show()
end

local function cell(r, c)
  cells[r] = cells[r] or {}
  local fs = cells[r][c]
  if not fs then
    fs = win.content:CreateFontString(
      nil,
      "OVERLAY",
      r == 1 and "GameFontNormalSmall" or "GameFontHighlightSmall"
    )
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    cells[r][c] = fs
  end
  return fs
end

local function stripe(r)
  local t = stripes[r]
  if not t then
    t = win.content:CreateTexture(nil, "BACKGROUND")
    t:SetColorTexture(1, 1, 1, 0.04)
    stripes[r] = t
  end
  return t
end

-- A track and a fill texture per row, for a focus with a bar column.
local function bar(r)
  local b = bars[r]
  if not b then
    b =
      { track = win.content:CreateTexture(nil, "ARTWORK"), fill = win.content:CreateTexture(nil, "OVERLAY") }
    b.track:SetColorTexture(1, 1, 1, 0.08)
    bars[r] = b
  end
  return b
end

-- Right-click on a character's row: a menu with Remove. The All characters
-- row has no key, so it gets none.
local function rowMenu(owner)
  local key = owner.key
  local c = key and ns.db.characters[key]
  if not (c and MenuUtil and MenuUtil.CreateContextMenu) then
    return
  end
  GameTooltip:Hide()
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle(ns.Roster.DisplayName(c))
    if key == ns.Game.CurrentKey() then
      root:CreateTitle("You're on this character")
    else
      root:CreateButton("Remove", function()
        ns.CharactersPage.Remove(key)
      end)
    end
  end)
end

-- An invisible button per row for the hover tooltip, the alt panel (left-click)
-- and the right-click menu; it forwards drags so the window still moves when
-- grabbed by a row.
local function hover(r)
  local b = hovers[r]
  if not b then
    b = CreateFrame("Button", nil, win.content)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    win:AddHighlight(hl)
    b:SetScript("OnEnter", function(self)
      tooltip(self, self.key)
    end)
    b:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
      if button == "RightButton" then
        rowMenu(self)
      elseif self.key and ns.db.characters[self.key] then
        ns.AltPanel.Toggle(win, self.key)
      end
    end)
    win:ForwardDrag(b)
    hovers[r] = b
  end
  return b
end

local function buildTabs()
  local x = 0
  for i, focus in ipairs(focuses) do
    local t = tabs[i]
    if not t then
      t = CreateFrame("Button", nil, win.frame, "BackdropTemplate")
      t:SetHeight(TAB_H)
      t.label = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      t.label:SetPoint("CENTER")
      if t.SetBackdrop then
        t:SetBackdrop({
          edgeFile = "Interface\\Buttons\\WHITE8x8",
          bgFile = "Interface\\Buttons\\WHITE8x8",
          edgeSize = 1,
        })
      end
      t:SetScript("OnClick", function()
        active = focus
        settings().focus = focus.key
        MainWindow.Render()
      end)
      tabs[i] = t
    end
    t.label:SetText(focus.title)
    t:SetWidth(math.max(70, (t.label:GetStringWidth() or 50) + 24))
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", win.frame, "TOPLEFT", ns.Window.PAD + x, -(ns.Window.HEADER_H + 4))
    -- Above the scrolling rows, so a row scrolled under the strip can't take the click.
    t:SetFrameLevel((win.frame:GetFrameLevel() or 1) + 10)
    x = x + t:GetWidth() + TAB_GAP
  end
end

local function paintTabs()
  local e = ns.Window.Current().edge
  for i, focus in ipairs(focuses) do
    local t, on = tabs[i], focus == active
    if t.SetBackdropColor then
      t:SetBackdropColor(e[1], e[2], e[3], on and 0.22 or 0)
      t:SetBackdropBorderColor(e[1], e[2], e[3], on and 1 or 0.35)
    end
    if on then
      t.label:SetTextColor(0.9, 0.94, 1)
    else
      t.label:SetTextColor(0.56, 0.6, 0.65)
    end
  end
end

-- Room the columns can stretch into: none until the player resizes the
-- window (it fits the table until then), after that the inner width (the
-- vertical scroll bar sits in the window's padding, outside it).
local function stretchWidth()
  if not win.store.size then
    return 0
  end
  return win:ContentWidth() - 4
end

-- Marks the row of the alt the panel is showing.
function MainWindow.PaintSelected()
  if selected then
    selected:Hide()
  end
  local key = ns.AltPanel.Key()
  if not (win and key) then
    return
  end
  for _, b in pairs(hovers) do
    if b:IsShown() and b.key == key then
      selected = selected or win.content:CreateTexture(nil, "BACKGROUND")
      local e = ns.Window.Current().edge
      selected:SetColorTexture(e[1], e[2], e[3], 0.25)
      selected:ClearAllPoints()
      selected:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
      selected:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
      selected:Show()
    end
  end
end

function MainWindow.Keys()
  return keys
end

local function layout(grid)
  local content = win.content
  local widths, width = ns.Columns.Fit(active.columns, stretchWidth())
  for _, row in pairs(cells) do
    for _, fs in pairs(row) do
      fs:Hide()
    end
  end
  for _, t in pairs(stripes) do
    t:Hide()
  end
  for _, b in pairs(hovers) do
    b:Hide()
  end
  for _, b in pairs(bars) do
    b.track:Hide()
    b.fill:Hide()
  end
  local tr, tg, tb = ns.Window.Rgb(ns.Window.Current().title)
  local header = {}
  for i, col in ipairs(active.columns) do
    header[i] = col[1]
  end
  local lines = { { cells = header } }
  keys = {}
  for _, row in ipairs(grid) do
    lines[#lines + 1] = row
    keys[#keys + 1] = row.key -- rows without a character have none
  end
  for r, row in ipairs(lines) do
    local x, y = 2, -(r - 1) * ROW_H - (r > 1 and 4 or 0)
    if r > 1 then
      if r % 2 == 1 then
        local t = stripe(r)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y + 2)
        t:SetSize(width + 4, ROW_H)
        t:Show()
      end
      local b = hover(r)
      b.key = row.key
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y + 2)
      b:SetSize(width + 4, ROW_H)
      b:Show()
    end
    for c, text in ipairs(row.cells) do
      local w = widths[c]
      local fs = cell(r, c)
      local textX, textW = x, w - 6
      if r > 1 and c == active.bar and row.fill then
        local b = bar(r)
        b.track:ClearAllPoints()
        b.track:SetPoint("TOPLEFT", content, "TOPLEFT", x, y - 3)
        local barW = math.min(BAR_MAX, w - BAR_TEXT) -- the bar grows with its column
        b.track:SetSize(barW, 8)
        b.track:Show()
        local fillW = math.floor(barW * math.max(0, math.min(1, row.fill)) + 0.5)
        if fillW > 0 then
          b.fill:SetColorTexture(row.color[1], row.color[2], row.color[3], 1)
          b.fill:ClearAllPoints()
          b.fill:SetPoint("TOPLEFT", b.track, "TOPLEFT", 0, 0)
          b.fill:SetSize(fillW, 8)
          b.fill:Show()
        end
        textX, textW = x + barW + 6, w - barW - 12
      end
      fs:ClearAllPoints()
      fs:SetPoint("TOPLEFT", content, "TOPLEFT", textX, y)
      fs:SetWidth(textW)
      fs:SetText(text)
      fs:Show()
      if r == 1 then
        fs:SetTextColor(tr, tg, tb)
      end
      x = x + w
    end
  end
  headerLine = headerLine or content:CreateTexture(nil, "ARTWORK")
  local e = ns.Window.Current().edge
  headerLine:SetColorTexture(e[1], e[2], e[3], 0.45)
  headerLine:ClearAllPoints()
  headerLine:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -ROW_H + 2)
  headerLine:SetSize(width + 4, 1)
  local height = #lines * ROW_H + 8
  content:SetSize(width + 4, height)
  return width + 4, height
end

local function build()
  win = ns.Window.New({
    name = "EmberkeepMainWindow",
    title = "Emberkeep",
    store = settings().window,
    defaultPoint = { "CENTER", "CENTER", 0, 80 },
    defaultSize = { 520, 220 },
    bounds = { 300, 120, 1200, 900 },
    isLocked = function()
      return settings().locked
    end,
    onResize = function()
      if win and win.frame:IsShown() then
        MainWindow.Render()
      end
    end,
    onTheme = function()
      ns.AltPanel.ApplyTheme()
      if tabs[1] then
        paintTabs()
      end
    end,
  })
  MainWindow.ApplySettings()
  -- Room for the tab strip between the title bar and the table.
  local top = -(ns.Window.HEADER_H + 4 + TAB_H + 6)
  win.scroll:SetPoint("TOPLEFT", ns.Window.PAD, top)
  win.vbar:SetPoint("TOPRIGHT", -2, top) -- same inset as Window.lua's bars
  tinsert(UISpecialFrames, "EmberkeepMainWindow") -- Esc closes it
  win.frame:Hide()
  for _, focus in ipairs(focuses) do
    if focus.key == settings().focus then
      active = focus
    end
  end
  buildTabs()
end

local function render()
  local grid, right = active.build(ns.db, ns.Game.Now())
  win:UpdateGrip()
  win:SetRightText(right)
  paintTabs()
  local w, h = layout(grid)
  win:AutoFit(w, h + TAB_H + 6)
  ns.AltPanel.Refresh()
  MainWindow.PaintSelected()
end

-- Resizing calls back into Render while it lays out; the flag stops that
-- loop, and pcall makes sure one error can't leave the flag stuck on.
function MainWindow.Render()
  if MainWindow._inRender then
    return
  end
  MainWindow._inRender = true
  local ok, err = pcall(render)
  MainWindow._inRender = false
  if not ok then
    error(err, 0)
  end
end

function MainWindow.IsShown()
  return win ~= nil and win.frame:IsShown()
end

-- Theme, scale and lock from the options page.
function MainWindow.ApplySettings()
  if not win then
    return
  end
  ns.Window.SetTheme(settings().theme)
  local frame, new = win.frame, settings().scale
  local old = win.appliedScale
  win.appliedScale = new
  if old == nil or old == new then
    -- First build: the saved position was saved at this scale already.
    frame:SetScale(new)
  else
    -- Positions are in the frame's own scaled units, so convert the centre
    -- to screen units and back, or the window jumps when the scale changes.
    local x, y = frame:GetCenter()
    frame:SetScale(new)
    if x and y then
      frame:ClearAllPoints()
      frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * old / new, y * old / new)
      win:SavePosition()
    end
  end
  win:UpdateGrip()
end

function MainWindow.Toggle()
  if not win then
    build()
  end
  if win.frame:IsShown() then
    win.frame:Hide()
  else
    MainWindow.Render()
    win.frame:Show()
  end
end

function MainWindow.RefreshIfShown()
  if win and win.frame:IsShown() then
    MainWindow.Render()
  end
end

ns.App.OnChange(MainWindow.RefreshIfShown)
