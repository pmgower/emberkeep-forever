-- AltPanel: one alt up close, docked beside the main window. It shows gear
-- now; bags, bank and mail will share it. It's a child of the main window, so
-- it moves, scales and closes with it.
local _, ns = ...
local AltPanel = {}
ns.AltPanel = AltPanel

local WIDE, NARROW, HEADER_H, PAD = 400, 240, 24, 10
local SLOT_H, ICON = 34, 28
local DIM, WARN = "|cff8f98a5", "|cffe0a040"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local win, panel, shownKey
local buttons = {}

local function settings()
  return ns.db.settings
end

local function classColored(name, classFile)
  local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  return c and c.colorStr and ("|c" .. c.colorStr .. name .. "|r") or name
end

local function textButton(label, width, onClick)
  local b = CreateFrame("Button", nil, panel, "BackdropTemplate")
  b:SetSize(width, 18)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.label:SetPoint("CENTER")
  b.label:SetText(label)
  if b.SetBackdrop then
    b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  end
  b:SetScript("OnClick", onClick)
  return b
end

local function build(window)
  win = window
  panel = CreateFrame("Frame", "EmberkeepAltPanel", win.frame, "BackdropTemplate")
  panel:SetFrameLevel((win.frame:GetFrameLevel() or 1) + 10)
  if panel.SetBackdrop then
    panel:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
  end
  win:ForwardDrag(panel)
  panel.close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  panel.close:SetSize(20, 20)
  panel.close:SetPoint("TOPRIGHT", -2, -3)
  panel.close:SetScript("OnClick", function()
    AltPanel.Close()
  end)
  panel.next = textButton("Down", 40, function()
    AltPanel.Step(1)
  end)
  panel.next:SetPoint("RIGHT", panel.close, "LEFT", -2, 0)
  panel.prev = textButton("Up", 30, function()
    AltPanel.Step(-1)
  end)
  panel.prev:SetPoint("RIGHT", panel.next, "LEFT", -3, 0)
  panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  panel.title:SetPoint("TOPLEFT", PAD, -8)
  panel.title:SetPoint("RIGHT", panel.prev, "LEFT", -6, 0)
  panel.title:SetJustifyH("LEFT")
  panel.title:SetWordWrap(false)
  panel.line = panel:CreateTexture(nil, "ARTWORK")
  panel.line:SetPoint("TOPLEFT", 4, -HEADER_H)
  panel.line:SetPoint("TOPRIGHT", -4, -HEADER_H)
  panel.line:SetHeight(1)
  panel.summary = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.summary:SetPoint("TOPLEFT", PAD, -(HEADER_H + 9))
  panel.view = textButton("", 80, function()
    settings().gearList = not settings().gearList
    AltPanel.Refresh()
  end)
  panel.view:SetPoint("TOPRIGHT", -PAD, -(HEADER_H + 5))
  panel.asOf = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  panel.asOf:SetPoint("BOTTOMLEFT", PAD, 9)
  panel.asOf:SetJustifyH("LEFT")
  AltPanel.ApplyTheme()
end

