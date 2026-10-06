--- The boot-time loading bar.
---
--- loading.lua is the one module that draws outside `love.draw` and presents frames by
--- hand, and it runs before `G` exists. What is worth asserting is therefore not pixels
--- but the contract that makes it safe: progress only moves forward, every screen gets
--- a pass, and a present costs a GPU sync on hardware so tiny steps must not buy one.

local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")

local suite = T.suite()

local love = bootstrap.load()

--- A loading module with its own progress state. The real one is a memoised require
--- whose whole job is to run once, so each test drops it from the package cache.
---@return table
local function fresh()
    package.loaded["loading"] = nil
    love._test.frames.presents = 0
    local screens = love._test.frames.screens
    for i = #screens, 1, -1 do screens[i] = nil end
    return require("loading")
end

suite.test("each drawn step presents one frame across every screen", function()
    local Loading = fresh()

    Loading.step(0)
    T.assert_eq(love._test.frames.presents, 1)
    T.assert_deep_eq(love._test.frames.screens, { "top", "bottom" })

    Loading.step(0.5)
    T.assert_eq(love._test.frames.presents, 2)
    T.assert_deep_eq(love._test.frames.screens, { "top", "bottom", "top", "bottom" })
end)

suite.test("progress only moves forward and stops at 1", function()
    local Loading = fresh()

    Loading.step(0.5)
    T.assert_near(Loading.progress(), 0.5, 1e-9)

    Loading.step(0.2)
    T.assert_near(Loading.progress(), 0.5, 1e-9, "a backwards step must not rewind the bar")

    Loading.step(4)
    T.assert_near(Loading.progress(), 1, 1e-9, "progress is clamped to a full bar")
end)

suite.test("steps too small to see do not cost a frame", function()
    local Loading = fresh()

    Loading.step(0)
    local baseline = love._test.frames.presents

    -- Sfx.preload reports 69 times; at one present each that is 69 GPU syncs spent
    -- rendering a bar that has not visibly moved.
    for i = 1, 5 do Loading.step(i * 0.001) end
    T.assert_eq(love._test.frames.presents, baseline, "sub-threshold steps must not present")
    T.assert_near(Loading.progress(), 0.005, 1e-9, "but they still accumulate")

    Loading.step(0.02)
    T.assert_eq(love._test.frames.presents, baseline + 1, "crossing the threshold presents")
end)

suite.test("the final step always presents", function()
    local Loading = fresh()

    Loading.step(0.999)
    local baseline = love._test.frames.presents

    Loading.step(1)
    T.assert_eq(love._test.frames.presents, baseline + 1,
        "a full bar must reach the screen however small the last step was")
end)

suite.test("slice maps a sub-task onto its span of the bar", function()
    local Loading = fresh()
    local report = Loading.slice(0.6, 0.9)

    report(0, 4)
    T.assert_near(Loading.progress(), 0.6, 1e-9)

    report(2, 4)
    T.assert_near(Loading.progress(), 0.75, 1e-9)

    report(4, 4)
    T.assert_near(Loading.progress(), 0.9, 1e-9)

    -- An empty sub-task still has to leave the bar at the end of its span rather than
    -- divide by zero.
    T.assert_no_error(function() Loading.slice(0.9, 0.95)(0, 0) end)
    T.assert_near(Loading.progress(), 0.95, 1e-9)
end)

suite.test("survives a runtime with no graphics module", function()
    local Loading = fresh()
    local graphics = love.graphics

    love.graphics = nil
    T.assert_no_error(function() Loading.step(0.5) end)
    love.graphics = graphics

    T.assert_near(Loading.progress(), 0.5, 1e-9,
        "progress is tracked even when it cannot be drawn")
end)

suite.test("Sfx.preload reports progress once per cue", function()
    local Loading = fresh()
    local calls, last_done, total = 0, nil, nil

    Sfx.preload(function(done, n)
        calls = calls + 1
        last_done, total = done, n
    end)

    T.assert_true(calls > 0, "preload has cues to report")
    T.assert_eq(calls, total, "one report per cue")
    T.assert_eq(last_done, total, "the last report is the final cue")

    T.assert_no_error(function() Sfx.preload() end)
    T.assert_near(Loading.progress(), 0, 1e-9, "no callback, no bar movement")
end)

return suite
