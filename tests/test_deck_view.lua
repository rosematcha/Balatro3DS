--- Deck Info: the full deck, the Remaining/Full tabs, the tallies and the 13x4 matrix.
---
--- The view used to build from the draw pile alone, so a card you had just enhanced vanished
--- from it, and the header strip toggled between suit counts and rank counts because there
--- was no room for both. The reference lists the whole deck and greys what is no longer
--- drawable (`UI_definitions.lua:3260-3266`), and shows suits against ranks as one table
--- rather than two strips of totals (`deck_preview`, `:469-620`).
local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")

local suite = T.suite()

bootstrap.load()
local DeckViewUI = require("deck_view_ui")

local function game_with_deck()
    local g = bootstrap.new_game(8101)
    g.deck = Deck(g)
    g.deck.cards = {
        { rank = 2, suit = "Hearts" },
        { rank = 5, suit = "Hearts" },
        { rank = 14, suit = "Spades" },
    }
    g.deck.discard_pile = {
        { rank = 11, suit = "Clubs" },
    }
    g.hand = Hand(g)
    g.hand.cards = { { rank = 7, suit = "Diamonds" } }
    return g
end

suite.test("the view lists every card in the run, not just the draw pile", function()
    local g = game_with_deck()
    local entries = DeckViewUI.collect_run_cards(g)
    T.assert_eq(#entries, 5, "3 drawable + 1 discarded + 1 in hand")

    local drawable = 0
    for _, e in ipairs(entries) do if e.in_draw then drawable = drawable + 1 end end
    T.assert_eq(drawable, 3, "only the draw pile counts as drawable")
end)

suite.test("Remaining greys spent cards; Full Deck greys nothing", function()
    local g = game_with_deck()
    DeckViewUI.build(g)
    T.assert_eq(#g._deck_view_nodes, 5, "a node per card in the run")

    T.assert_eq(DeckViewUI.mode(g), "remaining", "Remaining is the default")
    DeckViewUI.draw_bottom(g)
    local greyed = 0
    for _, n in ipairs(g._deck_view_nodes) do if n.greyed then greyed = greyed + 1 end end
    T.assert_eq(greyed, 2, "the discarded card and the one in hand are greyed")

    DeckViewUI.set_mode(g, 2)
    T.assert_eq(DeckViewUI.mode(g), "full")
    DeckViewUI.draw_bottom(g)
    for _, n in ipairs(g._deck_view_nodes) do
        T.assert_eq(n.greyed, nil, "Full Deck greys nothing")
    end

    DeckViewUI.destroy(g)
end)

--- The rows used to size themselves to the number of non-empty suits, so playing your last
--- Club reflowed and resized every other card on screen.
suite.test("all four suit rows are laid out even when a suit is empty", function()
    local g = game_with_deck()
    DeckViewUI.build(g)

    local m = DeckViewUI._chrome_metrics()
    local ys = {}
    for i, suit in ipairs({ "Spades", "Hearts", "Clubs", "Diamonds" }) do
        local row = g._deck_view_rows[suit]
        T.assert_not_nil(row, suit .. " has a row")
        if row[1] then ys[i] = row[1].T.y end
    end
    T.assert_eq(ys[1], m.rows_y + math.floor((m.row_h - m.card_h) * 0.5 + 0.5), "Spades on row 1")
    T.assert_eq(ys[2] - ys[1], m.row_step, "Hearts sits one step below Spades")
    -- Clubs is on row 3 whether or not the Jack is still drawable.
    T.assert_eq(ys[3] - ys[1], m.row_step * 2, "Clubs keeps row 3")
    T.assert_eq(ys[4] - ys[1], m.row_step * 3, "Diamonds keeps row 4")

    DeckViewUI.destroy(g)
end)

suite.test("tallies count suits, faces, aces and numbered cards", function()
    local g = game_with_deck()

    -- Remaining: the draw pile only.
    DeckViewUI.refresh_readout(g)
    local t = DeckViewUI.readout(g).tallies
    T.assert_eq(t.suits.Hearts, 2)
    T.assert_eq(t.suits.Spades, 1)
    T.assert_eq(t.suits.Clubs, 0, "the discarded Jack is not drawable")
    T.assert_eq(t.ace, 1)
    T.assert_eq(t.numbered, 2)
    T.assert_eq(t.face, 0)

    -- Full Deck: everything.
    DeckViewUI.set_mode(g, 2)
    t = DeckViewUI.readout(g).tallies
    T.assert_eq(t.suits.Clubs, 1, "the discarded Jack counts here")
    T.assert_eq(t.suits.Diamonds, 1, "so does the card in hand")
    T.assert_eq(t.face, 1)
    T.assert_eq(t.total, 5)
end)

--- Stone cards have no rank or suit, so the reference leaves them out of every tally
--- (`UI_definitions.lua:3363`).
suite.test("stone cards are excluded from the tallies", function()
    local t = DeckViewUI.count_tallies({
        { rank = 5, suit = "Hearts" },
        { rank = 9, suit = "Hearts", enhancement = "stone" },
    })
    T.assert_eq(t.suits.Hearts, 1)
    T.assert_eq(t.total, 1)
end)

--- The whole point of the table over two strips of totals: only the intersection tells you
--- *which* flush or *which* pair is still live.
suite.test("the matrix counts every suit against every rank", function()
    local grid, stones = DeckViewUI.count_suit_ranks({
        { rank = 2, suit = "Hearts" },
        { rank = 5, suit = "Hearts" },
        { rank = 5, suit = "Hearts" },
        { rank = 14, suit = "Spades" },
        { rank = 9, suit = "Clubs", enhancement = "stone" },
    })
    T.assert_eq(grid.Hearts[5], 2, "a duplicated rank stacks in its cell")
    T.assert_eq(grid.Hearts[2], 1)
    T.assert_eq(grid.Spades[14], 1)
    T.assert_eq(grid.Clubs[9], 0, "a stone card has no rank or suit")
    T.assert_eq(stones, 1, "and is counted apart")

    -- Every cell is present, so the drawing loop never indexes nil.
    for _, suit in ipairs({ "Spades", "Hearts", "Clubs", "Diamonds" }) do
        for rank = 2, 14 do
            T.assert_true(type(grid[suit][rank]) == "number", suit .. " " .. rank)
        end
    end
end)

suite.test("the matrix header runs Ace first, like the reference", function()
    local d = DeckViewUI.RANKS_DESC
    T.assert_eq(#d, 13)
    T.assert_eq(d[1], 14, "Ace leads")
    T.assert_eq(d[13], 2, "and the deuce closes")
end)

suite.test("the tabs pick a mode outright rather than cycling", function()
    local g = game_with_deck()
    DeckViewUI.build(g)
    DeckViewUI.draw_bottom(g)

    local rects = g._deck_view_tab_rects
    T.assert_eq(#rects, 2, "Remaining and Full Deck")
    T.assert_eq(DeckViewUI.mode(g), "remaining")

    local full = rects[2]
    T.assert_true(DeckViewUI.handle_header_touch(g, full.x + full.w * 0.5, full.y + full.h * 0.5))
    T.assert_eq(DeckViewUI.mode(g), "full")

    -- Tapping the tab that is already chosen is a no-op, not a toggle back.
    T.assert_true(DeckViewUI.handle_header_touch(g, full.x + full.w * 0.5, full.y + full.h * 0.5))
    T.assert_eq(DeckViewUI.mode(g), "full")

    local remaining = rects[1]
    T.assert_true(DeckViewUI.handle_header_touch(g,
        remaining.x + remaining.w * 0.5, remaining.y + remaining.h * 0.5))
    T.assert_eq(DeckViewUI.mode(g), "remaining")

    DeckViewUI.destroy(g)
end)

suite.test("the shoulders switch tabs and the Close button closes", function()
    local g = game_with_deck()
    g.STATE = g.STATES.SELECTING_HAND
    T.assert_true(g:enter_deck_view())
    DeckViewUI.draw_bottom(g)

    T.assert_true(DeckViewUI.handle_gamepad(g, "rightshoulder"))
    T.assert_eq(DeckViewUI.mode(g), "full")
    T.assert_true(DeckViewUI.handle_gamepad(g, "leftshoulder"))
    T.assert_eq(DeckViewUI.mode(g), "remaining")

    local c = g._deck_view_close_rect
    T.assert_not_nil(c, "the Close button has a rect")
    T.assert_true(DeckViewUI.handle_header_touch(g, c.x + c.w * 0.5, c.y + c.h * 0.5))
    T.assert_false(g._deck_view_open)
end)

--- Three passes over every card in the run, every frame, for numbers that cannot move while
--- a modal is over the deck. Per-frame allocation is what this port can least afford.
suite.test("the top screen's readout is derived once, not once per draw", function()
    local g = game_with_deck()
    DeckViewUI.build(g)

    local r = g._deck_view_readout
    T.assert_not_nil(r, "building the view derives it")
    T.assert_eq(r.drawable, 3)
    T.assert_eq(r.owned, 5)
    T.assert_eq(r.tallies.suits.Hearts, 2)
    T.assert_eq(r.grid.Spades[14], 1)

    local calls = 0
    local real = DeckViewUI.collect_run_cards
    DeckViewUI.collect_run_cards = function(...) calls = calls + 1 return real(...) end
    DeckViewUI.draw_top("top", g)
    DeckViewUI.draw_top("top", g)
    DeckViewUI.collect_run_cards = real
    T.assert_eq(calls, 0, "drawing reads the cache rather than rebuilding it")

    -- Flipping the tab changes what the readout describes, so it has to rebuild.
    DeckViewUI.set_mode(g, 2)
    T.assert_eq(g._deck_view_readout.tallies.suits.Clubs, 1, "Full Deck counts the discarded Jack")
    T.assert_eq(g._deck_view_readout.drawable, 3, "the drawable count is a fact, not a mode")

    DeckViewUI.destroy(g)
    T.assert_eq(g._deck_view_readout, nil, "and it does not outlive the view")
end)

return suite
