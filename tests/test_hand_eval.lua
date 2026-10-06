--- Poker hand classification: `Hand:calculate_play()`.
---
--- `calculate_play` has no return value -- it writes `G.selectedHand`, an index into
--- `G.handlist`. These tests drive it with plain node tables (it only reads
--- `node.card_data.{rank,suit,enhancement}` and `node.face_up`) rather than real Card
--- instances, which would drag in atlases, layout and popups for no added coverage.
---
--- Ranks are numbers 2..14 (11=J, 12=Q, 13=K, 14=A) and suits are the capitalised
--- strings the deck builds, per deck.lua.
---
--- Joker-conditional rules (Four Fingers, Shortcut, Smeared) go through
--- `self.game:hasJoker`, so they are exercised by putting stub jokers on the real Game
--- rather than by flipping a flag.

local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")

local suite = T.suite()

local game = bootstrap.new_game(777)

local H, C, D, S = "Hearts", "Clubs", "Diamonds", "Spades"

--------------------------------------------------------------------------------
-- Fixture plumbing
--------------------------------------------------------------------------------

--- Build a node from a compact spec: { rank, suit, enhancement }.
---@param spec table
---@return table node
local function node(spec)
    return {
        card_data = { rank = spec[1], suit = spec[2], enhancement = spec[3] },
        face_up = true,
    }
end

