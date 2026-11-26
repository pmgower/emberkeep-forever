-- Bags: what each character was last seen carrying, and what they keep in the
-- bank. Pure Lua. The adapter hands over a reading of every bag (or every bank
-- tab); this keeps the last good one. place is "bags" (the default) or "bank".
local _, ns = ...
ns = ns or {}
local Bags = {}
ns.Bags = Bags

local function itemId(link)
  return tonumber(tostring(link or ""):match("item:(%d+)"))
end

Bags.PLACES = { bags = true, bank = true }

local function placeOf(place)
  return Bags.PLACES[place] and place or "bags"
end

-- reading: { items = { { id, link or nil, count }, ... } in slot order, free,
-- total }. A link that hasn't loaded keeps the one saved for the same item.
-- Saves it on the character and returns true, unless the game reported no
-- slots at all: everyone has a backpack, and the bank always has its own
-- slots, so that means "not loaded" (or the bank isn't open).
function Bags.Observe(c, reading, now, place)
  place = placeOf(place)
  if not reading or (reading.total or 0) <= 0 then
    return false
  end
  local known = {}
  for _, item in ipairs(c[place] and c[place].items or {}) do
    known[itemId(item.link) or 0] = item.link
  end
  local items = {}
  for i, item in ipairs(reading.items) do
    local link = item.link or known[item.id] or ("item:" .. tostring(item.id))
    items[i] = { link = link, count = item.count }
  end
  c[place] = { items = items, free = reading.free, total = reading.total, at = now }
  return true
end

-- What a window shows, or nil if that place was never saved. info(link)
-- returns what the game knows about an item: { name, quality, icon }.
-- Returns { rows = { { link, count, name, quality, icon }, ... }, free, total, at }.
function Bags.View(c, info, place)
  local saved = c[placeOf(place)]
  if not saved then
    return nil
  end
  local view = { rows = {}, free = saved.free, total = saved.total, at = saved.at }
  for i, item in ipairs(saved.items) do
    local known = info(item.link) or {}
    view.rows[i] = {
      link = item.link,
      count = item.count,
      name = known.name,
      quality = known.quality,
      icon = known.icon,
    }
  end
  return view
end

-- "9 of 16 slots free". Slots of bags that only hold some things (quivers,
-- reagent bags) aren't counted. The same for the bank.
function Bags.Summary(view)
  return view.free .. " of " .. view.total .. " slots free"
end

return Bags
