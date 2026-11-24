-- Items: reads what the logged-in character is wearing, and looks up items by
-- link. The only file that asks the game about items.
local _, ns = ...
local Items = {}
ns.Items = Items

local secret = issecretvalue or function()
  return false
end

local function plain(v)
  if v == nil or secret(v) then
    return nil
  end
  return v
end

-- A reading for Gear.Observe: only the slots with something in them.
function Items.Worn()
  local reading = {}
  if not GetInventoryItemID then
    return reading
  end
  for _, slot in ipairs(ns.Gear.SLOTS) do
    local id = plain(GetInventoryItemID("player", slot.id))
    if id then
      local link = plain(GetInventoryItemLink("player", slot.id))
      -- A link whose name hasn't loaded reads "[]"; treat it as not loaded.
      if link and (ns.Gear.LinkName(link) or "") == "" then
        link = nil
      end
      reading[slot.id] = { id = id, link = link }
    end
  end
  return reading
end

-- For Gear.View. Asks the game to load an item it doesn't know yet; the
-- answer arrives as GET_ITEM_INFO_RECEIVED.
function Items.Info(link)
  local id = ns.Gear.ItemId(link)
  if not (C_Item and id) then
    return {}
  end
  local info = {}
  local _, _, _, equipLoc, icon = C_Item.GetItemInfoInstant(link)
  info.icon, info.twoHanded = icon, equipLoc == "INVTYPE_2HWEAPON"
  info.name, _, info.quality = C_Item.GetItemInfo(link)
  if info.name and C_Item.GetDetailedItemLevelInfo then
    info.itemLevel = C_Item.GetDetailedItemLevelInfo(link)
  elseif not info.name and C_Item.RequestLoadItemDataByID then
    C_Item.RequestLoadItemDataByID(id)
  end
  return info
end

-- "|cff1eff00Name|r" in the item's quality color.
function Items.Colored(name, quality)
  local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  return c and c.hex and (c.hex .. name .. "|r") or name
end

-- r, g, b of an item quality, or nil when it isn't known.
function Items.Rgb(quality)
  local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  if c then
    return c.r, c.g, c.b
  end
end

-- Shift-click links the item in chat: whatever the game does with a modified
-- click on an item. A bare "item:1234" can't be linked.
function Items.ModifiedClick(link)
  if IsModifiedClick and IsModifiedClick() and tostring(link):find("|H", 1, true) then
    HandleModifiedItemClick(link)
  end
end