local function slotButton(id)
  local b = buttons[id]
  if not b then
    b = CreateFrame("Button", nil, panel)
    b:SetHeight(SLOT_H)
    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetSize(ICON + 2, ICON + 2)
    b.border:SetPoint("LEFT", 0, 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(ICON, ICON)
    b.icon:SetPoint("CENTER", b.border, "CENTER")
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.name:SetPoint("TOPLEFT", b.border, "TOPRIGHT", 6, -2)
    b.name:SetPoint("RIGHT", b, "RIGHT", -2, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.detail = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.detail:SetPoint("BOTTOMLEFT", b.border, "BOTTOMRIGHT", 6, 2)
    b.detail:SetJustifyH("LEFT")
    b:SetScript("OnEnter", function(self)
      if self.link then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(self)
      if self.link then
        ns.Items.ModifiedClick(self.link)
      end
    end)
    win:ForwardDrag(b)
    buttons[id] = b
  end
  return b
end

local function paintSlot(id, row)
  local b = slotButton(id)
  b.link = row.link or false
  local detail = row.label
  if row.link then
    b.icon:SetTexture(row.icon or QUESTION)
    b.icon:Show()
    b.name:SetText(ns.Items.Colored(row.name, row.quality))
    if row.itemLevel then
      detail = detail .. "  " .. row.itemLevel
    end
    if row.outleveled then
      detail = detail .. "  " .. WARN .. "outleveled|r"
    end
  else
    b.icon:Hide()
    b.name:SetText(DIM .. (row.usedByTwoHander and "Two-handed weapon" or "Empty") .. "|r")
  end
  b.detail:SetText(detail)
  local r, g, bl = ns.Items.Rgb(row.quality)
  b.border:SetColorTexture(r or 0.3, g or 0.35, bl or 0.4, row.link and 1 or 0.35)
  return b
end

local function place(b, x, y, width)
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
  b:SetWidth(width)
  b:Show()
end

-- Draws the slots and returns how tall they are.
local function layoutGear(view, list, width)
  local top = -(HEADER_H + 30)
  if list then
    for i, slot in ipairs(ns.Gear.SLOTS) do
      place(paintSlot(slot.id, view.slots[slot.id]), PAD, top - (i - 1) * SLOT_H, width - PAD * 2)
    end
    return #ns.Gear.SLOTS * SLOT_H
  end
  local column = (width - PAD * 2 - 8) / 2
  for i, id in ipairs(ns.Gear.LEFT) do
    place(paintSlot(id, view.slots[id]), PAD, top - (i - 1) * SLOT_H, column)
  end
  for i, id in ipairs(ns.Gear.RIGHT) do
    place(paintSlot(id, view.slots[id]), PAD + column + 8, top - (i - 1) * SLOT_H, column)
  end
  return math.max(#ns.Gear.LEFT, #ns.Gear.RIGHT) * SLOT_H
end

-- To the right of the window, or to its left when the right has no room.
local function dock(width)
  local num = ns.Window.Num
  local right, left = num(win.frame:GetRight(), 0), num(win.frame:GetLeft(), 0)
  local scale = num(win.frame:GetEffectiveScale(), 1)
  if scale <= 0 then
    scale = 1
  end
  local screen = num(UIParent:GetWidth(), 0) * num(UIParent:GetEffectiveScale(), 1) / scale
  panel:ClearAllPoints()
  if right + width > screen and left > width then
    panel:SetPoint("TOPRIGHT", win.frame, "TOPLEFT", 2, 0)
  else
    panel:SetPoint("TOPLEFT", win.frame, "TOPRIGHT", -2, 0)
  end
end

function AltPanel.Refresh()
  if not (panel and shownKey) then
    return
  end
  local c = ns.db.characters[shownKey]
  if not c then
    return AltPanel.Close() -- removed while open
  end
  for _, b in pairs(buttons) do
    b:Hide()
  end
  local list = settings().gearList
  local width = list and NARROW or WIDE
  local name = classColored(ns.Roster.DisplayName(c, settings().hideSurnames), c.classFile)
  panel.title:SetText(name .. DIM .. "  " .. tostring(c.level or "?") .. " " .. (c.class or "") .. "|r")
  panel.view.label:SetText(list and "Two columns" or "List")
  local view = ns.Gear.View(c, ns.Items.Info)
  local height = SLOT_H
  if view then
    panel.summary:SetText(ns.Gear.Summary(view))
    panel.asOf:SetText("Gear as of " .. ns.Format.Ago(view.at, ns.Game.Now()))
    panel.view:Show()
    height = layoutGear(view, list, width)
  else
    panel.summary:SetText(DIM .. "No gear saved yet|r")
    panel.asOf:SetText("Log in here once to save it.")
    panel.view:Hide()
  end
  panel:SetSize(width, HEADER_H + 30 + height + 26)
  dock(width)
  panel:Show()
end

-- Which character the panel is showing, if it's open.
function AltPanel.Key()
  return shownKey
end

function AltPanel.Close()
  shownKey = nil
  if panel then
    panel:Hide()
  end
  ns.MainWindow.PaintSelected()
end

-- Opens on a character, or closes if it's already showing them.
function AltPanel.Toggle(window, key)
  if shownKey == key then
    return AltPanel.Close()
  end
  if not panel then
    build(window)
  end
  shownKey = key
  AltPanel.Refresh()
  ns.MainWindow.PaintSelected()
end

-- Moves to the next or previous row of the tab that's open.
function AltPanel.Step(step)
  local key = ns.Gear.Step(ns.MainWindow.Keys(), shownKey, step)
  if key and key ~= shownKey then
    shownKey = key
    AltPanel.Refresh()
    ns.MainWindow.PaintSelected()
  end
end

function AltPanel.ApplyTheme()
  if not panel then
    return
  end
  local theme = ns.Window.Current()
  local e = theme.edge
  if panel.SetBackdropColor then
    panel:SetBackdropColor(theme.bg[1], theme.bg[2], theme.bg[3], theme.bg[4])
    panel:SetBackdropBorderColor(e[1], e[2], e[3], 1)
  end
  panel.line:SetColorTexture(e[1], e[2], e[3], 0.55)
  for _, b in ipairs({ panel.prev, panel.next, panel.view }) do
    if b.SetBackdropBorderColor then
      b:SetBackdropBorderColor(e[1], e[2], e[3], 0.5)
    end
  end
end

-- Item names and levels load a moment after they're asked for. A panel full
-- of items answers one by one, so redraw once for the lot.
local pending = false
local loader = CreateFrame("Frame")
loader:RegisterEvent("GET_ITEM_INFO_RECEIVED")
loader:SetScript("OnEvent", function()
  if pending or not (shownKey and ns.MainWindow.IsShown()) then
    return
  end
  if not (C_Timer and C_Timer.After) then
    return AltPanel.Refresh()
  end
  pending = true
  C_Timer.After(0.2, function()
    pending = false
    if ns.MainWindow.IsShown() then
      AltPanel.Refresh()
    end
  end)
end)
