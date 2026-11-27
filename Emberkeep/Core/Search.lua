-- Search: find an item on any alt, from what was saved of their bags, bank,
-- mail and gear. Pure Lua. The search words work like Baganator's: text
-- matches item names, #word matches only a keyword (quality, kind, slot,
-- where it is), numbers match item levels, and & | ! ( ) combine them.
local _, ns = ...
ns = ns or {}
local Search = {}
ns.Search = Search

Search.MAX_ITEMS = 100 -- results shown at most; the rest are counted
Search.PLACES = { "bags", "bank", "mail", "equipped" }
local PLACE_WORD = { bags = "bags", bank = "bank", mail = "mailbox", equipped = "equipped" }
local PLACE_TEXT = { bags = "bags", bank = "bank", mail = "mail", equipped = "worn" }

-- Keywords, from what the game says about an item (GetItemInfoInstant and
-- GetItemInfo), as the help in the window lists them.
local CLASSES = {
  [0] = "consumable",
  [1] = "container",
  [2] = "weapon",
  [3] = "gem",
  [4] = "armor",
  [5] = "reagent",
  [6] = "ammo",
  [7] = "tradegoods",
  [9] = "recipe",
  [11] = "quiver",
  [12] = "quest",
  [13] = "key",
  [15] = "misc",
}
local ARMOR = { [1] = "cloth", [2] = "leather", [3] = "mail", [4] = "plate", [6] = "shield" }
local QUALITIES = { [0] = "poor", "common", "uncommon", "rare", "epic", "legendary", "artifact", "heirloom" }
local QUALITY_HEX = {
  ["9d9d9d"] = 0,
  ffffff = 1,
  ["1eff00"] = 2,
  ["0070dd"] = 3,
  a335ee = 4,
  ff8000 = 5,
  e6cc80 = 6,
  ["00ccff"] = 7,
}
local BIND = { [1] = "bop", [2] = "boe", [3] = "bou" }
local SLOTS = {
  INVTYPE_HEAD = "head",
  INVTYPE_NECK = "neck",
  INVTYPE_SHOULDER = "shoulder",
  INVTYPE_BODY = "shirt",
  INVTYPE_CHEST = "chest",
  INVTYPE_ROBE = "chest",
  INVTYPE_WAIST = "waist",
  INVTYPE_LEGS = "legs",
  INVTYPE_FEET = "feet",
  INVTYPE_WRIST = "wrist",
  INVTYPE_HAND = "hands",
  INVTYPE_FINGER = "ring",
  INVTYPE_TRINKET = "trinket",
  INVTYPE_CLOAK = "back",
  INVTYPE_WEAPON = "onehand",
  INVTYPE_WEAPONMAINHAND = "onehand",
  INVTYPE_2HWEAPON = "twohand",
  INVTYPE_SHIELD = "offhand",
  INVTYPE_WEAPONOFFHAND = "offhand",
  INVTYPE_HOLDABLE = "offhand",
  INVTYPE_RANGED = "ranged",
  INVTYPE_RANGEDRIGHT = "ranged",
  INVTYPE_THROWN = "ranged",
  INVTYPE_RELIC = "relic",
  INVTYPE_TABARD = "tabard",
  INVTYPE_BAG = "bag",
}

-- For the help rows: each group of keywords, in the order they're listed.
Search.KEYWORDS = {
  { "Quality", "poor (or junk), common, uncommon, rare, epic, legendary" },
  { "Kind", "gear, weapon, armor, consumable, reagent, tradegoods, recipe, quest, container, gem, misc" },
  { "Armor", "cloth, leather, mail, plate, shield" },
  { "Slot", "head, neck, shoulder, chest, waist, legs, feet, wrist, hands, ring, trinket, back, onehand" },
  { "", "twohand, offhand, ranged, relic, shirt, tabard, bag" },
  { "Binds", "boe, bop, bou" },
  { "Where", "bags, bank, mailbox, equipped" },
}

local function itemId(link)
  return tonumber(tostring(link or ""):match("item:(%d+)"))
end

