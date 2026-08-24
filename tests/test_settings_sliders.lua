--- The settings sliders: touch drag, D-pad hold ramp, and the deferred settings write.
---
--- These are feel behaviours, so the assertions are about what the gesture produces rather
--- than about any one helper: a drag that starts on the knob must not teleport the value, a
--- held direction must cross the range without a hundred presses, and neither may touch the
--- SD card until the gesture is over (a settings write is 36 ms on hardware).
local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")

local suite = T.suite()

--- Open the audio tab and run one draw pass, which is what lays the slider rects out.
local function audio_tab(opts)
    local g = bootstrap.new_game()
    if opts and opts.from_menu then
        g.STATE = g.STATES.MENU
        g._settings_over_menu = true
    else
        g.STATE = g.STATES.PAUSED
    end
    g._pause_show_settings = true
    g._pause_settings_tab = "audio"
    g:draw_bottom_pause()
    return g
end

--- Count settings writes without letting one reach the filesystem stub.
local function with_counted_saves(g, fn)
    local saves = 0
    local original = g.save_settings
    g.save_settings = function(self)
        saves = saves + 1
    end
    local ok, err = pcall(fn, function() return saves end)
    g.save_settings = original
    if not ok then error(err, 0) end
end

local function silence_cues(fn)
    local original = Sfx.play
    Sfx.play = function() return true end
    local ok, err = pcall(fn)
    Sfx.play = original
    if not ok then error(err, 0) end
end

--- x of the knob for a value, in screen coordinates.
local function knob_x(r, value)
    return r.track_x + (value / 100) * r.track_w
end

suite.test("every slider gets a hit band tall and wide enough for a thumb", function()
    local g = audio_tab()
    local seen = 0
    for _, kind in ipairs({ "master_volume", "music_volume", "sfx_volume", "screenshake" }) do
        local r = g._pause_slider_rects[kind]
        T.assert_not_nil(r, kind .. " has no rect")
        -- The band covers the label as well as the track. 24 px was the old track-only band
        -- and it was the reason most presses landed on nothing.
        T.assert_true(r.h >= 30, kind .. " band is only " .. tostring(r.h) .. " px tall")
        -- Both ends of the track have to be reachable, knob included.
        T.assert_true(r.x <= r.track_x - r.grab_r, kind .. " cannot be grabbed at 0")
        T.assert_true(r.x + r.w >= r.track_x + r.track_w + r.grab_r, kind .. " cannot be grabbed at 100")
        seen = seen + 1
    end
    T.assert_eq(seen, 4)
end)

