local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")

local suite = T.suite()

suite.test("playing-card edition accents do not consume a full scoring beat", function()
    bootstrap.load()
    T.assert_true(Hand.EDITION_EFFECT_INTERVAL < 0.25)
end)

suite.test("edition-only Jokers use the short accent interval", function()
    local game = bootstrap.new_game(7401)
    local joker = game:add_joker_by_def("j_egg", { edition = "polychrome" })
    T.assert_true(joker and true or false)
    local ctx = { chips = 10, mult = 2 }
    T.assert_true(game:begin_joker_emit("on_hand_scored", ctx))
    T.assert_eq(game._joker_emit_interval, game.JOKER_EDITION_EMIT_INTERVAL)
    T.assert_true(game._joker_emit_interval < 0.25)
end)

return suite
