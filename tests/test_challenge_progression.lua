local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")

local suite = T.suite()

local function fresh(seed)
    local game = bootstrap.new_game(seed)
    game.SETTINGS.CHALLENGE_WINS = {}
    game.SETTINGS.CHALLENGES_UNLOCKED = 0
    game.unlocks = game:build_unlocks()
    game:apply_unlocks(game.unlocks)
    return game
end

suite.test("five distinct White Stake deck wins reveal the first five challenges", function()
    local game = fresh(7201)
    for i = 1, 4 do
        local deck = DECK_SELECT_DEFS[i]
        game.unlocks[deck.id].stakes.stake_white.defeated = true
    end
    T.assert_eq(game:refresh_challenge_unlocks(), 0)
    game.unlocks[DECK_SELECT_DEFS[5].id].stakes.stake_white.defeated = true
    T.assert_eq(game:refresh_challenge_unlocks(), 5)
    T.assert_true(game:is_challenge_unlocked(CHALLENGE_DEFS[5].id))
    T.assert_false(game:is_challenge_unlocked(CHALLENGE_DEFS[6].id))
end)

suite.test("completed challenges keep a five-challenge runway", function()
    local game = fresh(7202)
    game.SETTINGS.CHALLENGES_UNLOCKED = 5
    for i = 1, 3 do game.SETTINGS.CHALLENGE_WINS[CHALLENGE_DEFS[i].id] = true end
    T.assert_eq(game:refresh_challenge_unlocks(), 8)
    for i = 1, #CHALLENGE_DEFS do game.SETTINGS.CHALLENGE_WINS[CHALLENGE_DEFS[i].id] = true end
    T.assert_eq(game:refresh_challenge_unlocks(), 20)
end)

suite.test("locked challenges cannot start", function()
    local game = fresh(7203)
    game.start_new_run_from_main_menu = function() error("locked challenge started") end
    T.assert_false(game:start_challenge_run(CHALLENGE_DEFS[1].id))
    game.SETTINGS.CHALLENGES_UNLOCKED = 5
    local started = false
    game.start_new_run_from_main_menu = function() started = true end
    T.assert_true(game:start_challenge_run(CHALLENGE_DEFS[1].id))
    T.assert_true(started)
end)

return suite
