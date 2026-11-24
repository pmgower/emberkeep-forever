-- Roster: every character the player has logged in on, keyed "Name-Realm".
-- Pure Lua. Adapters hand it sightings (what the game reported just now);
-- it keeps the last good value of each field, so a blank read never wipes
-- what was saved. While logging out the game can also report level 0 and
-- 0 gold, so a logout sighting's zero gold is ignored too.
local _, ns = ...
ns = ns or {}
local Roster = {}
ns.Roster = Roster

-- Forever names have a first name and a surname, so the key holds both:
-- "Jango Fett-Forever". Without a surname it's "Jango-Forever".
function Roster.Key(name, realm, surname)
  local full = tostring(name)
  if surname ~= nil and surname ~= "" then
    full = full .. " " .. tostring(surname)
  end
  return full .. "-" .. tostring(realm)
end

-- "Jango Fett", or "Jango" when the player picked first names only.
function Roster.DisplayName(c, hideSurnames)
  if c.surname and c.surname ~= "" and not hideSurnames then
    return tostring(c.name) .. " " .. c.surname
  end
  return tostring(c.name)
end

local function present(v)
  return v ~= nil and v ~= ""
end

-- sighting: { name, realm, class, classFile, race, faction, level, money, zone,
-- subzone }
-- opts.loggingOut: the sighting was read during logout.
-- Returns the character's key, or nil when the sighting has no name or realm.
function Roster.Observe(store, sighting, now, opts)
  local loggingOut = opts and opts.loggingOut
  if not (present(sighting.name) and present(sighting.realm)) then
    return nil
  end
  local key = Roster.Key(sighting.name, sighting.realm, sighting.surname)
  local c = store[key]
  if not c and present(sighting.surname) then
    -- Saved before surnames were read: move it to the full-name key.
    local old = Roster.Key(sighting.name, sighting.realm)
    c, store[old] = store[old], nil
  end
  c = c or {}
  c.name, c.realm = sighting.name, sighting.realm
  if present(sighting.surname) then
    c.surname = sighting.surname
  end
  for _, field in ipairs({ "class", "classFile", "race", "faction", "zone" }) do
    if present(sighting[field]) then
      c[field] = sighting[field]
    end
  end
  -- Subzone goes with the zone: a fresh zone read with no subzone clears an
  -- old one, but an empty logout read keeps both.
  if present(sighting.zone) then
    c.subzone = present(sighting.subzone) and sighting.subzone or nil
  end
  if type(sighting.level) == "number" and sighting.level > 0 then
    c.level = sighting.level
  end
  if
    type(sighting.money) == "number" and (sighting.money > 0 or (sighting.money == 0 and not loggingOut))
  then
    c.money = sighting.money
  end
  c.lastSeen = now
  store[key] = c
  return key
end

-- Removes every character whose first or full name matches (any realm,
-- any case).
-- Returns how many were removed.
function Roster.Forget(store, name)
  local wanted, removed = tostring(name):lower(), 0
  for key, c in pairs(store) do
    if tostring(c.name):lower() == wanted or Roster.DisplayName(c):lower() == wanted then
      store[key] = nil
      removed = removed + 1
    end
  end
  return removed
end

-- Removes one character by its key. Returns true if it was there.
function Roster.ForgetKey(store, key)
  local found = store[key] ~= nil
  store[key] = nil
  return found
end

-- Characters as a list of copies (each with its key), highest level first,
-- then by name. Copies, so nothing a window adds ends up in SavedVariables.
function Roster.Characters(store)
  local list = {}
  for key, c in pairs(store) do
    local copy = { key = key }
    for k, v in pairs(c) do
      copy[k] = v
    end
    list[#list + 1] = copy
  end
  table.sort(list, function(a, b)
    if (a.level or 0) ~= (b.level or 0) then
      return (a.level or 0) > (b.level or 0)
    end
    return tostring(a.name) < tostring(b.name)
  end)
  return list
end

return Roster
