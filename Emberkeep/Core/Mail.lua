-- Mail: the mail with items or gold in each character's mailbox when they last
-- opened it, plus what your other characters have mailed them since. Pure Lua.
-- Mail expires; this says when, so nothing is lost by accident.
local _, ns = ...
ns = ns or {}
local Mail = {}
ns.Mail = Mail

local DAY = 86400
Mail.SENT_DAYS = 30 -- mail you send lasts this long before it goes back
Mail.DELIVERY = 3600 -- mail with items can take this long to arrive
Mail.WARN_WITHIN = 3 * DAY
Mail.SOON = 7 * DAY

local function worthKeeping(m)
  return #(m.items or {}) > 0 or (m.money or 0) > 0
end

-- "jango" from "Jango-Nightfall" or "Jango Pheu", to match a sender to a character.
local function firstName(name)
  return (tostring(name or ""):gsub("%-.*$", ""):match("^%s*(%S*)") or ""):lower()
end

-- reading: { mails = { { sender, subject, money, daysLeft, returns, items =
-- { { link, count } } } }, total } for the inbox, read while it's open. The game
-- shows at most 50 mails at a time; total counts them all. Only mail with items
-- or gold is kept. An inbox with none is a real reading, but not an empty one
-- while the game says there is mail (not loaded yet). Mail sent to this
-- character is dropped once a mail from its sender shows in the inbox, or once
-- the inbox is read more than an hour after it was sent.
function Mail.Observe(c, reading, now)
  if not reading or not reading.mails or reading.incomplete then
    return false
  end
  if #reading.mails == 0 and (reading.total or 0) > 0 then
    return false
  end
  local hidden = math.max(0, (reading.total or #reading.mails) - #reading.mails)
  local inbox = {}
  for _, m in ipairs(reading.mails) do
    if worthKeeping(m) then
      local items = {}
      for j, item in ipairs(m.items or {}) do
        items[j] = { link = item.link, count = item.count }
      end
      inbox[#inbox + 1] = {
        sender = m.sender,
        subject = m.subject,
        money = m.money or 0,
        items = items,
        expires = m.daysLeft and (now + math.floor(m.daysLeft * DAY)) or nil,
        returns = m.returns,
      }
    end
  end
  local senders = {}
  for _, m in ipairs(reading.mails) do
    senders[firstName(m.sender)] = true
  end
  local sent = {}
  for _, m in ipairs(c.mail and c.mail.sent or {}) do
    local arrived = senders[firstName(m.fromName or m.from)]
    local young = now - m.at < Mail.DELIVERY
    -- While the game hides some mail, what was sent may be among it.
    if m.expires > now and (hidden > 0 or (young and not arrived)) then
      sent[#sent + 1] = m
    end
  end
  c.mail = { inbox = inbox, sent = sent, at = now, hidden = hidden }
  return true
end

-- Something you mailed to one of your characters: { from, fromName, items =
-- { { link, count } }, money, returned, daysLeft }. from is shown; fromName is
-- the sender's name as the inbox shows it. Mail you send back (returned) keeps
-- what time it had left, as far as anyone can tell, and is deleted when that
-- runs out. Kept until it shows in their mailbox.
function Mail.Sent(c, mail, now)
  if not c or not worthKeeping(mail) then
    return false
  end
  c.mail = c.mail or { inbox = {}, sent = {} }
  c.mail.sent = c.mail.sent or {}
  table.insert(c.mail.sent, {
    from = mail.from,
    fromName = mail.fromName,
    items = mail.items or {},
    money = mail.money or 0,
    at = now,
    expires = now + math.floor((mail.returned and mail.daysLeft or Mail.SENT_DAYS) * DAY),
    returned = mail.returned or nil,
  })
  return true
end

-- What a window shows, or nil if the mailbox was never opened and nothing was
-- sent. Rows soonest to expire first: { sender, subject, items, money,
-- expiresIn (seconds, or nil), returns, sent }.
function Mail.View(c, now)
  local saved = c.mail
  if not saved then
    return nil
  end
  local rows = {}
  for _, m in ipairs(saved.inbox or {}) do
    rows[#rows + 1] = {
      sender = m.sender,
      subject = m.subject,
      items = m.items,
      money = m.money,
      expiresIn = m.expires and (m.expires - now) or nil,
      returns = m.returns,
    }
  end
  for _, m in ipairs(saved.sent or {}) do
    if m.expires > now then -- gone back to you by now
      rows[#rows + 1] = {
        sender = m.from,
        subject = m.returned and "Sent back by you" or "Sent by you",
        items = m.items,
        money = m.money,
        expiresIn = m.expires - now,
        returns = not m.returned,
        sent = true,
      }
    end
  end
  table.sort(rows, function(a, b)
    local x, y = a.expiresIn or math.huge, b.expiresIn or math.huge
    if x ~= y then
      return x < y
    end
    return tostring(a.sender) < tostring(b.sender)
  end)
  return { rows = rows, at = saved.at, hidden = saved.hidden or 0 }
end

-- The soonest any mail expires: seconds left, and whether it's then deleted
-- instead of returned. nil when there's none, or none within `within`.
function Mail.Soonest(c, now, within)
  local view = Mail.View(c, now)
  local row = view and view.rows[1]
  if not (row and row.expiresIn) or row.expiresIn > (within or math.huge) then
    return nil
  end
  return row.expiresIn, row.returns == false
end

-- "2 mails, 1 expiring within 3 days", for the line above the list.
function Mail.Summary(view)
  local count = #view.rows
  local hidden = view.hidden or 0
  local more = hidden > 0 and (", " .. hidden .. " more the game didn't show") or ""
  if count == 0 then
    return hidden > 0 and ("Nothing to collect in the mail shown" .. more) or "Nothing to collect"
  end
  local text = count == 1 and "1 mail to collect" or (count .. " mails to collect")
  local soon = 0
  for _, row in ipairs(view.rows) do
    if row.expiresIn and row.expiresIn <= Mail.WARN_WITHIN then
      soon = soon + 1
    end
  end
  if soon > 0 then
    text = text .. ", " .. soon .. " expiring within 3 days"
  end
  return text .. more
end

-- "27 days left", "5h 20m left", or "expired".
function Mail.Left(seconds, Format)
  if not seconds then
    return ""
  elseif seconds <= 0 then
    return "expired"
  elseif seconds >= 2 * DAY then
    return math.floor(seconds / DAY) .. " days left"
  end
  return Format.Duration(seconds) .. " left"
end

-- "2d", "20h" or "now", for the Overview tab's Mail column.
function Mail.Short(seconds)
  if seconds <= 0 then
    return "now"
  elseif seconds >= 2 * DAY then
    return math.floor(seconds / DAY) .. "d"
  end
  return math.max(1, math.floor(seconds / 3600)) .. "h"
end

-- How urgent: "warn" within 3 days, "soon" within a week, or nil.
function Mail.Urgency(seconds)
  if seconds and seconds <= Mail.WARN_WITHIN then
    return "warn"
  elseif seconds and seconds <= Mail.SOON then
    return "soon"
  end
  return nil
end

return Mail