--- Classify a hand. Every selected node is also a hand node, in the same order, which
--- is what a real play looks like once the cards are chosen.
---@param cards table[] list of { rank, suit, enhancement } specs
---@param jokers string[]|nil joker ids to own for this evaluation
---@return string hand name from G.handlist
---@return table hand the Hand instance, for follow-up assertions
local function classify(cards, jokers)
    game.jokers = {}
    for _, id in ipairs(jokers or {}) do
        game.jokers[#game.jokers + 1] = { def = { id = id } }
    end

    local h = Hand(game)
    h.card_nodes = {}
    h.selected = {}
    for _, spec in ipairs(cards) do
        local nd = node(spec)
        h.card_nodes[#h.card_nodes + 1] = nd
        h.selected[#h.selected + 1] = nd
    end

    h:calculate_play()

    local idx = G.selectedHand
    local name = G.handlist and G.handlist[idx]
    return name or ("<no name for index " .. tostring(idx) .. ">"), h
end

--- Assert a fixture classifies as `expected`.
---@param label string
---@param cards table[]
---@param expected string
---@param jokers string[]|nil
local function check(label, cards, expected, jokers)
    local got = classify(cards, jokers)
    T.assert_eq(got, expected, label)
end

--------------------------------------------------------------------------------
-- The twelve hand types
--------------------------------------------------------------------------------

suite.test("classifies every standard five-card hand", function()
    check("high card", { { 2, H }, { 5, C }, { 7, D }, { 9, S }, { 12, H } }, "High Card")
    check("pair", { { 13, H }, { 13, C }, { 7, D }, { 9, S }, { 2, H } }, "Pair")
    check("two pair", { { 13, H }, { 13, C }, { 12, D }, { 12, S }, { 2, H } }, "Two Pair")
    check("three of a kind", { { 13, H }, { 13, C }, { 13, D }, { 9, S }, { 2, H } },
        "Three of a Kind")
    check("straight", { { 2, H }, { 3, C }, { 4, D }, { 5, S }, { 6, H } }, "Straight")
    check("flush", { { 2, H }, { 5, H }, { 7, H }, { 9, H }, { 12, H } }, "Flush")
    check("full house", { { 13, H }, { 13, C }, { 13, D }, { 12, S }, { 12, H } },
        "Full House")
    check("four of a kind", { { 13, H }, { 13, C }, { 13, D }, { 13, S }, { 2, H } },
        "Four of a Kind")
    check("straight flush", { { 9, H }, { 10, H }, { 11, H }, { 12, H }, { 13, H } },
        "Straight Flush")
end)

suite.test("classifies the Balatro-only hands", function()
    check("five of a kind", { { 14, H }, { 14, C }, { 14, D }, { 14, S }, { 14, H } },
        "Five of a Kind")
    check("flush house", { { 13, H }, { 13, H }, { 13, H }, { 12, H }, { 12, H } },
        "Flush House")
    check("flush five", { { 14, S }, { 14, S }, { 14, S }, { 14, S }, { 14, S } },
        "Flush Five")
end)

--------------------------------------------------------------------------------
-- Straight edge cases
--------------------------------------------------------------------------------

suite.test("the wheel straight A-2-3-4-5 counts as a straight", function()
    check("ace low, mixed suits", { { 14, H }, { 2, C }, { 3, D }, { 4, S }, { 5, H } },
        "Straight")
end)

suite.test("the wheel straight flush A-2-3-4-5 suited counts as a straight flush", function()
    check("ace low, one suit", { { 14, H }, { 2, H }, { 3, H }, { 4, H }, { 5, H } },
        "Straight Flush")
end)

suite.test("the broadway straight 10-J-Q-K-A counts as a straight", function()
    check("ace high", { { 10, H }, { 11, C }, { 12, D }, { 13, S }, { 14, H } }, "Straight")
end)

suite.test("cards out of order still form a straight", function()
    -- Selection order follows the hand, not rank, so classification must sort first.
    check("shuffled", { { 6, H }, { 3, C }, { 5, D }, { 2, S }, { 4, H } }, "Straight")
end)

suite.test("a wrapping run K-A-2-3-4 is not a straight", function()
    check("wrap-around", { { 13, H }, { 14, C }, { 2, D }, { 3, S }, { 4, H } }, "High Card")
end)

suite.test("a gap breaks a straight", function()
    check("2-3-4-5-7", { { 2, H }, { 3, C }, { 4, D }, { 5, S }, { 7, H } }, "High Card")
end)

suite.test("a duplicate rank breaks a straight", function()
    check("2-3-4-5-5", { { 2, H }, { 3, C }, { 4, D }, { 5, S }, { 5, H } }, "Pair")
end)

--------------------------------------------------------------------------------
-- Enhancements
--------------------------------------------------------------------------------

suite.test("a wild card completes a flush", function()
    check("four hearts plus a wild spade",
        { { 2, H }, { 5, H }, { 7, H }, { 9, H }, { 12, S, "wild" } }, "Flush")
end)

suite.test("five wild cards are a flush", function()
    check("all wild",
        { { 2, H }, { 5, C }, { 7, D }, { 9, S }, { 12, H } }, "High Card")
    check("all wild, enhanced",
        { { 2, H, "wild" }, { 5, C, "wild" }, { 7, D, "wild" },
          { 9, S, "wild" }, { 12, H, "wild" } }, "Flush")
end)

suite.test("a wild card does not invent a rank for a straight", function()
    -- Wild affects suit only. 2-3-4-5-7 stays a non-straight however it is enhanced.
    check("wild does not fill the gap",
        { { 2, H }, { 3, H }, { 4, H }, { 5, H }, { 7, H, "wild" } }, "Flush")
end)

suite.test("mixed suits without a wild are not a flush", function()
    check("four hearts and a spade",
        { { 2, H }, { 5, H }, { 7, H }, { 9, H }, { 12, S } }, "High Card")
end)

--------------------------------------------------------------------------------
-- Joker-modified evaluation
--------------------------------------------------------------------------------

suite.test("Four Fingers makes four suited cards a flush", function()
    check("four hearts, no joker",
        { { 2, H }, { 5, H }, { 7, H }, { 9, H } }, "High Card")
    check("four hearts, with Four Fingers",
        { { 2, H }, { 5, H }, { 7, H }, { 9, H } }, "Flush", { "j_four_fingers" })
end)

suite.test("Four Fingers makes four connected cards a straight", function()
    check("2-3-4-5, no joker",
        { { 2, H }, { 3, C }, { 4, D }, { 5, S } }, "High Card")
    check("2-3-4-5, with Four Fingers",
        { { 2, H }, { 3, C }, { 4, D }, { 5, S } }, "Straight", { "j_four_fingers" })
end)

suite.test("Four Fingers makes four suited connected cards a straight flush", function()
    check("2-3-4-5 hearts, with Four Fingers",
        { { 2, H }, { 3, H }, { 4, H }, { 5, H } }, "Straight Flush", { "j_four_fingers" })
end)

suite.test("Shortcut allows gaps of one in a straight", function()
    check("2-4-6-8-10, no joker",
        { { 2, H }, { 4, C }, { 6, D }, { 8, S }, { 10, H } }, "High Card")
    check("2-4-6-8-10, with Shortcut",
        { { 2, H }, { 4, C }, { 6, D }, { 8, S }, { 10, H } }, "Straight", { "j_shortcut" })
end)

suite.test("Shortcut does not allow a gap of two", function()
    check("2-5-8-11-14, with Shortcut",
        { { 2, H }, { 5, C }, { 8, D }, { 11, S }, { 14, H } }, "High Card", { "j_shortcut" })
end)

suite.test("Smeared Joker merges Hearts with Diamonds", function()
    check("hearts and diamonds, no joker",
        { { 2, H }, { 5, D }, { 7, H }, { 9, D }, { 12, H } }, "High Card")
    check("hearts and diamonds, with Smeared",
        { { 2, H }, { 5, D }, { 7, H }, { 9, D }, { 12, H } }, "Flush", { "j_smeared" })
end)

suite.test("Smeared Joker merges Spades with Clubs", function()
    check("spades and clubs, with Smeared",
        { { 2, S }, { 5, C }, { 7, S }, { 9, C }, { 12, S } }, "Flush", { "j_smeared" })
end)

suite.test("Smeared Joker does not merge red with black", function()
    check("hearts and spades, with Smeared",
        { { 2, H }, { 5, S }, { 7, H }, { 9, S }, { 12, H } }, "High Card", { "j_smeared" })
end)

--------------------------------------------------------------------------------
-- Which cards score
--------------------------------------------------------------------------------

--- Count nodes flagged as contributing chips.
---@param h table
---@return integer
local function scoring_count(h)
    local n = 0
    for _, nd in ipairs(h.card_nodes) do
        if nd.counts_for_play_score then n = n + 1 end
    end
    return n
end

suite.test("only the pair scores in a pair hand", function()
    local _, h = classify({ { 13, H }, { 13, C }, { 7, D }, { 9, S }, { 2, H } })
    T.assert_eq(scoring_count(h), 2, "a pair should score exactly its two cards")
    T.assert_true(h.card_nodes[1].counts_for_play_score, "first king scores")
    T.assert_true(h.card_nodes[2].counts_for_play_score, "second king scores")
    T.assert_false(h.card_nodes[3].counts_for_play_score, "the 7 must not score")
end)

suite.test("every card scores in a flush", function()
    local _, h = classify({ { 2, H }, { 5, H }, { 7, H }, { 9, H }, { 12, H } })
    T.assert_eq(scoring_count(h), 5, "all five cards of a flush score")
end)

suite.test("only the high card scores in a high card hand", function()
    local _, h = classify({ { 2, H }, { 5, C }, { 7, D }, { 9, S }, { 12, H } })
    T.assert_eq(scoring_count(h), 1, "a high card hand scores exactly one card")
    T.assert_true(h.card_nodes[5].counts_for_play_score, "the queen is the high card")
end)

suite.test("Splash makes every selected card score", function()
    local _, h = classify({ { 2, H }, { 5, C }, { 7, D }, { 9, S }, { 12, H } },
        { "j_splash" })
    T.assert_eq(scoring_count(h), 5, "Splash should score all five selected cards")
end)

suite.test("a stone card always scores", function()
    -- Stone cards score regardless of whether they are part of the scoring hand.
    local _, h = classify({ { 13, H }, { 13, C }, { 7, D, "stone" }, { 9, S }, { 2, H } })
    T.assert_true(h.card_nodes[3].counts_for_play_score,
        "a stone card should score even outside the pair")
end)

suite.test("stone cards cannot supply a rank or suit to a hand", function()
    -- A Stone Card has no gameplay rank or suit (reference card.lua:957-981,
    -- 4064-4080), so it cannot turn four matching cards into a made hand.
    check("pair", { { 7, H }, { nil, nil, "stone" } }, "High Card")
    check("flush", { { 2, H }, { 5, H }, { 7, H }, { 9, H }, { nil, nil, "stone" } }, "High Card")
    check("straight", { { 2, H }, { 3, C }, { 4, D }, { 5, S }, { nil, nil, "stone" } }, "High Card")
end)

suite.test("a stone card has no rank chips and contributes its flat fifty separately", function()
    local hand = Hand(game)
    local stone = setmetatable({
        enhancement = "stone",
        VT = { x = 0, y = 0, w = 10, h = 10, scale = 1 },
        collision_offset = { x = 0, y = 0 },
    }, { __index = Card })
    local chips, mult = hand:accumulate_card_score(0, 1, {
        card_data = { enhancement = "stone" },
        VT = stone.VT,
        collision_offset = stone.collision_offset,
    })
    T.assert_eq(chips, 0, "Stone Card must not add its former rank's base chips")

    local ctx = { chips = chips, mult = mult }
    stone:do_enhancement(ctx)
    T.assert_eq(ctx.chips, 50, "Stone Card contributes its flat fifty chips")
end)

suite.test("stone normalization preserves a dormant face for later enhancement changes", function()
    local data = { rank = 14, suit = "Spades", enhancement = "stone" }
    Card.normalize_gameplay_data(data)
    T.assert_nil(data.rank, "a stone card has no gameplay rank")
    T.assert_nil(data.suit, "a stone card has no gameplay suit")
    T.assert_eq(data._stone_rank, 14)
    T.assert_eq(data._stone_suit, "Spades")

    Card.restore_gameplay_data(data)
    T.assert_eq(data.rank, 14)
    T.assert_eq(data.suit, "Spades")
end)

--------------------------------------------------------------------------------
-- Fewer than five cards, and the empty selection
--------------------------------------------------------------------------------

suite.test("short selections still classify", function()
    check("single card", { { 9, H } }, "High Card")
    check("two of a kind", { { 9, H }, { 9, C } }, "Pair")
    check("three of a kind, three cards", { { 9, H }, { 9, C }, { 9, D } },
        "Three of a Kind")
    check("two pair, four cards", { { 9, H }, { 9, C }, { 4, D }, { 4, S } }, "Two Pair")
end)

suite.test("an empty selection reports no hand", function()
    local h = Hand(game)
    h.card_nodes = {}
    h.selected = {}
    h:calculate_play()
    T.assert_eq(G.selectedHand, -1, "no selection should set selectedHand to -1")
    T.assert_eq(G.selectedHandChips, 0, "no selection should zero the chips")
    T.assert_eq(G.selectedHandMult, 0, "no selection should zero the mult")
end)

--------------------------------------------------------------------------------
-- Base chips and mult
--------------------------------------------------------------------------------

suite.test("classification sets the base chips and mult for the hand", function()
    classify({ { 13, H }, { 13, C }, { 7, D }, { 9, S }, { 2, H } })
    local idx = G.selectedHand
    local stats = G.hand_stats and G.hand_stats[idx]
    T.assert_not_nil(stats, "a classified hand must have stats")
    T.assert_true((tonumber(G.selectedHandChips) or 0) > 0,
        "a pair should carry non-zero base chips")
    T.assert_true((tonumber(G.selectedHandMult) or 0) > 0,
        "a pair should carry non-zero base mult")
end)

suite.test("a better hand carries more base chips than a worse one", function()
    classify({ { 2, H }, { 5, C }, { 7, D }, { 9, S }, { 12, H } })
    local high_card_chips = tonumber(G.selectedHandChips) or 0
    classify({ { 9, H }, { 10, H }, { 11, H }, { 12, H }, { 13, H } })
    local straight_flush_chips = tonumber(G.selectedHandChips) or 0
    T.assert_true(straight_flush_chips > high_card_chips,
        string.format("straight flush (%d chips) should beat high card (%d chips)",
            straight_flush_chips, high_card_chips))
end)

--------------------------------------------------------------------------------
-- Face-down cards
--------------------------------------------------------------------------------

suite.test("a face-down selected card marks the hand hidden", function()
    local h = Hand(game)
    game.jokers = {}
    h.card_nodes, h.selected = {}, {}
    for i, spec in ipairs({ { 13, H }, { 13, C }, { 7, D }, { 9, S }, { 2, H } }) do
        local nd = node(spec)
        if i == 3 then nd.face_up = false end
        h.card_nodes[i] = nd
        h.selected[i] = nd
    end
    h:calculate_play()
    T.assert_true(G.selectedHandHidden,
        "a face-down card in the selection should hide the hand readout")
end)

return suite
