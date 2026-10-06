--- Shop rendering must stay allocation-light and use source atlas geometry on 3DS.

local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")
local ShopUI = require("shop_ui")

local suite = T.suite()

local function padded_image()
    return {
        getDimensions = function() return 1024, 512 end,
    }
end

suite.test("voucher and booster cells use declared source columns", function()
    bootstrap.load()
    local voucher = { image = padded_image(), px = 72, py = 95, cols = 10 }
    local booster = { image = padded_image(), px = 72, py = 95, cols = 10 }

    local crystal = ShopUI.cached_atlas_quad(voucher, VOUCHER_DEFS.v_crystal_ball.pos, "_test")
    local x, y = crystal:getViewport()
    T.assert_eq(x, 648, "Crystal Ball column")
    T.assert_eq(y, 95, "Crystal Ball row")

    local pack = ShopUI.cached_atlas_quad(booster, 19, "_test")
    x, y = pack:getViewport()
    T.assert_eq(x, 648, "booster column")
    T.assert_eq(y, 95, "booster row")
end)

suite.test("shop atlas quads are reused", function()
    bootstrap.load()
    local atlas = { image = padded_image(), px = 72, py = 95, cols = 10 }
    local first = ShopUI.cached_atlas_quad(atlas, 19, "_test")
    local second = ShopUI.cached_atlas_quad(atlas, 19, "_test")
    T.assert_true(first == second)
end)

suite.test("booster shop art does not build animated meshes", function()
    local love = bootstrap.load()
    local game = bootstrap.new_game(55)
    game.ASSET_ATLAS.Booster.image = padded_image()
    game.ASSET_ATLAS.Booster.cols = 10
    local before = #love.graphics._meshes

    T.assert_true(ShopUI.draw_booster_atlas_frame(game, { x = 0, y = 0, w = 72, h = 95 }, 19))
    T.assert_eq(#love.graphics._meshes, before)
end)

suite.test("editioned shop offers build meshes only on capable consoles", function()
    local love = bootstrap.load()
    local game = bootstrap.new_game(55)
    local Fx = require("fx")
    local def
    for _, candidate in pairs(JOKER_DEFS) do
        if candidate and candidate.id then
            def = candidate
            break
        end
    end
    local joker = Joker(0, 0, 70, 94, def, { face_up = true, edition = "foil" })
    joker.shop_offer_slot = 1
    local card = Card(0, 0, 72, 95, {
        rank = 2,
        suit = "Hearts",
        modifier = { edition = "polychrome" },
    }, nil, { face_up = true })
    card.shop_offer_slot = 2

    -- Old 3DS: flat tint, no transient meshes on the shop shelf.
    local real_probe = Fx.shop_editions_animated
    Fx.shop_editions_animated = function() return false end
    local before = #love.graphics._meshes
    joker:draw()
    T.assert_eq(#love.graphics._meshes, before, "joker shop offer stays flat on Old 3DS")
    before = #love.graphics._meshes
    card:draw()
    T.assert_eq(#love.graphics._meshes, before, "playing-card shop offer stays flat on Old 3DS")
    Fx.shop_editions_animated = real_probe

    -- New 3DS / desktop (this harness): the shop animates like the play areas.
    T.assert_true(Fx.shop_editions_animated(), "non-3DS hosts qualify for animated shop editions")
    before = #love.graphics._meshes
    joker:draw()
    T.assert_true(#love.graphics._meshes > before, "joker shop offer animates on capable consoles")

    game:remove(joker)
    game:remove(card)
end)

suite.test("interactivity updates do not rebuild shop nodes", function()
    local game = bootstrap.new_game(55)
    game.STATE = game.STATES.SHOP
    game._shop_slide = nil
    game._shop_pops_active = nil
    local booster_syncs, voucher_syncs = 0, 0
    game.sync_shop_booster_nodes = function() booster_syncs = booster_syncs + 1 end
    game.sync_shop_voucher_nodes = function() voucher_syncs = voucher_syncs + 1 end

    game:sync_shop_offer_interactivity()
    T.assert_eq(booster_syncs, 0)
    T.assert_eq(voucher_syncs, 0)
end)

suite.test("stable shop layouts stay cached", function()
    local game = bootstrap.new_game(55)
    game._shop_layout_dirty = true
    T.assert_true(ShopUI.shop_layout_needs_refresh(game))
    game._shop_layout_dirty = nil
    T.assert_false(ShopUI.shop_layout_needs_refresh(game))
    game.shop_offer_nodes = { { _shop_settling = true } }
    T.assert_true(ShopUI.shop_layout_needs_refresh(game))
end)

suite.test("finishing a shop pop requests one final layout", function()
    local game = bootstrap.new_game(55)
    game.STATE = game.STATES.SHOP
    game._shop_slide = nil
    game._shop_layout_dirty = nil
    game.shop_offer_nodes = { { _shop_pop_t = 0.99 } }
    game.shop_booster_nodes = {}
    game.shop_voucher_nodes = {}
    game._shop_pops_active = true

    game:_update_scene_transitions(1 / 30)
    T.assert_false(game:shop_pop_in_active())
    T.assert_true(game._shop_layout_dirty)
end)

return suite
