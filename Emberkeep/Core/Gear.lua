-- Gear: what each character was last seen wearing. Pure Lua. The adapter hands
-- over a reading (item link and item id per slot); this keeps the last good
-- one, because the game can know an item is worn before its link has loaded,
-- and reads nothing at all while logging out.
local _, ns = ...
ns = ns or {}
local Gear = {}
ns.Gear = Gear

-- Inventory slot ids and names, in the order a list shows them.
Gear.SLOTS = {
  { id = 1, label = "Head" },
  { id = 2, label = "Neck" },
  { id = 3, label = "Shoulder" },
  { id = 15, label = "Back" },
  { id = 5, label = "Chest" },
  { id = 9, label = "Wrist" },
  { id = 10, label = "Hands" },
  { id = 6, label = "Waist" },
  { id = 7, label = "Legs" },
  { id = 8, label = "Feet" },
  { id = 11, label = "Ring 1" },
  { id = 12, label = "Ring 2" },
  { id = 13, label = "Trinket 1" },
  { id = 14, label = "Trinket 2" },
  { id = 16, label = "Main hand" },
  { id = 17, label = "Off hand" },
  { id = 18, label = "Ranged" },
}

-- The character panel's two sides, as slot ids.
Gear.LEFT = { 1, 2, 3, 15, 5, 9, 16, 17, 18 }
Gear.RIGHT = { 10, 6, 7, 8, 11, 12, 13, 14 }

local MAIN_HAND, OFF_HAND = 16, 17

-- An item this many levels below its wearer is worth replacing. Below
-- OUTLEVELED_FROM nobody needs telling: starter gear is always behind.
Gear.OUTLEVELED_BY, Gear.OUTLEVELED_FROM = 8, 10

-- The item id inside a link ("|Hitem:1234:...") or a bare "item:1234".
function Gear.ItemId(link)
  return tonumber(tostring(link or ""):match("item:(%d+)"))
end

-- The name a link shows, without the brackets. nil for a bare "item:1234".
function Gear.LinkName(link)
  return tostring(link or ""):match("%[(.-)%]")
end

-- reading: { [slot id] = { id = item id, link = item link or nil } }, only the
-- slots with something in them. Saves it on the character. Returns whether
-- anything was saved, and whether a link was missing (so read again shortly).
-- An empty reading is ignored: it means the game had nothing to say far more
-- often than that a character took everything off.
function Gear.Observe(c, reading, now)
  if not next(reading) then
    return false, false
  end
  local old = c.gear and c.gear.slots or {}
  local slots, missing = {}, false
  for slot, item in pairs(reading) do
    if item.link then
      slots[slot] = item.link
    else
      missing = true
      -- The same item keeps its saved link until the new one loads.
      local same = Gear.ItemId(old[slot]) == item.id
      slots[slot] = same and old[slot] or ("item:" .. tostring(item.id))
    end
  end
  c.gear = { slots = slots, at = now }
  return true, missing
end

-- What a window shows for a character's gear, or nil if none was ever saved.
-- info(link) returns { name, quality, icon, itemLevel, twoHanded } from the
-- game; anything it doesn't know yet may be missing.
-- Returns { slots = { [slot id] = row }, empty, outleveled, at }.
function Gear.View(c, info)
  if not c.gear then
    return nil
  end
  local view = { slots = {}, empty = 0, outleveled = 0, at = c.gear.at }
  local level = c.level or 0
  for _, slot in ipairs(Gear.SLOTS) do
    local link = c.gear.slots[slot.id]
    local row = { label = slot.label }
    if link then
      local i = info(link) or {}
      row.link = link
      row.name = Gear.LinkName(link) or i.name or "Loading..."
      row.quality, row.icon, row.itemLevel = i.quality, i.icon, i.itemLevel
      row.twoHanded = i.twoHanded
      row.outleveled = level >= Gear.OUTLEVELED_FROM
        and (i.itemLevel or 0) > 0
        and i.itemLevel < level - Gear.OUTLEVELED_BY
      if row.outleveled then
        view.outleveled = view.outleveled + 1
      end
    end
    view.slots[slot.id] = row
  end
  local main, off = view.slots[MAIN_HAND], view.slots[OFF_HAND]
  off.usedByTwoHander = not off.link and main.twoHanded == true
  for _, row in pairs(view.slots) do
    if not row.link and not row.usedByTwoHander then
      view.empty = view.empty + 1
    end
  end
  return view
end

-- "4 empty slots, 1 outleveled", for the line above the gear.
function Gear.Summary(view)
  local text = view.empty == 1 and "1 empty slot" or (view.empty .. " empty slots")
  if view.outleveled > 0 then
    text = text .. ", " .. view.outleveled .. " outleveled"
  end
  return text
end

-- The key `step` places after `key` in a list of keys, wrapping round. The
-- first one when the key isn't in the list.
function Gear.Step(keys, key, step)
  for i, k in ipairs(keys) do
    if k == key then
      return keys[(i - 1 + step) % #keys + 1]
    end
  end
  return keys[1]
end

return Gear
