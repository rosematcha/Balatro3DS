local T = require("tests.testlib")
local TicketStrip = require("ticket_strip")
local challenges = require("challenge_catalog")

local suite = T.suite()

suite.test("ticket geometry reserves a bounded stub and body", function()
    local r = TicketStrip.layout(10, 20, 200, 30, 60)
    T.assert_eq(r.stub_w, 60)
    T.assert_eq(r.body_x, 70)
    T.assert_eq(r.body_w, 140)
    T.assert_true(r.notch >= 2)
end)

suite.test("challenge tickets summarize rules and loadout", function()
    local facts = TicketStrip.challenge_facts(challenges[16]) -- Blast Off
    local text = table.concat(facts, " | ")
    T.assert_true(text:find("Hands: 2", 1, true) ~= nil)
    T.assert_true(text:find("Discards: 2", 1, true) ~= nil)
    T.assert_true(text:find("Starting Jokers: 2", 1, true) ~= nil)
    T.assert_true(text:find("Starting Vouchers: 2", 1, true) ~= nil)
end)

suite.test("a rule-light challenge still has a readable fact", function()
    local facts = TicketStrip.challenge_facts({})
    T.assert_eq(facts[1], "Special rules apply")
end)

return suite
