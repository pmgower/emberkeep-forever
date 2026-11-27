local Mail = dofile("Emberkeep/Core/Mail.lua")
local Format = dofile("Emberkeep/Core/Format.lua")

local DAY = 86400

local function mail(sender, daysLeft, items, money, returns)
  local m = { sender = sender, subject = "Hi", daysLeft = daysLeft, items = items or {} }
  m.money, m.returns = money, returns
  return m
end

local cloth = { { link = "item:2589", count = 20 } }

describe("Mail.Observe", function()
  it("keeps only mail with items or gold, with when each expires", function()
    local c = {}
    local reading = { mails = { mail("A", 2.5, cloth), mail("B", 20, nil, 500), mail("C", 9) } }
    assert.is_true(Mail.Observe(c, reading, 1000))
    assert.are.equal(2, #c.mail.inbox)
    assert.are.equal(1000 + 2.5 * DAY, c.mail.inbox[1].expires)
    assert.are.equal(1000, c.mail.at)
  end)

  it("saves an inbox with nothing to collect", function()
    local c = { mail = { inbox = { { items = cloth, money = 0 } }, sent = {} } }
    assert.is_true(Mail.Observe(c, { mails = {} }, 1000))
    assert.are.same({}, c.mail.inbox)
    assert.is_false(Mail.Observe(c, nil, 1000))
  end)

  it("ignores an empty inbox while the game says there's mail", function()
    local c = { mail = { inbox = { { items = cloth, money = 0 } }, sent = {} } }
    assert.is_false(Mail.Observe(c, { mails = {}, total = 3 }, 1000))
    assert.is_false(Mail.Observe(c, { mails = { mail("A", 2, cloth) }, incomplete = true }, 1000))
    assert.are.equal(1, #c.mail.inbox)
  end)

  it("keeps mail you sent until it shows up in their inbox", function()
    local c = {}
    Mail.Sent(c, { from = "Jango Pheu", fromName = "Jango", items = cloth }, 1000)
    Mail.Observe(c, { mails = {} }, 1000 + 600)
    assert.are.equal(1, #c.mail.sent, "not arrived yet")
    Mail.Observe(c, { mails = { mail("Jango", 30, cloth) } }, 1000 + 1200)
    assert.are.same({}, c.mail.sent, "arrived: shown once, from the inbox")
  end)

  it("drops mail you sent once their inbox is read an hour later", function()
    local c = {}
    Mail.Sent(c, { from = "Jango", items = cloth }, 1000)
    Mail.Sent(c, { from = "Jango", money = 100 }, 1000 + 2 * 3600)
    Mail.Observe(c, { mails = {} }, 1000 + 2.5 * 3600)
    assert.are.equal(1, #c.mail.sent)
    assert.are.equal(100, c.mail.sent[1].money)
  end)

  it("keeps mail you sent while the game hides some of their mail", function()
    local c = {}
    Mail.Sent(c, { from = "Jango", items = cloth }, 1000)
    local shown = {}
    for i = 1, 50 do
      shown[i] = mail("Vendor", 20)
    end
    Mail.Observe(c, { mails = shown, total = 60 }, 1000 + 5 * 3600)
    assert.are.equal(1, #c.mail.sent)
    assert.are.equal(10, c.mail.hidden)
    local view = Mail.View(c, 1000 + 5 * 3600)
    assert.are.equal("1 mail to collect, 10 more the game didn't show", Mail.Summary(view))
  end)
end)

describe("Mail.Sent", function()
  it("adds mail with items or gold, and ignores an empty letter", function()
    local c = {}
    assert.is_true(Mail.Sent(c, { from = "Jango", items = cloth }, 1000))
    assert.is_false(Mail.Sent(c, { from = "Jango", items = {} }, 1000))
    assert.is_false(Mail.Sent(nil, { from = "Jango", items = cloth }, 1000))
    assert.are.equal(1, #c.mail.sent)
    assert.are.equal(1000 + 30 * DAY, c.mail.sent[1].expires)
  end)

  it("keeps the time left on mail you send back, and says it will be deleted", function()
    local c = {}
    Mail.Sent(c, { from = "Jango", items = cloth, returned = true, daysLeft = 4 }, 0)
    local row = Mail.View(c, 0).rows[1]
    assert.are.equal(4 * DAY, row.expiresIn)
    assert.is_false(row.returns)
    assert.are.equal("Sent back by you", row.subject)
  end)

  it("stops showing it once it would have gone back to you", function()
    local c = {}
    Mail.Sent(c, { from = "Jango", items = cloth }, 0)
    assert.are.equal(1, #Mail.View(c, 29 * DAY).rows)
    assert.are.equal(0, #Mail.View(c, 31 * DAY).rows)
  end)
end)

describe("Mail.View", function()
  it("lists soonest to expire first, sent mail included", function()
    local c = {}
    Mail.Observe(c, { mails = { mail("Auction House", 1, cloth, 0, false), mail("Gamon", 9, nil, 500) } }, 0)
    Mail.Sent(c, { from = "Jango", items = cloth }, 0)
    local view = Mail.View(c, 0)
    assert.are.same({ "Auction House", "Gamon", "Jango" }, {
      view.rows[1].sender,
      view.rows[2].sender,
      view.rows[3].sender,
    })
    assert.is_true(view.rows[3].sent)
    assert.are.equal("3 mails to collect, 1 expiring within 3 days", Mail.Summary(view))
  end)

  it("is nil for a character whose mailbox was never opened", function()
    assert.is_nil(Mail.View({}, 0))
    assert.is_nil(Mail.Soonest({}, 0))
  end)
end)

describe("Mail.Soonest", function()
  it("says when the soonest mail expires and whether it's then deleted", function()
    local c = {}
    local mails = { mail("Auction House", 2, cloth, 0, false), mail("Gamon", 9, nil, 5, true) }
    Mail.Observe(c, { mails = mails }, 0)
    local left, deletes = Mail.Soonest(c, 0, 3 * DAY)
    assert.are.equal(2 * DAY, left)
    assert.is_true(deletes)
    assert.is_nil(Mail.Soonest(c, 0, DAY), "none within a day")
  end)
end)

describe("words", function()
  it("says how long is left", function()
    assert.are.equal("27 days left", Mail.Left(27.5 * DAY, Format))
    assert.are.equal("1d 4h left", Mail.Left(28 * 3600, Format))
    assert.are.equal("expired", Mail.Left(-5, Format))
    assert.are.equal("2d", Mail.Short(2.2 * DAY))
    assert.are.equal("20h", Mail.Short(20 * 3600))
    assert.are.equal("now", Mail.Short(0))
    assert.are.equal("warn", Mail.Urgency(2 * DAY))
    assert.are.equal("soon", Mail.Urgency(5 * DAY))
    assert.is_nil(Mail.Urgency(20 * DAY))
    assert.is_nil(Mail.Urgency(nil))
  end)
end)
