--- Persistent unlock conditions for the sixteen tier-two vouchers.
---
--- Conditions mirror the reference catalog (`reference/Balatro/game.lua:608-624`) and
--- its `check_for_unlock` evaluators
--- (`reference/Balatro/functions/common_events.lua:1163-1620`).  Keeping them here makes
--- shop eligibility testable without constructing shop UI nodes.

local VoucherUnlocks = {}

VoucherUnlocks.CONDITIONS = {
    v_overstock_plus = { type = "career_stat", stat = "c_shop_dollars_spent", amount = 2500 },
    v_liquidation = { type = "run_redeem", amount = 10 },
    v_glow_up = { type = "have_edition", amount = 5 },
    v_reroll_glut = { type = "career_stat", stat = "c_shop_rerolls", amount = 100 },
    v_omen_globe = { type = "career_stat", stat = "c_tarot_reading_used", amount = 25 },
    v_observatory = { type = "career_stat", stat = "c_planetarium_used", amount = 25 },
    v_nacho = { type = "career_stat", stat = "c_cards_played", amount = 2500 },
    v_recyclomancy = { type = "career_stat", stat = "c_cards_discarded", amount = 2500 },
    v_tarot_tycoon = { type = "career_stat", stat = "c_tarots_bought", amount = 50 },
    v_planet_tycoon = { type = "career_stat", stat = "c_planets_bought", amount = 50 },
    v_money_tree = { type = "interest_streak", amount = 10 },
    v_antimatter = { type = "blank_redeems", amount = 10 },
    v_illusion = { type = "career_stat", stat = "c_playing_cards_bought", amount = 20 },
    v_petroglyph = { type = "ante_up", ante = 12 },
    v_retcon = { type = "blind_discoveries", amount = 25 },
    v_palette = { type = "min_hand_size", amount = 5 },
}

VoucherUnlocks.CAREER_STATS = {
    "c_shop_dollars_spent", "c_shop_rerolls", "c_tarot_reading_used",
    "c_planetarium_used", "c_cards_played", "c_cards_discarded",
    "c_tarots_bought", "c_planets_bought", "c_round_interest_cap_streak",
    "c_blank_redeems", "c_playing_cards_bought",
}

local function count_editioned_jokers(game)
    local count = 0
    for _, joker in ipairs(game.jokers or {}) do
        local edition = joker and joker.edition
        if type(edition) == "table" then edition = next(edition) end
        if edition and edition ~= "base" then count = count + 1 end
    end
    return count
end

local function count_discovered_blinds(game)
    local count = 0
    for id, discovered in pairs(game.Discovered or {}) do
        if discovered == true and type(id) == "string" and id:sub(1, 3) == "bl_" then
            count = count + 1
        end
    end
    return count
end

function VoucherUnlocks.condition_for(id)
    return type(id) == "string" and VoucherUnlocks.CONDITIONS[id] or nil
end

function VoucherUnlocks.is_met(game, id, data)
    local cond = VoucherUnlocks.condition_for(id)
    if not cond then return true end
    data = data or {}
    if cond.type == "career_stat" then
        return game:get_career_stat(cond.stat) >= cond.amount
    elseif cond.type == "run_redeem" then
        return #(game.vouchers or {}) >= cond.amount
    elseif cond.type == "have_edition" then
        return count_editioned_jokers(game) >= cond.amount
    elseif cond.type == "interest_streak" then
        return game:get_career_stat("c_round_interest_cap_streak") >= cond.amount
    elseif cond.type == "blank_redeems" then
        return game:get_career_stat("c_blank_redeems") >= cond.amount
    elseif cond.type == "ante_up" then
        return (tonumber(data.ante) or tonumber(game.ante) or 0) >= cond.ante
    elseif cond.type == "blind_discoveries" then
        return count_discovered_blinds(game) >= cond.amount
    elseif cond.type == "min_hand_size" then
        return (tonumber(data.hand_size) or game:get_effective_hand_size_limit()) <= cond.amount
    end
    return false
end

return VoucherUnlocks
