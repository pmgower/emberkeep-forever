-- A permissive stand-in for the WoW API, enough to load every TOC file in
-- order and drive the event and slash-command paths. Any frame method returns
-- a harmless default, so the smoke test catches nil errors and load-order
-- mistakes in our code, not layout.
local W = {}

local function fakeObject(kind)
  local o = { _kind = kind, _scripts = {}, _events = {}, _shown = true, _w = 100, _h = 100 }
  return setmetatable(o, {
    __index = function(_, k)
      return function(self, ...)
        if k == "SetScript" then
          local name, fn = ...
          self._scripts[name] = fn
        elseif k == "RegisterEvent" then
          self._events[...] = true
        elseif k == "Show" then
          self._shown = true
        elseif k == "Hide" then
          self._shown = false
        elseif k == "IsShown" then
          return self._shown
        elseif k == "GetWidth" then
          return self._w
        elseif k == "GetHeight" then
          return self._h
        elseif k == "SetWidth" then
          self._w = ...
        elseif k == "SetHeight" then
          self._h = ...
        elseif k == "SetSize" then
          self._w, self._h = ...
        elseif k == "GetStringWidth" then
          return 40
        elseif k == "GetPoint" then
          return "CENTER", nil, "CENTER", 0, 0
        elseif k:match("^Create") then
          return fakeObject(k)
        elseif k:match("^Get") then
          return 0
        end
        return nil
      end
    end,
  })
end

function W.install(state)
  W.frames = {}
  _G.CreateFrame = function(kind)
    local f = fakeObject(kind)
    table.insert(W.frames, f)
    return f
  end
  _G.UIParent = fakeObject("UIParent")
  _G.GameTooltip = fakeObject("GameTooltip")
  _G.UISpecialFrames = {}
  _G.tinsert = table.insert
  _G.SlashCmdList = {}
  _G.RAID_CLASS_COLORS = { WARRIOR = { colorStr = "ffc79c6e" } }
  _G.DEFAULT_CHAT_FRAME = {
    lines = {},
    AddMessage = function(self, text)
      table.insert(self.lines, text)
    end,
  }
  _G.C_AddOns = {
    GetAddOnMetadata = function(_, field)
      return field == "Version" and state.version or nil
    end,
  }
  _G.UnitName = function()
    return state.name
  end
  _G.GetRealmName = function()
    return state.realm
  end
  _G.UnitClass = function()
    return "Warrior", "WARRIOR"
  end
  _G.UnitRace = function()
    return "Orc"
  end
  _G.UnitFactionGroup = function()
    return "Horde"
  end
  _G.UnitLevel = function()
    return state.level
  end
  _G.GetMoney = function()
    return state.money
  end
  _G.GetRealZoneText = function()
    return state.zone
  end
  _G.time = function()
    return state.now
  end
  _G.IsShiftKeyDown = function()
    return false
  end
  _G.IsMouseButtonDown = function()
    return false
  end
  _G.GetCursorPosition = function()
    return 0, 0
  end
end

-- Loads every file the TOC lists, in order, with one shared namespace.
function W.loadToc(toc, addonName)
  local ns = {}
  local dir = toc:match("^(.*)/[^/]+$")
  for line in io.lines(toc) do
    if line ~= "" and not line:match("^#") then
      local chunk = assert(loadfile(dir .. "/" .. line:gsub("\\", "/")))
      chunk(addonName, ns)
    end
  end
  return ns
end

-- Sends an event to every frame registered for it.
function W.fire(event, ...)
  for _, f in ipairs(W.frames) do
    if f._events[event] and f._scripts.OnEvent then
      f._scripts.OnEvent(f, event, ...)
    end
  end
end

return W