suite.test("slider rows do not overlap and stay inside the panel", function()
    local g = audio_tab()
    local rows = {}
    for _, kind in ipairs({ "master_volume", "music_volume", "sfx_volume", "screenshake" }) do
        rows[#rows + 1] = g._pause_slider_rects[kind]
    end
    table.sort(rows, function(a, b) return a.y < b.y end)
    for i = 2, #rows do
        T.assert_true(rows[i].y >= rows[i - 1].y + rows[i - 1].h,
            "slider row " .. i .. " overlaps the one above it")
    end
    -- The Back button sits under the last row rather than on top of it.
    T.assert_true(g._pause_back_rect.y >= rows[#rows].y + rows[#rows].h,
        "Back overlaps the last slider")
    T.assert_true(g._pause_back_rect.y + g._pause_back_rect.h <= 236, "Back runs off the panel")
end)

suite.test("a press on the bare track jumps the knob to the finger", function()
    local g = audio_tab()
    silence_cues(function()
        g:set_master_volume(100)
        local r = g._pause_slider_rects.master_volume
        T.assert_true(g:begin_pause_slider_drag(r.track_x + r.track_w * 0.5, r.track_y))
        T.assert_eq(g._pause_slider_drag, "master_volume")
        T.assert_eq(g:get_master_volume(), 50)
    end)
end)

suite.test("a press on the knob keeps the value put and drags from there", function()
    local g = audio_tab()
    silence_cues(function()
        g:set_music_volume(60)
        local r = g._pause_slider_rects.music_volume
        -- Grabbing a few pixels off-centre is what a finger actually does. The value must not
        -- snap to wherever the contact point happened to land.
        local grab = knob_x(r, 60) - 5
        T.assert_true(g:begin_pause_slider_drag(grab, r.track_y))
        T.assert_eq(g:get_music_volume(), 60)
        -- Moving 20% of the track right moves the value 20, not to the absolute finger x.
        g:update_pause_slider_drag(grab + r.track_w * 0.2)
        T.assert_eq(g:get_music_volume(), 80)
    end)
end)

suite.test("a drag keeps tracking after the finger slides off the row", function()
    local g = audio_tab()
    silence_cues(function()
        local r = g._pause_slider_rects.sfx_volume
        g:begin_pause_slider_drag(r.track_x, r.track_y)
        T.assert_eq(g:get_sfx_volume(), 0)
        -- 200 px below the track and well past its right end: on a 240 px screen a thumb
        -- leaves the row constantly, and dropping the gesture there is the whole complaint.
        T.assert_true(g:update_pause_slider_drag(r.track_x + r.track_w + 80))
        T.assert_eq(g:get_sfx_volume(), 100)
    end)
end)

suite.test("the ends of the track snap to 0 and 100", function()
    local g = audio_tab()
    silence_cues(function()
        local r = g._pause_slider_rects.master_volume
        g:begin_pause_slider_drag(knob_x(r, 50), r.track_y)
        -- Two pixels shy of each end still reads as the end, because 98 is never what anyone
        -- was aiming for.
        g:update_pause_slider_drag(r.track_x + r.track_w - 2)
        T.assert_eq(g:get_master_volume(), 100)
        g:update_pause_slider_drag(r.track_x + 2)
        T.assert_eq(g:get_master_volume(), 0)
    end)
end)

suite.test("touch values are quantised against touchscreen jitter", function()
    local g = audio_tab()
    silence_cues(function()
        local r = g._pause_slider_rects.master_volume
        g:begin_pause_slider_drag(knob_x(r, 50), r.track_y)
        local mid = knob_x(r, 50)
        local settled = g:get_master_volume()
        -- A resting finger on a resistive panel wanders about a pixel. It must not walk the
        -- number.
        for _, jitter in ipairs({ -1, 1, -1, 0, 1 }) do
            g:update_pause_slider_drag(mid + jitter)
            T.assert_eq(g:get_master_volume(), settled, "jitter of " .. jitter .. " moved the value")
        end
    end)
end)

suite.test("a touch drag defers its settings write until the gesture settles", function()
    local g = audio_tab()
    silence_cues(function()
        with_counted_saves(g, function(saves)
            local r = g._pause_slider_rects.music_volume
            g:begin_pause_slider_drag(r.track_x, r.track_y)
            for i = 1, 20 do
                g:update_pause_slider_drag(r.track_x + r.track_w * (i / 20))
            end
            T.assert_eq(saves(), 0, "an in-flight drag wrote to the SD card")
            g:finish_pause_slider_drag()
            -- Lifting off only arms the write; re-grabbing before it lands cancels it.
            g:update_pause_slider_hold(0.1)
            T.assert_eq(saves(), 0)
            g:update_pause_slider_hold(0.5)
            T.assert_eq(saves(), 1, "the write never landed")
            g:update_pause_slider_hold(0.5)
            T.assert_eq(saves(), 1, "the write repeated")
        end)
    end)
end)

suite.test("closing the panel flushes a pending write immediately", function()
    local g = audio_tab()
    silence_cues(function()
        with_counted_saves(g, function(saves)
            local r = g._pause_slider_rects.sfx_volume
            g:begin_pause_slider_drag(r.track_x + r.track_w * 0.4, r.track_y)
            g:finish_pause_slider_drag()
            T.assert_eq(saves(), 0)
            g:end_pause_slider_drag()
            T.assert_eq(saves(), 1)
            T.assert_nil(g._pause_slider_drag)
        end)
    end)
end)

suite.test("the sliders drag from the main menu, not only from a paused run", function()
    local g = audio_tab({ from_menu = true })
    silence_cues(function()
        local r = g._pause_slider_rects.master_volume
        g:touchpressed(1, r.track_x, r.track_y)
        T.assert_eq(g._pause_slider_drag, "master_volume")
        g:touchmoved(1, knob_x(r, 70), r.track_y, 0, 0)
        T.assert_eq(g:get_master_volume(), 70)
        g:touchreleased(1, knob_x(r, 70), r.track_y)
        T.assert_nil(g._pause_slider_drag)
    end)
end)

suite.test("touching a slider moves gamepad focus onto it", function()
    local g = audio_tab()
    silence_cues(function()
        local r = g._pause_slider_rects.screenshake
        g:begin_pause_slider_drag(r.track_x + r.track_w * 0.5, r.track_y)
        T.assert_eq(g:focused_pause_slider_kind(), "screenshake")
    end)
end)

suite.test("a D-pad tap moves one unit, as the reference's does", function()
    local g = audio_tab()
    silence_cues(function()
        g:set_master_volume(50)
        g:focus_pause_target("master_volume")
        g:adjust_pause_focus_slider(1)
        T.assert_eq(g:get_master_volume(), 51)
        g:adjust_pause_focus_slider(-1)
        g:adjust_pause_focus_slider(-1)
        T.assert_eq(g:get_master_volume(), 49)
    end)
end)

suite.test("holding a direction ramps across the range in about a second", function()
    local g = audio_tab()
    local original = love.keyboard.isDown
    love.keyboard.isDown = function(key) return key == "right" end
    silence_cues(function()
        -- Outside the counter: this one is a deliberate immediate write, not the ramp's.
        g:set_master_volume(0)
        g:focus_pause_target("master_volume")
        with_counted_saves(g, function(saves)
            g:adjust_pause_focus_slider(1)
            local elapsed = 0
            -- 60 fps, which is what the console runs at.
            for _ = 1, 90 do
                g:update_pause_slider_hold(1 / 60)
                elapsed = elapsed + 1 / 60
                if g:get_master_volume() >= 100 then break end
            end
            T.assert_eq(g:get_master_volume(), 100, "a held direction never reached the end")
            T.assert_true(elapsed < 1.5, "the ramp took " .. tostring(elapsed) .. "s to cross")
            -- Nothing under the ramp is allowed to write; the flush waits for the release.
            T.assert_eq(saves(), 0, "the ramp wrote to the SD card mid-hold")
        end)
    end)
    love.keyboard.isDown = original
end)

suite.test("a hold does nothing before its delay, so a tap stays a tap", function()
    local g = audio_tab()
    local original = love.keyboard.isDown
    love.keyboard.isDown = function(key) return key == "right" end
    silence_cues(function()
        g:set_music_volume(50)
        g:focus_pause_target("music_volume")
        g:adjust_pause_focus_slider(1)
        T.assert_eq(g:get_music_volume(), 51)
        for _ = 1, 12 do g:update_pause_slider_hold(1 / 60) end -- 0.2 s, under the delay
        T.assert_eq(g:get_music_volume(), 51, "the ramp started before its delay")
    end)
    love.keyboard.isDown = original
end)

suite.test("moving focus off a slider stops its ramp", function()
    local g = audio_tab()
    local original = love.keyboard.isDown
    love.keyboard.isDown = function(key) return key == "right" end
    silence_cues(function()
        g:set_master_volume(50)
        g:focus_pause_target("master_volume")
        g:adjust_pause_focus_slider(1)
        g:pause_gamepad_move(1)
        local moved_to = g:get_master_volume()
        for _ = 1, 60 do g:update_pause_slider_hold(1 / 60) end
        T.assert_eq(g:get_master_volume(), moved_to, "the ramp followed focus off the row")
    end)
    love.keyboard.isDown = original
end)

suite.test("a drag suppresses the D-pad ramp", function()
    local g = audio_tab()
    local original = love.keyboard.isDown
    love.keyboard.isDown = function(key) return key == "right" end
    silence_cues(function()
        local r = g._pause_slider_rects.master_volume
        g:focus_pause_target("master_volume")
        g:adjust_pause_focus_slider(1)
        g:begin_pause_slider_drag(knob_x(r, 20), r.track_y)
        for _ = 1, 60 do g:update_pause_slider_hold(1 / 60) end
        T.assert_eq(g:get_master_volume(), 20, "the ramp fought the finger")
    end)
    love.keyboard.isDown = original
end)

suite.test("the value tick fires on detents, not on every step", function()
    local g = audio_tab()
    local original = Sfx.play
    local ticks = 0
    Sfx.play = function() ticks = ticks + 1 return true end
    local r = g._pause_slider_rects.master_volume
    g:set_master_volume(0)
    g:begin_pause_slider_drag(knob_x(r, 0), r.track_y)
    -- A sweep across the whole track in 50 samples: 100 units of travel, so a cue per step
    -- would be 50 of them.
    for i = 1, 50 do
        g:update_pause_slider_drag(r.track_x + r.track_w * (i / 50))
    end
    Sfx.play = original
    T.assert_true(ticks > 0, "a full sweep was silent")
    T.assert_true(ticks <= 12, "a full sweep fired " .. tostring(ticks) .. " cues")
end)

suite.test("out-of-band presses do not start a drag", function()
    local g = audio_tab()
    silence_cues(function()
        local r = g._pause_slider_rects.master_volume
        T.assert_false(g:begin_pause_slider_drag(r.x - 4, r.track_y))
        T.assert_nil(g._pause_slider_drag)
        T.assert_false(g:begin_pause_slider_drag(r.track_x, g._pause_back_rect.y + 4))
        T.assert_nil(g._pause_slider_drag)
    end)
end)

return suite
