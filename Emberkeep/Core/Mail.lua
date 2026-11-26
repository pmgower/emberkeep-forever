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

-- reading: { mails = { { sender, subject, money, daysLeft, returns, items =
-- { { link, count } } } } } for the whole inbox, read while it's open. Only mail
-- with items or gold is kept; an inbox with none is a real reading. Mail sent
-- to this character is dropped once the inbox has been read, except mail sent
-- within the last hour, which may not have arrived yet.
function Mail.Observe(c, reading, now)
  if not reading or not reading.mails then
    return false
  end
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
  local sent = {}
  for _, m in ipairs(c.mail and c.mail.sent or {}) do
    if now - m.at < Mail.DELIVERY then
      sent[#sent + 1] = m
    end
  end
  c.mail = { inbox = inbox, sent = sent, at = now }
  return true
end

-- Something you mailed to one of your characters: { from, items = { { link,
-- count } }, money }. Kept until they next open their mailbox.
function Mail.Sent(c, mail, now)
  if not c or not worthKeeping(mail) then
    return false
  end
  c.mail = c.mail or { inbox = {}, sent = {} }
  c.mail.sent = c.mail.sent or {}
  table.insert(c.mail.sent, {
    from = mail.from,
    items = mail.items or {},
    money = mail.money or 0,
    at = now,
    expires = now + Mail.SENT_DAYS * DAY,
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
    rows[#rows + 1] = {
      sender = m.from,
      subject = "Sent by you",
      items = m.items,
      money = m.money,
      expiresIn = m.expires - now,
      returns = true,
      sent = true,
    }
  end
  table.sort(rows, function(a, b)
    local x, y = a.expiresIn or math.huge, b.expiresIn or math.huge
    if x ~= y then
      return x < y
    end
    return tostring(a.sender) < tostring(b.sender)
  end)
  return { rows = rows, at = saved.at }
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
  if count == 0 then
    return "Nothing to collect"
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
  return text
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
