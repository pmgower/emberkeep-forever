-- Store: the shape of EmberkeepDB, the account-wide SavedVariables table.
-- Pure Lua: given whatever the game loaded (nil on first run), return a table
-- with every part the addon reads, keeping what is already there.
local _, ns = ...
ns = ns or {}
local Store = {}
ns.Store = Store

function Store.Ensure(db)
  db = type(db) == "table" and db or {}
  db.characters = type(db.characters) == "table" and db.characters or {}
  db.settings = type(db.settings) == "table" and db.settings or {}
  db.settings.window = type(db.settings.window) == "table" and db.settings.window or {}
  db.wellRested = nil -- before 0.3.1, one rank for every character
  return db
end

return Store
