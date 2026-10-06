--- Round-win progression: ordinary blind cash-outs must not use the run-victory cue.
local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")

local suite = T.suite()

local function with_recorded_cues(fn)
    local original = Sfx.play
    local cues = {}
    Sfx.play = function(cue)
        cues[#cues + 1] = cue
        return true
    end
    local ok, err = pcall(fn, cues)
    Sfx.play = original
    if not ok then error(err, 0) end
end

local function cue_count(cues, wanted)
    local count = 0
    for _, cue in ipairs(cues) do
        if cue == wanted then count = count + 1 end
    end
    return count
end

suite.test("cash-out after an ordinary blind does not play the victory cue", function()
    local g = bootstrap.new_game()
    g._last_completed_blind_was_boss = false
    g.ante = 1
    g._round_win_display_lines = nil
    g.enter_shop_after_blind = function(self) self._entered_shop = true end

    with_recorded_cues(function(cues)
        g:continue_from_round_win()
        T.assert_true(g._entered_shop)
        T.assert_eq(cue_count(cues, "win"), 0)
    end)
end)

suite.test("Ante 8 enters victory before cash-out and plays the victory cue", function()
    local g = bootstrap.new_game()
    g._last_completed_blind_was_boss = true
    -- The ante steps when the Boss falls, so the winning run reaches cash-out on 9.
    g.ante = 9
    g._endless_mode = false
    g._round_win_display_lines = { { "Blind reward", 5, "pending" } }
    g.ensure_victory_progress_recorded = function() end
    g.STATE = g.STATES.SELECTING_HAND

    with_recorded_cues(function(cues)
        g._blind_defeat = { t = 1, hold = 0, next_ping = 1, pings = {} }
        g:_update_blind_defeat(0)
        T.assert_eq(g.STATE, g.STATES.YOU_WIN)
        T.assert_eq(cue_count(cues, "win"), 1)
        T.assert_eq(g.money, 0, "winning rewards remain pending before Endless")
    end)
end)

suite.test("Endless resumes at the deferred Ante 8 cash-out", function()
    local g = bootstrap.new_game()
    g._last_completed_blind_was_boss = true
    g.ante = 9
    g._round_win_display_lines = { { "Blind reward", 5, "pending" } }
    g.ensure_victory_progress_recorded = function() end
    g:continue_from_you_win_endless()
    T.assert_eq(g.STATE, g.STATES.ROUND_EVAL)
    T.assert_not_nil(g._round_eval_slide)
    T.assert_eq(g.money, 0, "cash-out is not credited before confirmation")
    g:continue_from_round_win()
    T.assert_eq(g.money, 5)
end)

suite.test("cash-out rewards do not increase that round's interest", function()
    local g = bootstrap.new_game()
    g.money = 25
    g.hands = 1
    g.discards = 2
    g.extra_hand_bonus = 2
    g.extra_discard_bonus = 1
    g.current_blind_index = 1
    g.current_blind_reward = 3
    g.current_blind_target = 100
    -- The round-end batch is dispatched through `begin_joker_emit` so
    -- each triggering joker gets a beat; returning false means nothing needed staggering.
    g.begin_joker_emit = function(_, event, ctx)
        if event == "on_round_end" then ctx.add_round_win_payout("Test Joker", 5) end
        return false
    end
    g.emit_hand_cards_event = function() end
    g.set_state = function(self, state) self.STATE = state end

    g:enter_round_win_after_blind()

    local rows = g._round_win_display_lines
    T.assert_eq(rows[1][1], "Blind reward")
    T.assert_eq(rows[2][1], "Remaining Hands ($2 each)")
    T.assert_eq(rows[3][1], "Remaining Discards ($1 each)")
    T.assert_eq(rows[4][1], "Test Joker")
    T.assert_eq(rows[5][1], "1 interest per $5 (5 max)")
    T.assert_eq(rows[5][2], 5, "interest must use the pre-cash-out balance")
    T.assert_eq(g.money, 25, "cash-out rows must not credit money while they reveal")

    g:flush_round_win_pending_payouts()
    T.assert_eq(g.money, 42, "Cash Out should credit every listed reward exactly once")
end)

suite.test("the Cash Out panel waits for a staggered round-end joker batch", function()
    local g = bootstrap.new_game()
    g.money = 25
    g.hands = 1
    g.discards = 2
    g.current_blind_index = 1
    g.current_blind_reward = 3
    g.current_blind_target = 100
    g.emit_hand_cards_event = function() end
    g.set_state = function(self, state) self.STATE = state end

    local busy = true
    local ctx_seen
    g.begin_joker_emit = function(_, event, ctx)
        if event ~= "on_round_end" then return false end
        ctx_seen = ctx
        return true
    end
    g.joker_emit_busy = function() return busy end

    g:enter_round_win_after_blind()
    T.assert_eq(g._round_win_display_lines, nil,
        "no rows are built while the joker batch is still announcing itself")

    -- The joker pops mid-batch, then the queue drains.
    ctx_seen.add_round_win_payout("Late Joker", 7)
    busy = false
    g:update(0.016)

    local rows = g._round_win_display_lines
    T.assert_true(rows ~= nil, "the panel is built once the batch drains")
    local labels = {}
    for _, row in ipairs(rows) do labels[row[1]] = true end
    T.assert_true(labels["Late Joker"], "a joker that paid mid-batch still gets its row")
end)

local function fake_card_node(rank, suit)
    return {
        T = { x = 10, y = 10, r = 0, scale = 1 },
        VT = { x = 10, y = 10, r = 0, scale = 1 },
        card_data = { rank = rank, suit = suit },
    }
end

suite.test("beating a blind un-deals the hand to the deck instead of popping it", function()
    local g = bootstrap.new_game(1310)
    g.deck = g.deck or Deck(g)
    g.hand = g.hand or Hand(g)
    local removed = {}
    g.remove = function(_, node) removed[#removed + 1] = node end

    local nodes = { fake_card_node(2, "Hearts"), fake_card_node(3, "Clubs"), fake_card_node(4, "Spades") }
    g.hand.card_nodes = nodes
    g.hand.cards = {}
    for i, node in ipairs(nodes) do g.hand.cards[i] = node.card_data end

    -- A card still flying to the discard pile when the blind resolves must finish its throw.
    local in_flight = { node = fake_card_node(5, "Diamonds"), fly_after = 0, flew = true }
    g.pending_discard = { in_flight }

    local draw_pile_before = #g.deck.cards

    g:recycle_full_deck_after_blind_win()

    T.assert_eq(#g.hand.card_nodes, 0, "the hand releases its nodes")
    T.assert_eq(#g.deck.cards, draw_pile_before + 3, "the hand's cards recycle into the draw pile")
    T.assert_eq(#removed, 0, "no node is popped out synchronously")
    T.assert_eq(#g.pending_discard, 4, "three un-deal flights queue behind the in-flight discard")
    T.assert_eq(g.pending_discard[1], in_flight, "the in-flight discard survives the recycle")

    local prev_fly_after
    for i = 2, 4 do
        local entry = g.pending_discard[i]
        T.assert_true(entry.target ~= nil, "un-deal flights carry the deck origin as a target")
        -- The deck is bottom right and level with the hand, as it is in the reference
        -- (`common_events.lua:22-24`), so the hand un-deals back out the way it came.
        T.assert_true(entry.target.x >= 320, "the deck origin sits off the right edge")
        T.assert_true(entry.target.y > 90 and entry.target.y < 160,
            "at the hand's own height, not above the screen")
        if prev_fly_after then
            T.assert_near(entry.fly_after - prev_fly_after, 0.07, 1e-9,
                "un-deal flights leave on the reference's 0.07 s hand sweep beat")
            T.assert_true(entry.percent < g.pending_discard[i - 1].percent,
                "the pitch ladder runs downward across the sweep")
        end
        prev_fly_after = entry.fly_after
    end
end)

suite.test("an un-deal flight flies to the deck origin and is removed on arrival", function()
    local g = bootstrap.new_game(1311)
    g.deck = g.deck or Deck(g)
    g.hand = g.hand or Hand(g)
    local removed = {}
    g.remove = function(_, node) removed[#removed + 1] = node end

    local node = fake_card_node(11, "Hearts")
    g.hand.card_nodes = { node }
    g.hand.cards = { node.card_data }
    g.pending_discard = {}

    g:recycle_full_deck_after_blind_win()
    g:update(0.1, 0.1)

    T.assert_true(node.T.x >= 320, "the flight target is the deck's off-screen origin")
    -- The discard pile is also off to the right but well above the hand, so height is what
    -- separates an un-deal from a discard.
    T.assert_true(node.T.y > 90 and node.T.y < 160,
        "the flight leaves level with the hand, not up at the discard pile")
    T.assert_eq(#removed, 0, "the node stays alive while its spring is in flight")

    node.VT.x, node.VT.y = node.T.x, node.T.y
    g:update(0.1, 0.1)
    T.assert_eq(#removed, 1, "the node is removed once it reaches the deck")
    T.assert_eq(#g.pending_discard, 0, "the flight leaves the queue")
end)

--- `state_events.lua:248`: the Boss falling is what raises the ante, inside `end_round`
--- before ROUND_EVAL. Leaving the shop must not raise it a second time.
suite.test("the ante rises when the boss falls, not when the shop is left", function()
    local g = bootstrap.new_game()
    g.ante = 3
    g.current_blind_index = 3
    g.current_blind_target = 100
    g.emit_joker_event = function() end
    g.emit_hand_cards_event = function() end
    g.set_state = function(self, state) self.STATE = state end

    g:enter_round_win_after_blind()
    T.assert_eq(g.ante, 4, "the boss defeat steps the ante")

    g._last_completed_blind_was_boss = true
    g.enter_blind_select = function() end
    g:advance_after_shop()
    T.assert_eq(g.ante, 4, "leaving the shop does not step it again")
end)

suite.test("an ordinary blind win leaves the ante alone", function()
    local g = bootstrap.new_game()
    g.ante = 3
    g.current_blind_index = 1
    g.current_blind_target = 100
    g.emit_joker_event = function() end
    g.emit_hand_cards_event = function() end
    g.set_state = function(self, state) self.STATE = state end

    g:enter_round_win_after_blind()
    T.assert_eq(g.ante, 3)
end)

return suite
