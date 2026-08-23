local T = require("tests.testlib")
local M = require("milestone_queue")
local suite = T.suite()

local function game() return { SETTINGS = {} } end

suite.test("milestones queue in order and deduplicate within the session", function()
    local g = game()
    T.assert_true(M.push(g, "unlock", "First", "A"))
    T.assert_true(M.push(g, "unlock", "Second", "B"))
    T.assert_false(M.push(g, "unlock", "First", "A"))
    M.update(g, 0)
    T.assert_eq(g._milestone_active.title, "First")
    M.update(g, 3)
    M.update(g, 0)
    T.assert_eq(g._milestone_active.title, "Second")
end)

suite.test("milestones defer while a hand is scoring", function()
    local g = game()
    g.hand = { scoring = true }
    M.push(g, "unlock", "Held")
    M.update(g, 1)
    T.assert_nil(g._milestone_active)
    T.assert_eq(#g._milestone_queue, 1)
end)

return suite
