--- Collection discovery.
---
--- Seals and editions were reported as discovered unconditionally, which both hid the
--- reveal and inflated the collection percentage that feeds the deck unlock thresholds.
--- The discovery data was already being recorded — the collection just ignored it.
local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")

local suite = T.suite()

bootstrap.load()
local CollectionCatalog = require("collection_catalog")
local CollectionUI = require("collection_ui")

suite.test("the collection only lists playable decks", function()
    local decks = CollectionCatalog.build_deck_entries()
    T.assert_eq(#decks, 15, "Challenge Deck is an internal challenge-run card back")
    for _, entry in ipairs(decks) do
        T.assert_false(entry.id == "b_challenge", "internal decks do not occupy collection slots")
    end
end)

suite.test("dragging a collection card reorders its row live", function()
    local g = bootstrap.new_game(5100)
    g.STATE = g.STATES.PAUSED
    g._collection_over_run = true
    g._menu_sub_state = "collection_grid"

    local m = CollectionUI.grid_metrics(5)
    local nodes = {}
    for i = 1, 5 do
        local x, y = CollectionUI.slot_position(m, i, 5)
        nodes[i] = CollectionUI.CollectionStaticNode(x, y, 71, 95, { id = "c" .. i })
    end
    g._collection_nodes = nodes
    g._collection_page_count = 5

    local first, third = nodes[1], nodes[3]
    local x1 = CollectionUI.slot_position(m, 1, 5)
    local x3 = CollectionUI.slot_position(m, 3, 5)

    g:touchpressed(1, x1 + 5, m.start_y + 5)
    g:touchmoved(1, x3 + 5, m.start_y + 5, x3 - x1, 0)

    T.assert_eq(g._collection_nodes[3], first, "the dragged card takes the slot it is over")
    T.assert_eq(g._collection_nodes[2], third, "the cards it passed shuffle back one place")
    T.assert_eq(third.T.x, CollectionUI.slot_position(m, 2, 5),
        "the displaced card is given its new slot as a target, not snapped to it")

    g:touchreleased(1, x3 + 5, m.start_y + 5)
    T.assert_eq(first.T.x, x3, "the released card springs into the slot it opened")
    T.assert_eq(g.dragging, nil, "the drag is released normally")
end)

suite.test("a collection card dragged off its row stays in that row", function()
    local g = bootstrap.new_game(5101)
    g.STATE = g.STATES.PAUSED
    g._collection_over_run = true
    g._menu_sub_state = "collection_grid"

    local m = CollectionUI.grid_metrics(15)
    local nodes = {}
    for i = 1, 15 do
        local x, y = CollectionUI.slot_position(m, i, 15)
        nodes[i] = CollectionUI.CollectionStaticNode(x, y, 71, 95, { id = "c" .. i })
    end
    g._collection_nodes = nodes
    g._collection_page_count = 15

    -- Slot 7 is the middle of the second row. Dragging it down onto the third row must not
    -- hand it over: the reference gives each row its own CardArea.
    local node = nodes[7]
    local x7, y7 = CollectionUI.slot_position(m, 7, 15)
    local x13, y13 = CollectionUI.slot_position(m, 13, 15)
    g:touchpressed(1, x7 + 5, y7 + 5)
    g:touchmoved(1, x13 + 5, y13 + 5, x13 - x7, y13 - y7)
    g:touchreleased(1, x13 + 5, y13 + 5)

    T.assert_eq(g._collection_nodes[8], node, "it moved only within its own row")
    T.assert_eq(node.T.y, y7, "and returns to that row's line")
end)

suite.test("a seal is undiscovered until a card carrying it is seen", function()
    local g = bootstrap.new_game(5101)
    g.Discovered = {}

    local entry = { category = "seals", id = "seal_gold", discovery_id = "seal_gold" }
    T.assert_false(CollectionCatalog.is_entry_discovered(g, entry),
        "an unseen seal must not fill its slot")

    g:discover_card_properties({ rank = 5, suit = "Hearts", seal = "gold" })
    T.assert_true(CollectionCatalog.is_entry_discovered(g, entry), "seeing one reveals it")

    local unseen = { category = "seals", id = "seal_red", discovery_id = "seal_red" }
    T.assert_false(CollectionCatalog.is_entry_discovered(g, unseen), "and only that one")
end)

--- A playing card's edition hangs off `card_data.modifier`, not the top level, so reading
--- only `card_data.edition` meant a Foil card never registered at all.
suite.test("a playing card's edition is discovered from its modifier table", function()
    local g = bootstrap.new_game(5102)
    g.Discovered = {}

    local foil = { category = "editions", id = "edition_foil", discovery_id = "edition_foil" }
    T.assert_false(CollectionCatalog.is_entry_discovered(g, foil))

    g:discover_card_properties({ rank = 7, suit = "Clubs", modifier = { edition = "foil" } })
    T.assert_true(CollectionCatalog.is_entry_discovered(g, foil))
end)

--- `normalize_edition` answers "base" for an ordinary Joker; that is not an edition and
--- must not occupy a collection slot.
suite.test("an ordinary card does not discover a base edition", function()
    local g = bootstrap.new_game(5103)
    g.Discovered = {}
    g:discover_card_properties({ rank = 3, suit = "Spades" })
    T.assert_false(g:is_discovered("edition_base"), "there is no such edition to find")

    local enhanced = { category = "enhanced", id = "enhancement_gold", discovery_id = "enhancement_gold" }
    g:discover_card_properties({ rank = 3, suit = "Spades", enhancement = "gold" })
    T.assert_true(CollectionCatalog.is_entry_discovered(g, enhanced),
        "enhancements still record as they always did")
end)

--- Hex, Wheel of Fortune, Ectoplasm and Aura stamp an edition onto a Joker or card that
--- already exists, so neither `add_joker` nor `Hand:add_card` ever sees it. Polychrome is
--- the one players hit: it is the rarest shop roll, so Hex and the Wheel are usually
--- where it first turns up, and it stayed locked in the collection either way.
local function editionless_joker(game)
    game.jokers = {}
    T.assert_true(game:add_joker_by_def("j_joker"), "a plain Joker to modify")
    return game.jokers[1]
end

suite.test("Hex discovers the Polychrome it applies", function()
    local g = bootstrap.new_game(5104)
    editionless_joker(g)
    g.Discovered = {}

    g:apply_consumable_effect({ kind = "spectral", id = "spectral_hex" })

    T.assert_eq(Joker.normalize_edition(g.jokers[1].edition), "polychrome", "Hex applied")
    T.assert_true(g:is_discovered("edition_polychrome"), "and the collection heard about it")
end)

suite.test("Ectoplasm discovers the Negative it applies", function()
    local g = bootstrap.new_game(5105)
    editionless_joker(g)
    g.Discovered = {}

    g:apply_consumable_effect({ kind = "spectral", id = "spectral_ectoplasm" })

    T.assert_eq(Joker.normalize_edition(g.jokers[1].edition), "negative", "Ectoplasm applied")
    T.assert_true(g:is_discovered("edition_negative"))
end)

suite.test("Aura discovers the edition it applies to a card in hand", function()
    local g = bootstrap.new_game(5106)
    local data = { rank = 10, suit = "Hearts" }
    g.hand = {
        ordered_selected_nodes = function()
            return { { card_data = data, sync_visual_from_card_data = function() end } }
        end,
        clear_selection = function() end,
        layout = function() end,
    }
    g.Discovered = {}

    g:apply_consumable_effect({ kind = "spectral", id = "spectral_aura" })

    local applied = data.modifier and data.modifier.edition
    T.assert_not_nil(applied, "Aura applied an edition")
    T.assert_true(g:is_discovered("edition_" .. applied),
        "the card is already in hand, so nothing re-adds it later")
end)

suite.test("the Wheel discovers the edition it lands", function()
    local g = bootstrap.new_game(5108)
    local j = editionless_joker(g)
    g.Discovered = {}
    -- The Wheel is a 1-in-4; force the hit so the test is about discovery, not the roll.
    g.do_random = function() return true end

    g:apply_consumable_effect({ kind = "tarot", id = "tarot_wheel_of_fortune" })

    local applied = Joker.normalize_edition(j.edition)
    T.assert_true(applied ~= "base", "the Wheel landed an edition")
    T.assert_true(g:is_discovered("edition_" .. applied))
end)

suite.test("discover_edition ignores the absence of an edition", function()
    local g = bootstrap.new_game(5107)
    g.Discovered = {}
    g:discover_edition(nil)
    g:discover_edition("")
    g:discover_edition("base")
    T.assert_false(g:is_discovered("edition_base"), "base is not an edition")
    T.assert_eq(next(g.Discovered), nil, "and nothing else was recorded")
end)

return suite
