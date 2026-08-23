local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")
local VoucherUnlocks = require("voucher_unlocks")

local suite = T.suite()

local function fresh(seed)
    local game = bootstrap.new_game(seed)
    game.voucher_unlocks = {}
    game.career_stats = game:build_career_stats()
    game.seeded = false
    game.challenge_id = nil
    return game
end

suite.test("all tier-two vouchers have persistent unlock conditions", function()
    bootstrap.load()
    local tier_two = 0
    for id, def in pairs(VOUCHER_DEFS) do
        if def.tier == 2 then
            tier_two = tier_two + 1
            T.assert_not_nil(VoucherUnlocks.condition_for(id), id .. " has no unlock condition")
            T.assert_true(type(def.unlock) == "string" and def.unlock ~= "", id .. " has no unlock text")
        end
    end
    T.assert_eq(tier_two, 16)
end)

suite.test("career thresholds unlock permanently", function()
    local game = fresh(7101)
    game:add_career_stat("c_shop_rerolls", 99)
    T.assert_eq(#game:check_voucher_unlocks(), 0)
    T.assert_false(game:is_voucher_unlocked("v_reroll_glut"))
    game:add_career_stat("c_shop_rerolls", 1)
    local earned = game:check_voucher_unlocks()
    T.assert_eq(earned[1], "v_reroll_glut")
    T.assert_true(game:is_voucher_unlocked("v_reroll_glut"))
    game.career_stats.c_shop_rerolls = 0
    T.assert_true(game:is_voucher_unlocked("v_reroll_glut"), "earned unlocks do not regress")
end)

suite.test("tier two shop candidates need profile unlock and run dependency", function()
    local game = fresh(7102)
    game.vouchers = { "v_reroll" }
    local function contains(list, wanted)
        for _, id in ipairs(list) do if id == wanted then return true end end
        return false
    end
    T.assert_false(contains(game:_shop_voucher_candidate_ids(), "v_reroll_glut"))
    game.voucher_unlocks.v_reroll_glut = true
    T.assert_true(contains(game:_shop_voucher_candidate_ids(), "v_reroll_glut"))
    game.vouchers = {}
    T.assert_false(contains(game:_shop_voucher_candidate_ids(), "v_reroll_glut"))
end)

suite.test("run-state voucher conditions match the reference", function()
    local game = fresh(7103)
    game.vouchers = {}
    for i = 1, 10 do game.vouchers[i] = "v_test_" .. i end
    game.ante = 12
    game.hand_size_delta_spectral = -3
    local earned = game:check_voucher_unlocks({ ante = 12, hand_size = 5 })
    local found = {}
    for _, id in ipairs(earned) do found[id] = true end
    T.assert_true(found.v_liquidation)
    T.assert_true(found.v_petroglyph)
    T.assert_true(found.v_palette)
end)

suite.test("seeded and challenge runs cannot earn voucher unlocks", function()
    local game = fresh(7104)
    game:add_career_stat("c_cards_played", 3000)
    game.seeded = true
    T.assert_eq(#game:check_voucher_unlocks(), 0)
    game.seeded = false
    game.challenge_id = "c_omelette_1"
    T.assert_eq(#game:check_voucher_unlocks(), 0)
    T.assert_false(game:is_voucher_unlocked("v_nacho"))
end)

return suite