local function trim(s)
  return (s:match("^%s*(.-)%s*$"))
end

-- Search text into a tree: { op = "or" | "and", a, b }, { op = "not", a }, or
-- { term = "lower case text" }. nil when it isn't whole yet ("linen &").
-- ! binds tightest, then &, then |, as in Baganator.
function Search.Parse(text)
  local tokens, buf = {}, ""
  for ch in tostring(text or ""):gmatch(".") do
    if ch:find("[&|!()]") then
      if trim(buf) ~= "" then
        tokens[#tokens + 1] = { term = trim(buf):lower() }
      end
      buf = ""
      tokens[#tokens + 1] = { op = ch }
    else
      buf = buf .. ch
    end
  end
  if trim(buf) ~= "" then
    tokens[#tokens + 1] = { term = trim(buf):lower() }
  end
  if #tokens == 0 then
    return nil
  end
  local pos = 1
  local either
  local function single()
    local t = tokens[pos]
    if not t then
      return nil
    end
    pos = pos + 1
    if t.term then
      return t
    elseif t.op == "!" then
      local a = single()
      return a and { op = "not", a }
    elseif t.op == "(" then
      local a = either()
      if not (a and tokens[pos] and tokens[pos].op == ")") then
        return nil
      end
      pos = pos + 1
      return a
    end
    return nil
  end
  local function both()
    local a = single()
    while a and tokens[pos] and tokens[pos].op == "&" do
      pos = pos + 1
      local b = single()
      a = b and { op = "and", a, b }
    end
    return a
  end
  either = function()
    local a = both()
    while a and tokens[pos] and tokens[pos].op == "|" do
      pos = pos + 1
      local b = both()
      a = b and { op = "or", a, b }
    end
    return a
  end
  local tree = either()
  if pos <= #tokens then
    return nil -- something left over, such as a stray ")"
  end
  return tree
end

-- What one item is, for matching: { name (lower case), shown, quality, itemLevel,
-- keywords = { [word] = true } }. info(link) returns what the game knows:
-- { name, quality, itemLevel, classID, subclassID, equipLoc, bindType, icon }.
local function describe(link, place, known)
  local name = known.name or tostring(link):match("%[(.-)%]")
  local quality = known.quality or QUALITY_HEX[(tostring(link):match("|c%x%x(%x%x%x%x%x%x)") or ""):lower()]
  local words = { [PLACE_WORD[place]] = true }
  local function add(word)
    if word then
      words[word] = true
    end
  end
  add(QUALITIES[quality])
  if quality == 0 then
    add("junk")
  end
  add(CLASSES[known.classID])
  if known.classID == 2 or known.classID == 4 then
    add("gear")
  end
  if known.classID == 4 then
    add(ARMOR[known.subclassID])
  end
  add(SLOTS[known.equipLoc])
  add(BIND[known.bindType])
  return {
    name = name and name:lower() or "",
    shown = name, -- as the game writes it
    quality = quality,
    itemLevel = known.itemLevel,
    keywords = words,
  }
end

local function levelMatch(term, level)
  local exact = term:match("^(%d+)$")
  local below, above = term:match("^<(%d+)$"), term:match("^>(%d+)$")
  local low, high = term:match("^(%d+)%-(%d+)$")
  if not (exact or below or above or low) then
    return nil -- not an item level term
  end
  if not level then
    return false
  elseif exact then
    return level == tonumber(exact)
  elseif below then
    return level < tonumber(below)
  elseif above then
    return level > tonumber(above)
  end
  return level >= tonumber(low) and level <= tonumber(high)
end

local function matches(tree, item)
  if tree.op == "or" then
    return matches(tree[1], item) or matches(tree[2], item)
  elseif tree.op == "and" then
    return matches(tree[1], item) and matches(tree[2], item)
  elseif tree.op == "not" then
    return not matches(tree[1], item)
  end
  local term = tree.term
  local exact = term:match("^#(.*)$")
  if exact then
    return item.keywords[exact] == true
  end
  local level = levelMatch(term, item.itemLevel)
  if level ~= nil then
    return level
  end
  return item.keywords[term] == true or item.name:find(term, 1, true) ~= nil
end

-- Every item saved for every character, with where it is: { key, place,
-- link, count }. Mail sent to an alt counts as in their mailbox until it
-- would have gone back.
function Search.Entries(characters, now)
  local list = {}
  local function add(key, place, link, count)
    if link then
      list[#list + 1] = { key = key, place = place, link = link, count = count or 1 }
    end
  end
  for key, c in pairs(characters) do
    for _, place in ipairs({ "bags", "bank" }) do
      for _, item in ipairs(c[place] and c[place].items or {}) do
        add(key, place, item.link, item.count)
      end
    end
    for _, link in pairs(c.gear and c.gear.slots or {}) do
      add(key, "equipped", link, 1)
    end
    local mail = c.mail or {}
    for _, m in ipairs(mail.inbox or {}) do
      for _, item in ipairs(m.items or {}) do
        add(key, "mail", item.link, item.count)
      end
    end
    for _, m in ipairs(mail.sent or {}) do
      if (m.expires or math.huge) > now then
        for _, item in ipairs(m.items or {}) do
          add(key, "mail", item.link, item.count)
        end
      end
    end
  end
  return list
end

-- Runs a search. Returns nil while the text isn't a whole search yet, else
-- { items = { { id, link, name, quality, icon, total, alts = { { key, total,
-- places = { bags = n, ... } } } } }, more = items not shown }. Items are in
-- name order, alts with the most first.
function Search.Run(characters, text, info, now)
  local tree = Search.Parse(text)
  if not tree then
    return nil
  end
  local known, groups = {}, {}
  for _, e in ipairs(Search.Entries(characters, now)) do
    known[e.link] = known[e.link] or info(e.link) or {}
    local k = known[e.link]
    local item = describe(e.link, e.place, k)
    if matches(tree, item) then
      local id = itemId(e.link) or e.link
      local g = groups[id]
      if not g then
        g = { id = id, link = e.link, name = item.shown, quality = item.quality, icon = k.icon }
        g.total, g.byKey = 0, {}
        groups[id] = g
      end
      if not g.link:find("|H", 1, true) and e.link:find("|H", 1, true) then
        g.link, g.name = e.link, item.shown or g.name
      end
      local alt = g.byKey[e.key]
      if not alt then
        alt = { key = e.key, total = 0, places = {} }
        g.byKey[e.key] = alt
      end
      alt.total = alt.total + e.count
      alt.places[e.place] = (alt.places[e.place] or 0) + e.count
      g.total = g.total + e.count
    end
  end
  local items = {}
  for _, g in pairs(groups) do
    g.alts = {}
    for _, alt in pairs(g.byKey) do
      g.alts[#g.alts + 1] = alt
    end
    g.byKey = nil
    table.sort(g.alts, function(a, b)
      if a.total ~= b.total then
        return a.total > b.total
      end
      return a.key < b.key
    end)
    items[#items + 1] = g
  end
  table.sort(items, function(a, b)
    local x, y = tostring(a.name or ""):lower(), tostring(b.name or ""):lower()
    if x ~= y then
      return x < y
    end
    return tostring(a.id) < tostring(b.id)
  end)
  local more = math.max(0, #items - Search.MAX_ITEMS)
  for i = #items, Search.MAX_ITEMS + 1, -1 do
    items[i] = nil
  end
  return { items = items, more = more }
end

-- "15 bags, 5 bank", in a fixed order.
function Search.Places(alt)
  local parts = {}
  for _, place in ipairs(Search.PLACES) do
    local n = alt.places[place]
    if n then
      parts[#parts + 1] = n .. " " .. PLACE_TEXT[place]
    end
  end
  return table.concat(parts, ", ")
end

-- Where to look for it in the alt panel: the tab with the most of it.
function Search.Tab(alt)
  local best, most = "bags", -1
  for _, place in ipairs(Search.PLACES) do
    local n = alt.places[place] or 0
    if n > most then
      best, most = place, n
    end
  end
  return best == "equipped" and "gear" or best
end

return Search
