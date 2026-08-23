local Milestones = {}
local HOLD, SLIDE = 2.2, 0.22

local function is_safe(game)
    if not game or game.screenwipe then return false end
    if game.hand and (game.hand.is_scoring or game.hand.scoring) then return false end
    if game.joker_emit_busy and game:joker_emit_busy() then return false end
    return true
end

function Milestones.push(game, kind, title, detail)
    if not game or not title then return false end
    game._milestone_queue = game._milestone_queue or {}
    local key = tostring(kind or "milestone") .. ":" .. tostring(title) .. ":" .. tostring(detail or "")
    game._milestone_seen = game._milestone_seen or {}
    if game._milestone_seen[key] then return false end
    game._milestone_seen[key] = true
    game._milestone_queue[#game._milestone_queue + 1] = {
        kind = kind or "milestone", title = tostring(title), detail = tostring(detail or ""), key = key,
    }
    return true
end

function Milestones.update(game, dt)
    if not game then return end
    local active = game._milestone_active
    if not active then
        if not is_safe(game) or not game._milestone_queue or #game._milestone_queue == 0 then return end
        active = table.remove(game._milestone_queue, 1)
        active.age = 0
        game._milestone_active = active
        if Sfx and Sfx.play then
            Sfx.play("highlight1", 1, 0.45)
            Sfx.play("foil2", 1.1, 0.28)
        end
    end
    active.age = active.age + (tonumber(dt) or 0)
    if active.age >= HOLD then game._milestone_active = nil end
end

function Milestones.draw(game)
    local a = game and game._milestone_active
    if not a then return end
    local C = game.C
    local reduced = game.SETTINGS and game.SETTINGS.REDUCED_MOTION == true
    local edge = math.min(a.age / SLIDE, (HOLD - a.age) / SLIDE, 1)
    local y = reduced and 5 or (-31 + 36 * math.max(0, edge))
    love.graphics.push()
    love.graphics.setColor(C.BLACK or C.BLOCK.BACK)
    love.graphics.rectangle("fill", 88, y + 2, 224, 30)
    love.graphics.setColor(C.ORANGE)
    love.graphics.rectangle("fill", 88, y, 224, 28)
    love.graphics.setColor(C.BLACK or C.BLOCK.BACK)
    love.graphics.rectangle("fill", 92, y + 4, 216, 20)
    love.graphics.setFont(game.FONTS.PIXEL.SMALL)
    love.graphics.setColor(C.WHITE)
    love.graphics.printf(a.title, 98, y + 5, 204, "center")
    if a.detail ~= "" then
        love.graphics.setFont(game.FONTS.PIXEL.MICRO or game.FONTS.PIXEL.SMALL)
        love.graphics.setColor(C.DARK_WHITE or C.WHITE)
        love.graphics.printf(a.detail, 98, y + 14, 204, "center")
    end
    love.graphics.pop()
end

return Milestones
