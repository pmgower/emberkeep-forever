-- Bags: what each character was last seen carrying. Pure Lua. The adapter
-- hands over a reading of every bag; this keeps the last good one.
local _, ns = ...
ns = ns or {}
local Bags = {}
ns.Bags = Bags

-- reading: { items = { { link, count }, ... } in slot order, free, total }.
-- Saves it on the character and returns true, unless the game reported no
-- bag slots at all: everyone has a backpack, so that means "not loaded".
function Bags.Observe(c, reading, now)
  if not reading or (reading.total or 0) <= 0 then
    return false
  end
  local items = {}
  for i, item in ipairs(reading.items) do
    items[i] = { link = item.link, count = item.count }
  end
  c.bags = { items = items, free = reading.free, total = reading.total, at = now }
  return true
end

-- What a window shows, or nil if no bags were ever saved. info(link) returns
-- what the game knows about an item: { name, quality, icon }.
-- Returns { rows = { { link, count, name, quality, icon }, ... }, free, total, at }.
function Bags.View(c, info)
  if not c.bags then
    return nil
  end
  local view = { rows = {}, free = c.bags.free, total = c.bags.total, at = c.bags.at }
  for i, item in ipairs(c.bags.items) do
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
-- reagent bags) aren't counted.
function Bags.Summary(view)
  return view.free .. " of " .. view.total .. " slots free"
end

return Bags
