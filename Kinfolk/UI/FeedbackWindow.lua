-- FeedbackWindow: /kinfolk feedback. WoW chat can't be copied, so the issue
-- link and the report go in two read-only edit boxes the player can Ctrl+C
-- from. Also the small "Kinfolk ran into a problem" prompt. Same themed frame
-- as the main window (UI/Window.lua).
local _, ns = ...
local FeedbackWindow = {}
ns.FeedbackWindow = FeedbackWindow

local win, urlBox, reportBox, labels, boxBgs = nil, nil, nil, {}, {}
local LABEL_H, URL_H, GAP = 16, 20, 6

local function num(v, default)
  v = tonumber(v)
  return (v and v == v) and v or default
end

-- An edit box that selects everything on focus and undoes any typing, so the
-- text stays exactly what we generated.
local function readOnly(box)
  box:SetAutoFocus(false)
  box:SetMaxLetters(0) -- no cap: the prefilled link can be a few thousand characters
  box:SetFontObject("ChatFontNormal")
  box:SetTextInsets(4, 4, 3, 3)
  box:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
  end)
  box:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    win.frame:Hide()
  end)
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      self:SetText(self.fixedText or "")
      self:HighlightText()
    end
    FeedbackWindow.Relayout()
  end)
  box:SetScript("OnMouseUp", function(self)
    self:HighlightText()
  end)
  -- A faint panel behind the text, so it reads as something to select.
  local bg = box:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  boxBgs[#boxBgs + 1] = bg
  return box
end

local function setFixed(box, text)
  box.fixedText = text
  box:SetText(text)
end

local function label()
  local fs = win.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetJustifyH("LEFT")
  labels[#labels + 1] = fs
  return fs
end

local function applyTheme(theme)
  local r, g, b = ns.Window.Rgb(theme.title)
  for _, fs in ipairs(labels) do
    fs:SetTextColor(r, g, b)
  end
  for _, bg in ipairs(boxBgs) do
    bg:SetColorTexture(theme.edge[1], theme.edge[2], theme.edge[3], 0.12)
  end
end

-- Stack: label, link box, label, report box. Widths follow the window.
function FeedbackWindow.Relayout()
  if not (win and reportBox) then
    return
  end
  local w = win:ContentWidth() - 4
  local c, y = win.content, -2
  labels[1]:ClearAllPoints()
  labels[1]:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
  labels[1]:SetWidth(w)
  y = y - LABEL_H
  urlBox:ClearAllPoints()
  urlBox:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
  urlBox:SetSize(w, URL_H)
  y = y - URL_H - GAP * 2
  labels[2]:ClearAllPoints()
  labels[2]:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
  labels[2]:SetWidth(w)
  y = y - LABEL_H
  reportBox:ClearAllPoints()
  reportBox:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
  reportBox:SetWidth(w)
  c:SetSize(w, -y + num(reportBox:GetHeight(), 200) + GAP)
  win:UpdateScrollBars()
end

local function build()
  win = ns.Window.New({
    name = "KinfolkFeedbackWindow",
    title = "Kinfolk: report a problem",
    store = {},
    defaultPoint = { "CENTER", "CENTER", 0, 0 },
    defaultSize = { 540, 380 },
    bounds = { 360, 200, 1000, 900 },
    onResize = function()
      FeedbackWindow.Relayout()
    end,
    onTheme = function(theme)
      applyTheme(theme)
    end,
  })
  win.frame:SetFrameStrata("DIALOG")
  tinsert(UISpecialFrames, "KinfolkFeedbackWindow") -- Esc closes it
  label() -- texts are set in Show: they depend on whether the link carries the report
  urlBox = readOnly(CreateFrame("EditBox", nil, win.content))
  label()
  reportBox = readOnly(CreateFrame("EditBox", nil, win.content))
  reportBox:SetMultiLine(true)
  applyTheme(ns.Window.Current())
  win.frame:Hide() -- new frames start shown; Show decides
end

-- Opens the window with the link and the report. prefilled: the link already
-- carries the report, so the link box gets focus and the report is a fallback.
function FeedbackWindow.Show(url, report, prefilled)
  if not win then
    build()
  end
  FeedbackWindow.url, FeedbackWindow.report = url, report -- for tests
  if prefilled then
    labels[1]:SetText("1. Copy this link (Ctrl+C) into your browser. It opens a filled-in bug report:")
    labels[2]:SetText("2. Only if the report box on GitHub comes up empty, copy this into it:")
  else
    labels[1]:SetText("1. Copy this link (Ctrl+C) into your browser:")
    labels[2]:SetText("2. Copy this report (Ctrl+C) and paste it into the issue:")
  end
  setFixed(urlBox, url)
  setFixed(reportBox, report)
  FeedbackWindow.Relayout()
  win.frame:Show()
  local focus = prefilled and urlBox or reportBox
  focus:SetFocus()
  focus:HighlightText()
end

function FeedbackWindow.IsShown()
  return win ~= nil and win.frame:IsShown()
end

---------------------------------------------------------------- error prompt
-- Once per session, when Kinfolk itself hits a Lua error: "Report it" opens
-- the feedback window, which already has the error in its report.

local prompt, promptText

local function button(parent, text, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(110, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function buildPrompt()
  prompt = ns.Window.New({
    name = "KinfolkErrorPrompt",
    title = "Kinfolk ran into a problem",
    store = {},
    defaultPoint = { "TOP", "TOP", 0, -160 },
    defaultSize = { 380, 150 },
    bounds = { 300, 120, 700, 400 },
    onTheme = function(theme)
      if promptText then
        promptText:SetTextColor(ns.Window.Rgb(theme.title))
      end
    end,
  })
  local f, c = prompt.frame, prompt.content
  f:SetFrameStrata("DIALOG")
  tinsert(UISpecialFrames, "KinfolkErrorPrompt") -- Esc closes it
  c:SetSize(prompt:ContentWidth(), 60)
  promptText = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  promptText:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -2)
  promptText:SetWidth(prompt:ContentWidth() - 4)
  promptText:SetJustifyH("LEFT")
  FeedbackWindow.reportButton = button(f, "Report it", function()
    f:Hide()
    ns.App.OpenFeedback()
  end)
  FeedbackWindow.reportButton:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 20)
  FeedbackWindow.laterButton = button(f, "Not now", function()
    f:Hide()
  end)
  FeedbackWindow.laterButton:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 20)
  prompt:ApplyTheme()
  f:Hide()
end

function FeedbackWindow.ShowErrorPrompt(msg)
  if not prompt then
    buildPrompt()
  end
  local first = tostring(msg or ""):match("^[^\n]*") or ""
  if #first > 160 then
    first = first:sub(1, 160) .. "..."
  end
  FeedbackWindow.promptMessage = first -- for tests
  promptText:SetText(
    "Sorry about that. A bug report helps get it fixed, and the error is already in it.\n\n|cff999999"
      .. first
      .. "|r"
  )
  prompt.frame:Show()
end

function FeedbackWindow.IsPromptShown()
  return prompt ~= nil and prompt.frame:IsShown()
end
