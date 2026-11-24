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

-- Every bag's contents, for Bags.Observe: the backpack, then each equipped bag.
-- Free slots count only bags that hold anything (family 0). The keyring's
-- items are listed, its slots aren't counted. "missing" says a link hasn't
-- loaded, so read again shortly.
function Items.Carried()
  local C = C_Container
  if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then
    return nil
  end
  local reading = { items = {}, free = 0, total = 0, missing = false }
  local function readSlots(bag, size)
    for slot = 1, size do
      local info = C.GetContainerItemInfo(bag, slot)
      local id = info and plain(info.itemID)
      if id then
        local link = plain(info.hyperlink)
        if link and (ns.Gear.LinkName(link) or "") == "" then
          link = nil
        end
        reading.missing = reading.missing or link == nil
        reading.items[#reading.items + 1] = { id = id, link = link, count = plain(info.stackCount) or 1 }
      end
    end
  end
  for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do
    local size = plain(C.GetContainerNumSlots(bag)) or 0
    local free, family = C.GetContainerNumFreeSlots(bag)
    if size > 0 and (plain(family) or 0) == 0 and bag <= 4 then -- bag 5 is the reagent bag
      reading.total = reading.total + size
      reading.free = reading.free + (plain(free) or 0)
    end
    readSlots(bag, size)
  end
  local keyring = Enum and Enum.BagIndex and Enum.BagIndex.Keyring
  if keyring and GetKeyRingSize then
    readSlots(keyring, plain(GetKeyRingSize()) or 0)
  end
  return reading
end

local requested = {}

-- For Gear.View. Asks the game once to load an item it doesn't know yet; the
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
  elseif not info.name and not requested[id] and C_Item.RequestLoadItemDataByID then
    requested[id] = true
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
