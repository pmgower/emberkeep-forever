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
        elseif k == "UnregisterEvent" then
          self._events[...] = nil
        elseif k == "IsEventRegistered" then
          return self._events[...] == true
        elseif k == "Show" then
          self._shown = true
        elseif k == "Hide" then
          self._shown = false
        elseif k == "Disable" then
          self._disabled = true
        elseif k == "Enable" then
          self._disabled = false
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
          if self._point then
            return unpack(self._point)
          end
          return "CENTER", nil, "CENTER", 0, 0
        elseif k == "SetPoint" then
          self._point = { ... }
        elseif k == "SetScale" then
          self._scale = ...
        elseif k == "GetScale" then
          return self._scale or 1
        elseif k == "GetCenter" then
          return 600, 400
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
  -- Like the real one, it refuses a variable name used twice or a default of
  -- the wrong type, and SetValue writes the table and runs the callback.
  W.settings = { controls = {}, callbacks = {}, buttons = {}, variables = {}, pages = {} }
  local kinds = { boolean = "boolean", number = "number", string = "string" }
  local function setting(key, tbl)
    return {
      SetValueChangedCallback = function(_, fn)
        W.settings.callbacks[key] = fn
      end,
      SetValue = function(_, value)
        tbl[key] = value
        if W.settings.callbacks[key] then
          W.settings.callbacks[key]()
        end
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
    RegisterAddOnSetting = function(_, variable, key, tbl, kind, _, default)
      assert(not W.settings.variables[variable], "setting registered twice: " .. variable)
      W.settings.variables[variable] = true
      assert(type(default) == kinds[kind], "default for " .. key .. " isn't a " .. tostring(kind))
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
    RegisterCanvasLayoutSubcategory = function(_, frame, name)
      W.settings.pages[name] = frame
    end,
    OpenToCategory = function(id)
      W.settings.opened = id
    end,
  }
  -- Context menus: records the last one opened, with its titles and buttons.
  W.menu = nil
  _G.MenuUtil = {
    CreateContextMenu = function(owner, generator)
      local menu = { owner = owner, titles = {}, buttons = {} }
      generator(owner, {
        CreateTitle = function(_, text)
          table.insert(menu.titles, text)
        end,
        CreateButton = function(_, text, fn)
          menu.buttons[text] = fn
        end,
      })
      W.menu = menu
    end,
  }
  _G.CreateSettingsButtonInitializer = function(name, label, onClick)
    return { name = name, label = label, onClick = onClick }
  end
  -- Values named in state.secret read as hidden from addons.
  _G.issecretvalue = function(v)
    return state.secret ~= nil and v == state.secret
  end
  _G.UnitName = function()
    return state.name, state.surname -- Forever: the second value is the surname
  end
  _G.GetRealmName = function()
    return state.realm
  end
  _G.UnitClass = function()
    return "Warrior", "WARRIOR"
  end
  _G.UnitRace = function()
    return "Orc", "Orc" -- localized name, then the race token
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
  _G.GetSubZoneText = function()
    return state.subzone
  end
  _G.time = function()
    return state.now
  end
  _G.GetMaxPlayerLevel = function()
    return 60
  end
  _G.UnitXPMax = function()
    return state.xpMax or 0
  end
  _G.GetXPExhaustion = function()
    return state.rested
  end
  _G.IsResting = function()
    return state.resting
  end
  -- Worn items: state.worn is { [slot id] = { id, name, level, quality } }.
  -- state.unloaded leaves links out, as just after login.
  local function item(id)
    for _, it in pairs(state.worn or {}) do
      if it.id == id then
        return it
      end
    end
  end
  local function idOf(link)
    return tonumber(tostring(link):match("item:(%d+)"))
  end
  _G.GetInventoryItemID = function(_, slot)
    return state.worn and state.worn[slot] and state.worn[slot].id
  end
  _G.GetInventoryItemLink = function(_, slot)
    local it = state.worn and state.worn[slot]
    if it and not state.unloaded then
      return "|cffffffff|Hitem:" .. it.id .. "::|h[" .. it.name .. "]|h|r"
    end
  end
  _G.C_Item = {
    GetItemInfoInstant = function(link)
      return idOf(link), nil, nil, "INVTYPE_HEAD", 134400
    end,
    GetItemInfo = function(link)
      local it = item(idOf(link))
      if it then
        return it.name, link, it.quality
      end
    end,
    GetDetailedItemLevelInfo = function(link)
      local it = item(idOf(link))
      return it and it.level
    end,
    RequestLoadItemDataByID = function() end,
  }
  -- The backpack and a quiver (family 1): state.bag and state.quiver are
  -- { size, [slot] = { id, name, count } }. state.unloaded leaves names out.
  local function bagAt(bag)
    if bag == 0 then
      return state.bag
    end
    return bag == 1 and state.quiver or nil
  end
  _G.C_Container = {
    GetContainerNumSlots = function(bag)
      return bagAt(bag) and bagAt(bag).size or 0
    end,
    GetContainerNumFreeSlots = function(bag)
      local used = 0
      for slot in pairs(bagAt(bag) or {}) do
        used = used + (type(slot) == "number" and 1 or 0)
      end
      return bagAt(bag) and bagAt(bag).size - used or 0, bag == 1 and 1 or 0
    end,
    GetContainerItemInfo = function(bag, slot)
      local it = bagAt(bag) and bagAt(bag)[slot]
      local name = it and not state.unloaded and it.name or ""
      local link = it and ("|Hitem:" .. it.id .. "::|h[" .. name .. "]|h")
      return it and { itemID = it.id, hyperlink = link, stackCount = it.count }
    end,
  }
  W.linked = {}
  _G.IsModifiedClick = function()
    return state.shift == true
  end
  _G.HandleModifiedItemClick = function(link)
    table.insert(W.linked, link)
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
  _G.IsControlKeyDown = function()
    return state.ctrl == true
  end
  _G.GetBuildInfo = function()
    return "1.60.1", "60000", "Nov 1 2026", 16001
  end
  -- /played: counts requests; a test answers with W.fire("TIME_PLAYED_MSG", ...).
  -- ChatFrame1 listens for the answer, like the real chat window.
  W.playedRequests = 0
  _G.RequestTimePlayed = function()
    W.playedRequests = W.playedRequests + 1
  end
  _G.NUM_CHAT_WINDOWS = 1
  _G.ChatFrame1 = fakeObject("ChatFrame")
  _G.ChatFrame1:RegisterEvent("TIME_PLAYED_MSG")
  _G.GetLocale = function()
    return "enUS"
  end
  -- Like the real one, the first line is whoever called it (level 1), so
  -- state.stack is everything below that.
  _G.debugstack = function(start)
    local lines = { "Interface/AddOns/Emberkeep/App.lua:90: in function <handler>" }
    for line in (state.stack or ""):gmatch("[^\n]+") do
      lines[#lines + 1] = line
    end
    return table.concat(lines, "\n", math.min(start or 1, #lines + 1))
  end
  -- The game's error handler: records what reaches it, like BugSack would.
  W.caught = {}
  local handler = function(msg)
    table.insert(W.caught, msg)
  end
  _G.geterrorhandler = function()
    return handler
  end
  _G.seterrorhandler = function(fn)
    handler = fn
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
