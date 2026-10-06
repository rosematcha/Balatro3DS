local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")

local suite = T.suite()

suite.test("game speed is scoped to an active run", function()
    local game = bootstrap.new_game(1201)
    game.SETTINGS.GAMESPEED = 4

    game.STAGE = game.STAGES.MAIN_MENU
    T.assert_eq(game:speed_factor(0.1), 1, "main menu")

    game.STAGE = game.STAGES.RUN
    game.STATE = game.STATES.SELECTING_HAND
    T.assert_eq(game:speed_factor(0.1), 4, "active run")

    game.STATE = game.STATES.PAUSED
    T.assert_eq(game:speed_factor(0.1), 0, "paused run freezes scaled time")

    game.STATE = game.STATES.SELECTING_HAND
    game.screenwipe = true
    T.assert_eq(game:speed_factor(0.1), 1, "screen wipe")
end)

suite.test("only reference game-speed choices are accepted", function()
    local game = bootstrap.new_game(1202)
    for _, speed in ipairs({ 0.5, 1, 2, 4 }) do
        game:set_game_speed(speed)
        T.assert_eq(game.SETTINGS.GAMESPEED, speed, "accepted speed")
    end
    game:set_game_speed(3)
    T.assert_eq(game.SETTINGS.GAMESPEED, 4, "non-reference speed rejected")
end)

suite.test("wall-time effects do not inherit game speed", function()
    local game = bootstrap.new_game(1203)
    game.STAGE = game.STAGES.RUN
    game.STATE = game.STATES.SELECTING_HAND
    game.real_dt = 0.1
    game.jiggle = 1
    game._jiggle_t = 0

    game:update(0.4, 0.1)

    T.assert_near(game._jiggle_t, 0.1, 1e-9, "shake uses real time")
    -- The collector used to be driven off a real-time accumulator, which is what this line
    -- checked. It is now driven per frame -- see `Game.GC` -- so what has to hold instead is
    -- that a frame steps it exactly once whatever the game speed is; tests/test_gc.lua carries
    -- the rest of that.
    T.assert_eq(game._gc_heap_frames, 1, "one frame, one collector step")
end)

suite.test("opening deals wait for the reference draw beat", function()
    local game = bootstrap.new_game(1204)
    local hand = Hand(game)
    game.hand = hand
    game.deck = Deck()
    game.deck.cards = {
        { rank = 2, suit = "Hearts" },
        { rank = 3, suit = "Clubs" },
    }

    hand:fill_from_deck()
    T.assert_eq(#hand.cards, 0, "first card must not bypass the draw queue")
    T.assert_eq(#hand._draw_queue, 2, "opening cards queue together")

    -- The reference's `delay(0.3)` deal lead-in plus its 0.1 draw beat: the first card lands
    -- 0.4 s of TOTAL-clock time after the deal is queued (`state_events.lua:369`).
    hand:update(0.399)
    T.assert_eq(#hand.cards, 0, "card waits through the lead-in and most of the beat")
    hand:update(0.001)
    T.assert_eq(#hand.cards, 1, "card arrives after the 0.4 second TOTAL-clock lead-in plus beat")
end)

suite.test("discard flights use real time after their scaled queue beat", function()
    local game = bootstrap.new_game(1205)
    local removed = 0
    local node = {
        T = { x = 0, y = 0 },
        VT = { x = 0, y = 0 },
    }
    game.remove = function(_, removed_node)
        T.assert_eq(removed_node, node, "only the discarded node is removed")
        removed = removed + 1
    end
    game.pending_discard = { { node = node, fly_after = 0 } }

    -- This is one 4x logic frame but only 100 ms of real motion. The old scaled 0.35 s
    -- timeout removed the card here; it must remain until its real-time spring arrives.
    game:update(0.4, 0.1)
    T.assert_eq(removed, 0, "discard is not removed on scaled time")
    T.assert_eq(#game.pending_discard, 1, "discard remains in flight")

    node.VT.x, node.VT.y = node.T.x, node.T.y
    game:update(0.4, 0.1)
    T.assert_eq(removed, 1, "discard clears once its visual motion reaches the target")
    T.assert_eq(#game.pending_discard, 0, "completed discard leaves the queue")
end)

suite.test("card cadence clock caps at twice real time", function()
    local game = bootstrap.new_game(1206)
    game.real_dt = 0.02
    T.assert_near(game:card_beat_dt(0.08), 0.04, 1e-9, "4x step clamps to 2x real")
    T.assert_near(game:card_beat_dt(0.02), 0.02, 1e-9, "1x step passes through")
    T.assert_near(game:card_beat_dt(0.01), 0.01, 1e-9, "slow-motion step passes through")
    game.real_dt = nil
    T.assert_near(game:card_beat_dt(0.08), 0.08, 1e-9, "no real clock, no clamp")
end)

suite.test("deal stagger survives 4x game speed", function()
    local game = bootstrap.new_game(1207)
    local hand = Hand(game)
    game.hand = hand
    game.deck = Deck()
    game.deck.cards = {
        { rank = 2, suit = "Hearts" },
        { rank = 3, suit = "Clubs" },
    }
    game.real_dt = 0.02

    hand:fill_from_deck()
    -- The lead-in plus first beat is 0.4 on the cadence clock. Each 4x logic frame is 0.08
    -- scaled but clamps to 0.04 at the 2x-real cap, so the first card needs ten frames --
    -- five would have sufficed unclamped.
    for _ = 1, 9 do hand:update(0.08) end
    T.assert_eq(#hand.cards, 0, "beat holds at the real-time cap")
    hand:update(0.08)
    T.assert_eq(#hand.cards, 1, "card lands once the capped clock reaches the beat")
end)

return suite
