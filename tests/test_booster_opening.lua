local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")
local BoosterPackUI = require("booster_pack_ui")

local suite = T.suite()

local function offer()
    return {
        kind = "booster",
        pack = "standard",
        size = "normal",
        card_count = 3,
        picks_granted = 1,
        booster_sprite_index = 2,
    }
end

suite.test("booster wrapper bursts before choices become interactive", function()
    local game = bootstrap.new_game(1801)
    game.STATE = game.STATES.SHOP
    game:begin_booster_session(offer(), { x = 20, y = 30, w = 72, h = 95 })

    local sess = game.booster_session
    T.assert_eq(sess.opening_phase, "move", "wrapper starts at its shop position")
    T.assert_eq(#sess.choice_nodes, 0, "contents do not exist during the wrapper animation")

    game:_update_booster_opening(BoosterPackUI.PACK_MOVE_DURATION)
    T.assert_eq(sess.opening_phase, "buildup", "wrapper moves to the opening position")
    game:_update_booster_opening(BoosterPackUI.PACK_BURST_DURATION - 0.001)
    T.assert_eq(#sess.choice_nodes, 0, "contents wait for the release beat")
    game:_update_booster_opening(0.001)

    T.assert_eq(sess.opening_phase, "reveal", "release starts materialization")
    T.assert_eq(#sess.choice_nodes, 3, "release creates every pack choice")
    for _, node in pairs(sess.choice_nodes) do
        T.assert_false(node.states.click.can, "new choice remains locked during materialization")
    end
    T.assert_true(game:handle_gamepad_booster("b"), "opening consumes cancel instead of skipping")
    T.assert_eq(game.booster_session, sess, "opening session survives cancel")

    game:_update_booster_opening(BoosterPackUI.CARD_REVEAL_DURATION)
    T.assert_eq(sess.opening_phase, "ready", "materialization finishes")
end)

suite.test("game speed uses the reference square-root pack timing", function()
    local game = bootstrap.new_game(1802)
    game.STATE = game.STATES.SHOP
    game.SETTINGS.GAMESPEED = 4
    game:begin_booster_session(offer())
    game:_update_booster_opening(BoosterPackUI.PACK_MOVE_DURATION)
    game:_update_booster_opening(BoosterPackUI.PACK_BURST_DURATION)
    T.assert_eq(game.booster_session.opening_phase, "buildup", "4x TOTAL clock waits two logic seconds")
    game:_update_booster_opening(BoosterPackUI.PACK_BURST_DURATION)
    T.assert_eq(game.booster_session.opening_phase, "reveal", "sqrt speed duration matches reference")
end)

--------------------------------------------------------------------------------
-- Loading the pack's art off the release frame
--
-- Every choice node is constructed on the single frame the wrapper bursts, and each
-- construction blocks on `newImage` - a SD read plus a texture build, ~24 ms on console. Five
-- of those in one frame is the freeze the player sees on the one frame of the animation they
-- are actually watching. The wrapper's move and buildup are 1.7 s of dead time, so the loads
-- belong there.
--------------------------------------------------------------------------------

local function arcana_offer()
    return {
        kind = "booster",
        pack = "arcana",
        size = "mega",
        card_count = 5,
        picks_granted = 2,
        booster_sprite_index = 0,
    }
end

--- Step the wrapper to the instant before it releases, a frame at a time, so the warming pass
--- gets the frames it would get in the running game.
local function run_to_release(game, frames)
    local sess = game.booster_session
    local total = BoosterPackUI.PACK_MOVE_DURATION + BoosterPackUI.PACK_BURST_DURATION
    local dt = total / frames
    for _ = 1, frames do
        if sess.opening_phase == "reveal" or sess.opening_phase == "ready" then break end
        game:_update_booster_opening(dt)
    end
    return sess
end

suite.test("a pack's art is loaded before the frame that reveals it", function()
    local game = bootstrap.new_game(4402)
    game.STAGE = game.STAGES.RUN
    game.STATE = game.STATES.SHOP
    game:begin_booster_session(arcana_offer(), { x = 20, y = 30, w = 72, h = 95 })
    local sess = game.booster_session
    T.assert_true(#sess.choices > 1, "a mega pack offers several choices")

    -- 100 frames is what 1.7 s of wrapper animation is at 60 fps.
    run_to_release(game, 100)
    T.assert_eq(sess.opening_phase, "buildup", "still short of the release")

    -- The release frame itself: with warming done, constructing the nodes must not load.
    local before = #love._test.images
    game:_update_booster_opening(BoosterPackUI.PACK_BURST_DURATION)
    T.assert_eq(sess.opening_phase, "reveal", "the pack released")
    T.assert_true(next(sess.choice_nodes) ~= nil, "and built its choices")
    T.assert_eq(#love._test.images - before, 0,
        "the release frame loads nothing; the wrapper animation already did")
end)

--- The budget is one load a frame: a 24 ms load already overruns a 16.7 ms frame, so stacking
--- two is the freeze in miniature.
suite.test("warming loads at most one sprite a frame", function()
    local game = bootstrap.new_game(4403)
    game.STAGE = game.STAGES.RUN
    game.STATE = game.STATES.SHOP
    game:begin_booster_session(arcana_offer(), { x = 20, y = 30, w = 72, h = 95 })

    for _ = 1, 40 do
        local before = #love._test.images
        game:_update_booster_opening(0.01)
        T.assert_true(#love._test.images - before <= 1, "never more than one load in a frame")
    end
end)

--- Warming is scheduling, not caching: the same sprites still have to be there at the end.
suite.test("warmed choices still resolve their own art", function()
    local game = bootstrap.new_game(4404)
    game.STAGE = game.STAGES.RUN
    game.STATE = game.STATES.SHOP
    game:begin_booster_session(arcana_offer(), { x = 20, y = 30, w = 72, h = 95 })
    run_to_release(game, 100)
    game:_update_booster_opening(BoosterPackUI.PACK_BURST_DURATION)

    for _, node in pairs(game.booster_session.choice_nodes) do
        T.assert_not_nil(node.atlas or node.front_sprite, "the node found its art")
        if node.atlas then
            T.assert_not_nil(node.atlas.image, "and the image is resident")
            T.assert_not_nil(node.quad, "and it has a quad cut from it")
        end
    end
end)

--- The negative-edition offset is the one place a warm can silently load the wrong file: it
--- would warm the base sprite, leave the real one to block the release frame, and look
--- correct until a negative consumable turned up in a pack.
suite.test("the sprite index a warm loads is the one the constructor asks for", function()
    local base = Consumable.sprite_index_for({ index = 7 })
    local negative = Consumable.sprite_index_for({ index = 7, edition = "negative" })
    T.assert_eq(base, 7, "a plain consumable loads its own index")
    T.assert_ne(negative, base, "a negative copy is a different sprite")

    local node = Consumable(0, 0, { id = "c_test", kind = "tarot", index = 7,
        edition = "negative" })
    T.assert_eq(node.index, negative, "and it is the index the constructor resolved")
end)

return suite
