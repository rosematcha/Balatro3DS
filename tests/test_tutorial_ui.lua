local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")
local TutorialUI = require("tutorial_ui")

local suite = T.suite()

suite.test("fresh profiles get contextual guidance", function()
    local game = bootstrap.new_game(7501)
    game.SETTINGS.TUTORIAL_COMPLETE = false
    game.STATE = game.STATES.BLIND_SELECT
    game.round = 1
    game.SETTINGS.TUTORIAL_STAGE = 1
    T.assert_eq(TutorialUI.step(game).code, "01")
    game.STATE = game.STATES.SELECTING_HAND
    game.handsPlayed = 0
    game.SETTINGS.TUTORIAL_STAGE = 2
    T.assert_eq(TutorialUI.step(game).code, "02")
    game.STATE = game.STATES.SHOP
    game.SETTINGS.TUTORIAL_STAGE = 3
    T.assert_eq(TutorialUI.step(game).code, "03")
end)

suite.test("guidance continues from the first shop through the Big Blind", function()
    local game = bootstrap.new_game(7502)
    game.SETTINGS.TUTORIAL_COMPLETE = false
    game.SETTINGS.TUTORIAL_STAGE = 3
    game.STATE = game.STATES.SHOP
    TutorialUI.update(game)
    T.assert_false(game.SETTINGS.TUTORIAL_COMPLETE)
    game.STATE = game.STATES.BLIND_SELECT
    TutorialUI.update(game)
    T.assert_eq(game.SETTINGS.TUTORIAL_STAGE, 4)
    T.assert_false(game.SETTINGS.TUTORIAL_COMPLETE)
    game.current_blind_index = 2
    game.STATE = game.STATES.SELECTING_HAND
    TutorialUI.update(game)
    T.assert_eq(game.SETTINGS.TUTORIAL_STAGE, 5)
    game.handsPlayed = 1
    TutorialUI.update(game)
    T.assert_true(game.SETTINGS.TUTORIAL_COMPLETE)
    T.assert_nil(TutorialUI.step(game))
end)

suite.test("legacy progressed profiles do not receive first-run guidance", function()
    local game = bootstrap.new_game(7503)
    local normalized = game:normalize_settings({ WINS = 1 })
    T.assert_true(normalized.TUTORIAL_COMPLETE)
end)

suite.test("the settings action permanently skips an active tutorial", function()
    local game = bootstrap.new_game(7504)
    game.SETTINGS.TUTORIAL_COMPLETE = false
    game.SETTINGS.TUTORIAL_STAGE = 4
    game._tutorial_shop_seen = true
    game._tutorial_voice_step = "04"
    T.assert_true(game:skip_tutorial())
    T.assert_true(game.SETTINGS.TUTORIAL_COMPLETE)
    T.assert_nil(game.SETTINGS.TUTORIAL_STAGE)
    T.assert_nil(TutorialUI.step(game))
    T.assert_false(game:skip_tutorial())
end)

return suite
