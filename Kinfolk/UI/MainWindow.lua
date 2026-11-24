-- MainWindow: the Kinfolk window. A tab per focus along the top, and the
-- active focus's table below. Each focus says what its columns are and builds
-- its rows from Core, so a new focus is a new entry in `focuses`, nothing else.
local _, ns = ...
local MainWindow = {}
ns.MainWindow = MainWindow

local ROW_H, TAB_H, TAB_GAP = 18, 20, 4
local GOLD, SILVER, COPPER, DIM = "|cffffd100", "|cffc7c7cf", "|cffeda55f", "|cff8f98a5"

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

local focuses = {
  {
    key = "overview",
    title = "Overview",
    columns = { { "Character", 150 }, { "Lvl", 34 }, { "Gold", 100 }, { "Zone", 130 }, { "Last seen", 90 } },
    build = function(db, now)
      local rows, summary = ns.Overview.Build(db.characters, ns.Roster, ns.Format, now)
      local grid = {}
      for _, r in ipairs(rows) do
        grid[#grid + 1] = {
          key = r.key,
          cells = {
            classColored(r.name, r.classFile),
            r.level,
            moneyText(r.money),
            r.zone,
            DIM .. r.seen .. "|r",
          },
        }
      end
      local right = summary.count == 1 and "1 alt" or (summary.count .. " alts")
      if summary.money.gold ~= "" then
        right = right .. "  " .. GOLD .. summary.money.gold .. "|r"
      end
      return grid, right
    end,
  },
}

local win, tabs, cells, stripes, headerLine, hovers = nil, {}, {}, {}, nil, {}
local active = focuses[1]

local function settings()
  return ns.db.settings
end

local function tooltip(owner, key)
  local c = ns.db.characters[key]
  if not c then
    return
  end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(classColored(c.name, c.classFile))
  local who = string.format("Level %s %s %s", tostring(c.level or "?"), c.race or "", c.class or "")
  GameTooltip:AddLine(who, 0.79, 0.81, 0.84)
  GameTooltip:AddDoubleLine("Gold", moneyText(ns.Format.Money(c.money)), 1, 0.82, 0)
  if c.zone then
    GameTooltip:AddDoubleLine("Last zone", c.zone, 1, 0.82, 0, 1, 1, 1)
  end
  GameTooltip:AddDoubleLine("Last seen", ns.Format.Ago(c.lastSeen, ns.Game.Now()), 1, 0.82, 0, 1, 1, 1)
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

-- An invisible button per row for the hover tooltip; it forwards drags so the
-- window still moves when grabbed by a row.
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

local function layout(grid)
  local content = win.content
  local width = 0
  for _, col in ipairs(active.columns) do
    width = width + col[2]
  end
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
  local tr, tg, tb = ns.Window.Rgb(ns.Window.Current().title)
  local header = {}
  for i, col in ipairs(active.columns) do
    header[i] = col[1]
  end
  local lines = { { cells = header } }
  for _, row in ipairs(grid) do
    lines[#lines + 1] = row
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
      local w = active.columns[c][2]
      local fs = cell(r, c)
      fs:ClearAllPoints()
      fs:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
      fs:SetWidth(w - 6)
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
    name = "KinfolkMainWindow",
    title = "Kinfolk",
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
  tinsert(UISpecialFrames, "KinfolkMainWindow") -- Esc closes it
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
  win.frame:SetScale(settings().scale)
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
