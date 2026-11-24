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
        elseif k == "SetText" then
          self._text = ...
        elseif k == "GetText" then
          return self._text
        elseif k == "GetStringWidth" then
          return 40
        elseif k == "GetPoint" then
          return "CENTER", nil, "CENTER", 0, 0
        elseif k:match("^Create") then
          local child = fakeObject(k)
          table.insert(W.frames, child)
          return child
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
  -- Just enough of the Settings API to build the options page and change values.
  W.settings = { controls = {}, callbacks = {}, buttons = {} }
  local function setting(key, tbl)
    return {
      SetValueChangedCallback = function(_, fn)
        W.settings.callbacks[key] = fn
      end,
      tbl = tbl,
    }
  end
  _G.Settings = {
    RegisterVerticalLayoutCategory = function(name)
      W.settings.name = name
      return {
        GetID = function()
          return 7
        end,
      }, {
        AddInitializer = function(_, init)
          table.insert(W.settings.buttons, init)
        end,
      }
    end,
    RegisterAddOnSetting = function(_, _, key, tbl)
      return setting(key, tbl)
    end,
    CreateCheckbox = function(_, s)
      table.insert(W.settings.controls, s)
    end,
    CreateDropdown = function(_, s, options)
      s.options = options
      table.insert(W.settings.controls, s)
    end,
    CreateControlTextContainer = function()
      local data = {}
      return {
        Add = function(_, value, label)
          table.insert(data, { value = value, label = label })
        end,
        GetData = function()
          return data
        end,
      }
    end,
    CreateSlider = function(_, s)
      table.insert(W.settings.controls, s)
    end,
    CreateSliderOptions = function()
      return { SetLabelFormatter = function() end }
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id)
      W.settings.opened = id
    end,
  }
  _G.CreateSettingsButtonInitializer = function(_, label, onClick)
    return { label = label, onClick = onClick }
  end
  -- Values named in state.secret read as hidden from addons.
  _G.issecretvalue = function(v)
    return state.secret ~= nil and v == state.secret
  end
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

-- Bundled libraries are pinned upstream code, so the smoke test swaps them
-- for a LibStub that records what our code registers.
function W.fakeLibs()
  W.icons = {}
  local ldb = {
    NewDataObject = function(_, name, obj)
      W.icons[name] = { obj = obj, shown = nil }
      return obj
    end,
  }
  local dbicon = {
    Register = function(_, name, _, db)
      W.icons[name].db = db
    end,
    Show = function(_, name)
      W.icons[name].shown = true
    end,
    Hide = function(_, name)
      W.icons[name].shown = false
    end,
  }
  _G.LibStub = function(major)
    return ({ ["LibDataBroker-1.1"] = ldb, ["LibDBIcon-1.0"] = dbicon })[major]
  end
end

-- Loads every file the TOC lists, in order, with one shared namespace.
function W.loadToc(toc, addonName)
  W.fakeLibs()
  local ns = {}
  local dir = toc:match("^(.*)/[^/]+$")
  for line in io.lines(toc) do
    line = line:gsub("%s+$", "")
    if line ~= "" and not line:match("^#") and not line:match("^Libs\\") then
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
