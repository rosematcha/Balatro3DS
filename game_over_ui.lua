--- Bottom-screen Game Over summary when the blind is lost.

local GameOverUI = {}
local DynaText = require("dyna_text")
local NumberFormat = require("number_format")
local TicketStrip = require("ticket_strip")
local LOSS_QUIPS = {
    "Maybe Go Fish is more our speed...", "We folded like a cheap suit!",
    "Time for us to shuffle off and try again!", "The house always wins!",
    "Looks like the joke's on us!", "What a flop!",
}

function GameOverUI.quip(game)
    local index = ((math.floor(tonumber(game.round) or 0) + math.floor(tonumber(game.ante) or 0))
        % #LOSS_QUIPS) + 1
    return LOSS_QUIPS[index]
end
local SUMMARY_VALUES = {}

local GAME_OVER_TITLE_TEXT = DynaText.new({
    float_amount = 1,
    rotation_amount = 0.025,
})

--- Fill a caller-owned run-summary table. Reference game-over UI exposes these same
--- rows (`reference/Balatro/functions/UI_definitions.lua:2877-2893`) without requiring
--- any additional run tracking here.
function GameOverUI.populate_summary(game, out)
    out = out or {}
    out.best_hand_score = math.max(0, math.floor(tonumber(game.run_best_hand_score) or 0))
    if game.get_most_played_hand_name then
        out.most_played_hand = game:get_most_played_hand_name()
    else
        out.most_played_hand = "None"
    end
    out.cards_played = math.max(0, math.floor(tonumber(game.run_cards_played) or 0))
    out.cards_discarded = math.max(0, math.floor(tonumber(game.run_cards_discarded) or 0))
    out.defeated_by = game._game_over_blind_label
        or (game.get_blind_display_name and game:get_blind_display_name(game.current_blind_index or 1))
        or game.current_blind_name
        or "Blind"
    -- The reference's game-over readout carries the same rows as the victory one, including
    -- the shop counters and the seed (`UI_definitions.lua:2877-2893`, `:3013`). The port
    -- already tracked all three and showed them only on the win screen.
    out.cards_purchased = math.max(0, math.floor(tonumber(game.run_cards_purchased) or 0))
    out.times_rerolled = math.max(0, math.floor(tonumber(game.run_times_rerolled) or 0))
    out.new_discoveries = game.get_run_discoveries and game:get_run_discoveries() or 0
    out.seed = game.SEED and tostring(game.SEED) or "Unknown"
    return out
end

--- The 400x240 top display is a text readout, leaving the bottom screen free for
--- the Continue touch target.
--- Start the title's letter-by-letter reveal. Called once, when the run dies; the
--- reference's game-over title is a `pop_in = 0.4` DynaText (`game.lua:3582-3625`).
function GameOverUI.begin_title_pop()
    DynaText.pop_in(GAME_OVER_TITLE_TEXT)
end

function GameOverUI.draw_top(game)
    local summary = GameOverUI.populate_summary(game, SUMMARY_VALUES)
    local panel_x, panel_y, panel_w, panel_h = 8, 7, 384, 226
    if _G.draw_rect_with_shadow then
        draw_rect_with_shadow(panel_x, panel_y, panel_w, panel_h, 5, 2, game.C.BLOCK.BACK, game.C.BLOCK.SHADOW, 2)
    else
        love.graphics.setColor(game.C.PANEL)
        love.graphics.rectangle("fill", panel_x, panel_y, panel_w, panel_h, 5, 5)
    end

    local new_count = #(game._newly_unlocked_jokers or {}) + #(game._newly_unlocked_vouchers or {})
    TicketStrip.draw(game, {
        x = panel_x + 8, y = panel_y + 8, w = panel_w - 16, h = 36, stub_w = 72,
        stub = "ENDED", title = "Game Over",
        detail = GameOverUI.quip(game)
            .. (new_count > 0 and string.format("  %d new unlock%s", new_count, new_count == 1 and "" or "s") or ""),
        stub_color = game.C.MULT or game.C.ORANGE,
    })

    local y = panel_y + 47
    local function row(label, value, colour)
        TicketStrip.draw(game, {
            x = panel_x + 12, y = y, w = panel_w - 24, h = 20, stub_w = 112,
            stub = label, title = tostring(value), stub_color = colour or game.C.GREY,
        })
        y = y + 19
    end

    row("Best Hand", NumberFormat.format(summary.best_hand_score)
        .. (game._run_record_flags and game._run_record_flags.c_best_hand_chips and "  NEW" or ""), game.C.RED)
    row("Most Played Hand", summary.most_played_hand, game.C.WHITE)
    row("Cards Played", summary.cards_played, game.C.BLUE)
    row("Cards Discarded", summary.cards_discarded, game.C.RED)
    row("Cards Purchased", summary.cards_purchased, game.C.MONEY)
    row("Times Rerolled", summary.times_rerolled, game.C.GREEN)
    row("New Discoveries", summary.new_discoveries, game.C.ORANGE)
    row("Defeated By", summary.defeated_by, game.C.ORANGE)
    row("Seed", summary.seed, game.C.WHITE)
end

function GameOverUI.draw_bottom(game)
    -- Entrance slide, shared with the other scene panels; the reference's game-over
    -- overlay also arrives animated rather than replacing the screen in one frame
    -- (`reference/Balatro/game.lua:3582-3625`).
    love.graphics.push()
    if game.get_game_over_slide_dy then
        love.graphics.translate(0, game:get_game_over_slide_dy())
    end
    local blind_label = game._game_over_blind_label or "Blind"
    local final_score = tonumber(game._game_over_score) or tonumber(game.round_score) or 0
    local target = tonumber(game._game_over_target) or tonumber(game.current_blind_target) or 0
    local ante = tonumber(game._game_over_ante) or tonumber(game.ante) or 1
    local round_n = tonumber(game._game_over_round) or tonumber(game.round) or 1

    local panel_x, panel_y, panel_w = 8, 8, 304
    local panel_h = 132

    if _G.draw_rect_with_shadow then
        draw_rect_with_shadow(panel_x, panel_y, panel_w, panel_h, 4, 2, game.C.BLOCK.BACK, game.C.BLOCK.SHADOW, 2)
    else
        love.graphics.setColor(game.C.PANEL)
        love.graphics.rectangle("fill", panel_x, panel_y, panel_w, panel_h, 4, 4)
    end

    love.graphics.setColor(game.C.MULT or game.C.ORANGE)
    love.graphics.setFont(game.FONTS.PIXEL.MEDIUM)
    love.graphics.print("Game Over", panel_x + 8, panel_y + 6)

    love.graphics.setColor(game.C.WHITE)
    love.graphics.setFont(game.FONTS.PIXEL.SMALL)
    love.graphics.print(blind_label, panel_x + 8, panel_y + 30)

    love.graphics.setColor(game.C.GREY)
    love.graphics.print("Score " .. NumberFormat.format(math.floor(final_score))
        .. " / " .. NumberFormat.format(math.floor(target)), panel_x + 8, panel_y + 44)
    love.graphics.print(string.format("Ante %d  ·  Round %d", ante, round_n), panel_x + 8, panel_y + 58)

    love.graphics.setColor(game.C.WHITE)
    love.graphics.printf("You ran out of hands before beating this blind.", panel_x + 8, panel_y + 78, panel_w - 16, "left")

    game._game_over_continue_rect = { x = panel_x + panel_w - 84, y = panel_y + panel_h - 26, w = 74, h = 18 }
    TicketStrip.draw(game, {
        x = game._game_over_continue_rect.x, y = game._game_over_continue_rect.y,
        w = game._game_over_continue_rect.w, h = game._game_over_continue_rect.h,
        stub_w = 24, stub = "A", title = "Continue", stub_color = game.C.ORANGE,
    })
    love.graphics.pop()
end

function GameOverUI.handle_touch(game, x, y)
    if not game._game_over_continue_rect then return false end
    if game:_point_in_rect_simple(x, y, game._game_over_continue_rect) then
        Sfx.play_button()
        if game.continue_from_game_over then
            game:continue_from_game_over()
        end
        return true
    end
    return false
end

return GameOverUI
