--- Boot-time loading bar.
---
--- Before this existed the console sat on a black screen for the whole of startup.
--- The gap is real work: main.lua's requires parse roughly a megabyte of Lua off
--- RomFS, `Sfx.preload` decodes 69 Vorbis cues, and `Game()` builds every prototype
--- table. None of it happens inside a frame, so nothing is on screen.
---
--- The reference game covers the same gap the same way -- it draws a bar straight to
--- the backbuffer between load steps and calls `love.graphics.present()` by hand
--- (`functions/misc_functions.lua:105`). This is that, adapted to two screens.
---
--- Two constraints shape the module:
---
---   * It may not touch `G`, or require anything that does. The first checkpoint
---     fires before game.lua has been required.
---   * Drawing outside `love.draw` is legal on LovePotion: the CTR renderer opens a
---     frame lazily on the first `BindFramebuffer` and `Present` is a no-op when no
---     frame is open (`platform/ctr/source/utilities/driver/renderer/renderer_ext.cpp:102`).

local M = {}

--- The reference palette: a pale blue fill inside a white outline on black
--- (`functions/misc_functions.lua:116-120`).
local FILL_R, FILL_G, FILL_B = 0.6, 0.8, 0.9

--- The reference bar is 300x30 in a 1280x720 window. A 3DS screen is 240 tall, so
--- these keep roughly that share of the screen at the smaller size.
local BAR_W, BAR_H = 180, 14
local BAR_RADIUS = 3
local LINE_W = 2

--- Every checkpoint presents a frame, and on hardware a frame costs a GPU sync. A
--- per-cue callback would spend more time presenting than loading, so a step that
--- moves the bar less than this is recorded and not drawn.
local MIN_DELTA = 0.01

local progress = 0
local drawn = -1

---@param w integer screen width
---@param h integer screen height
---@param p number fill fraction, 0..1
local function draw_bar(w, h, p)
    local x = math.floor(w * 0.5 - BAR_W * 0.5)
    local y = math.floor(h * 0.5 - BAR_H * 0.5)

    love.graphics.setColor(FILL_R, FILL_G, FILL_B, 1)
    if p > 0 then
        love.graphics.rectangle("fill", x, y, BAR_W * p, BAR_H, BAR_RADIUS)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(LINE_W)
    love.graphics.rectangle("line", x, y, BAR_W, BAR_H, BAR_RADIUS)
end

--- Advance the bar and put it on screen.
---
--- Safe to call before `G` exists, before the graphics module is ready, and under the
--- headless test stub. Progress only ever moves forward.
---@param p number fill fraction, 0..1
function M.step(p)
    if type(p) == "number" and p > progress then
        progress = p < 1 and p or 1
    end
    if drawn >= 0 and progress - drawn < MIN_DELTA and progress < 1 then return end

    if not (love and love.graphics and love.graphics.rectangle) then return end
    if love.graphics.isActive and not love.graphics.isActive() then return end

    -- On console each screen is drawn in its own pass, exactly as love.run does it
    -- (`source/modules/love/scripts/callbacks.lua:269`). Under nest there is one real
    -- window and the emulated screens are canvases nothing is compositing yet, so the
    -- bar goes straight to the window instead.
    local screens = love.graphics.getScreens and love.graphics.getScreens()
    if screens then
        for i = 1, #screens do
            love.graphics.origin()
            love.graphics.setActiveScreen(screens[i])
            love.graphics.clear(0, 0, 0, 1)
            draw_bar(love.graphics.getWidth(screens[i]), love.graphics.getHeight(screens[i]), progress)
        end
    else
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 1)
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        if love.window and love.window.getMode then w, h = love.window.getMode() end
        draw_bar(w, h, progress)
    end

    love.graphics.present()
    drawn = progress
end

--- Build a `Loading.step` that maps a 0..1 sub-task onto a slice of the whole bar.
--- Used for the long loops that report their own progress.
---@param from number bar fraction the sub-task starts at
---@param to number bar fraction the sub-task ends at
---@return fun(done: integer, total: integer)
function M.slice(from, to)
    return function(done, total)
        M.step(from + (to - from) * (total > 0 and done / total or 1))
    end
end

--- Current fill fraction. Exists for tests.
---@return number
function M.progress()
    return progress
end

return M
