-- Columns: how wide each table column is. Pure Lua.
local _, ns = ...
ns = ns or {}
local Columns = {}
ns.Columns = Columns

-- columns is a list of { label, width, grow = weight }. When `available` is
-- wider than the columns add up to, the extra goes to the columns with a grow
-- weight, in proportion to it (any rounding leftover goes to the first one).
-- Columns never get narrower than their own width.
function Columns.Fit(columns, available)
  local widths, base, weights = {}, 0, 0
  for i, col in ipairs(columns) do
    widths[i] = col[2]
    base = base + col[2]
    weights = weights + (col.grow or 0)
  end
  local extra = math.floor((tonumber(available) or 0) - base)
  if extra <= 0 or weights <= 0 then
    return widths, base
  end
  local given, first = 0, nil
  for i, col in ipairs(columns) do
    if (col.grow or 0) > 0 then
      local add = math.floor(extra * col.grow / weights)
      widths[i] = widths[i] + add
      given = given + add
      first = first or i
    end
  end
  widths[first] = widths[first] + (extra - given)
  return widths, base + extra
end

return Columns
