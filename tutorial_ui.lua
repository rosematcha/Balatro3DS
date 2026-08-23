--- Contextual first-run guidance using the selected Ticket Strip presentation.
--- Copy is condensed from the reference localization tutorial keys sb_1..4, fh_1..8 and
--- s_1..12 (`reference/Balatro/localization/en-us.lua:4012-4189`).

local TicketStrip = require("ticket_strip")
local TutorialUI = {}

function TutorialUI.step(game)
    if not game or not game.SETTINGS or game.SETTINGS.TUTORIAL_COMPLETE == true then return nil end
    local stage = math.max(1, math.floor(tonumber(game.SETTINGS.TUTORIAL_STAGE) or 1))
    if stage == 1 then
        return { code = "01", title = "Your goal is to earn Chips to defeat the enemy Blind.",
            detail = "Select the Small Blind to start the round!", color = game.C.BLUE }
    elseif stage == 2 then
        return { code = "02", title = "You earn Chips by playing Poker hands.",
            detail = "Tap up to 5 cards, then press Play Hand.", color = game.C.RED }
    elseif stage == 3 then
        return { code = "03", title = "Buy new cards from the Shop.",
            detail = "Jokers change the run; Vouchers passively upgrade it.", color = game.C.MONEY }
    elseif stage == 4 then
        return { code = "04", title = "The Big Blind is worth more money.",
            detail = "Select it when your deck is ready.", color = game.C.ORANGE }
    elseif stage == 5 then
        return { code = "05", title = "Build another scoring hand.",
            detail = "Use what you bought, then beat the Big Blind.", color = game.C.RED }
    end
    return nil
end

function TutorialUI.update(game)
    if not game or not game.SETTINGS or game.SETTINGS.TUTORIAL_COMPLETE == true then return end
    local stage = math.max(1, math.floor(tonumber(game.SETTINGS.TUTORIAL_STAGE) or 1))
    if stage == 1 and game.STATE == game.STATES.SELECTING_HAND then
        stage = 2
    elseif stage == 2 and game.STATE == game.STATES.SHOP then
        stage = 3
    elseif stage == 3 and game.STATE ~= game.STATES.SHOP and game._tutorial_shop_seen then
        stage = 4
    elseif stage == 4 and game.STATE == game.STATES.SELECTING_HAND
        and (tonumber(game.current_blind_index) or 1) >= 2 then
        stage = 5
        game._tutorial_second_hand_start = tonumber(game.handsPlayed) or 0
    elseif stage == 5 and (tonumber(game.handsPlayed) or 0) > (tonumber(game._tutorial_second_hand_start) or 0) then
        game.SETTINGS.TUTORIAL_COMPLETE = true
        game.SETTINGS.TUTORIAL_STAGE = nil
        game._tutorial_shop_seen = nil
        return
    end
    game.SETTINGS.TUTORIAL_STAGE = stage
    local step = TutorialUI.step(game)
    if step and game._tutorial_voice_step ~= step.code then
        game._tutorial_voice_step = step.code
        if Sfx and Sfx.play then
            Sfx.play_voice(tonumber(step.code), 1, 0.55)
        end
    end
    if stage == 3 and game.STATE == game.STATES.SHOP then
        game._tutorial_shop_seen = true
    end
end

function TutorialUI.draw_top(game)
    local step = TutorialUI.step(game)
    if not step then return false end
    TicketStrip.draw(game, { x = 18, y = 174, w = 364, h = 54, stub_w = 68,
        stub = "JIMBO " .. step.code, title = step.title, detail = step.detail,
        stub_color = step.color })
    return true
end

return TutorialUI
