local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")

local suite = T.suite()

suite.test("ALEEB123 matches reference pseudorandom fixtures", function()
    local game = bootstrap.new_game("ALEEB123")
    local fixtures = {
        { "boss", 0.68987431225199258 },
        { "Voucher1", 0.90698089005084093 },
        { "Tag1", 0.67360544174843784 },
        { "Tag1", 0.54799715498384005 },
        { "cdt1", 0.47735062460076771 },
        { "rarity1sho", 0.242198884411295 },
        { "Joker1sho1", 0.8238152333030675 },
        { "etperpoll1", 0.38744306234294212 },
        { "edisho1", 0.50934458864075305 },
        { "shop_pack1", 0.91161530222338483 },
    }
    for _, fixture in ipairs(fixtures) do
        T.assert_near(game:random(fixture[1]), fixture[2], 1e-15, fixture[1])
    end
end)

suite.test("seed input follows the base game's corpus", function()
    local game = bootstrap.new_game("ALEEB123")
    T.assert_eq(game:normalize_run_seed("0"), "O")
    T.assert_eq(game:normalize_run_seed("a1"), "A1")
    T.assert_eq(game:normalize_run_seed("12345678"), "12345678")
    T.assert_nil(game:normalize_run_seed(""))
    T.assert_nil(game:normalize_run_seed("123456789"))
end)

suite.test("the first shop starts with a normal Buffoon Pack", function()
    local game = bootstrap.new_game("ALEEB123")
    game:initialize_run_loop()
    game:roll_shop_offers()
    game:roll_shop_boosters()

    local first = game.shop_booster_offers[1]
    T.assert_eq(first.pack, "buffoon")
    T.assert_eq(first.size, "normal")
    T.assert_true(first.center_key == "p_buffoon_normal_1"
        or first.center_key == "p_buffoon_normal_2")
    T.assert_true(game.first_shop_buffoon)
end)

suite.test("ALEEB123 reproduces the reference first shop and opening deal", function()
    local game = bootstrap.new_game("ALEEB123")
    game:initialize_run_loop()
    T.assert_eq(game.current_boss_blind_id, "bl_pillar")
    T.assert_eq(game.current_round_voucher_id, "v_planet_merchant")
    T.assert_eq(game.skips[1], 4, "Coupon Tag")
    T.assert_eq(game.skips[2], 12, "Boss Tag")

    game:roll_shop_offers()
    T.assert_eq(game.shop_offers[1].id, "j_fortune_teller")
    T.assert_eq(game.shop_offers[2].id, "j_mime")
    game:roll_shop_boosters()
    T.assert_eq(game.shop_booster_offers[1].center_key, "p_buffoon_normal_1")
    T.assert_eq(game.shop_booster_offers[2].center_key, "p_buffoon_normal_2")

    game:prepare_hand_for_new_blind()
    local expected = {
        { "Hearts", 3 }, { "Diamonds", 12 }, { "Spades", 5 }, { "Clubs", 2 },
        { "Clubs", 5 }, { "Diamonds", 2 }, { "Hearts", 10 }, { "Spades", 9 },
    }
    for i, card in ipairs(game.hand._draw_queue) do
        T.assert_eq(card.suit, expected[i][1], "opening card " .. i .. " suit")
        T.assert_eq(card.rank, expected[i][2], "opening card " .. i .. " rank")
    end
end)

suite.test("undiscovered tag requirements stay out of seeded pools", function()
    local game = bootstrap.new_game("ALEEB123")
    game:initialize_run_loop()

    T.assert_eq(game.skips[1], 4, "Coupon Tag")
    T.assert_eq(game.skips[2], 12, "Boss Tag")

    game.Discovered.j_blueprint = true
    game.Discovered.edition_foil = true
    game:roll_skips()
    T.assert_true(game.skips[1] ~= 4 or game.skips[2] ~= 12,
        "changing the discovered pool changes the seeded selection")
end)

suite.test("the first-shop Buffoon state survives saving", function()
    local game = bootstrap.new_game("ALEEB123")
    game:initialize_run_loop()
    game:roll_shop_offers()
    game:roll_shop_boosters()
    local snapshot = game:build_run_snapshot()

    T.assert_true(snapshot.first_shop_buffoon)
    T.assert_eq(snapshot.rng_format, "reference")

    local restored = bootstrap.new_game("BBBBBBBB")
    T.assert_true(restored:load_run_snapshot(snapshot))
    T.assert_true(restored.first_shop_buffoon)
end)

return suite
