local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")

local suite = T.suite()

suite.test("master volume is adjustable and survives settings normalization", function()
    local game = bootstrap.new_game(7301)
    game:set_master_volume(37, { skip_save = true })
    T.assert_eq(game:get_master_volume(), 37)
    T.assert_eq(game:snapshot_settings().SOUND.volume, 37)
    T.assert_eq(game:normalize_settings({ SOUND = { volume = 142 } }).SOUND.volume, 100)
end)

suite.test("ordinary cards default to the standard atlas", function()
    local game = bootstrap.new_game(7302)
    game.SETTINGS.HIGH_CONTRAST_CARDS = false
    local card = Card(0, 0, 1, 1, { rank = 14, suit = "Spades" })
    T.assert_eq(card.rank_atlas_name, "cards_1")
end)

suite.test("high contrast switches existing and future ordinary cards", function()
    local game = bootstrap.new_game(7303)
    game.SETTINGS.HIGH_CONTRAST_CARDS = false
    local ordinary = Card(0, 0, 1, 1, { rank = 10, suit = "Hearts" })
    local explicit = Card(0, 0, 1, 1, { rank = 9, suit = "Clubs" }, nil,
        { rank_atlas_name = "cards_1" })
    game:set_high_contrast_cards(true)
    T.assert_true(game:high_contrast_cards_enabled())
    T.assert_eq(ordinary.rank_atlas_name, "cards_2")
    T.assert_eq(explicit.rank_atlas_name, "cards_1")
    local future = Card(0, 0, 1, 1, { rank = 8, suit = "Diamonds" })
    T.assert_eq(future.rank_atlas_name, "cards_2")
end)

suite.test("accessibility settings persist", function()
    local game = bootstrap.new_game(7304)
    game.SETTINGS.HIGH_CONTRAST_CARDS = true
    local snapshot = game:snapshot_settings()
    T.assert_true(snapshot.HIGH_CONTRAST_CARDS)
    T.assert_true(game:normalize_settings(snapshot).HIGH_CONTRAST_CARDS)
end)

return suite
