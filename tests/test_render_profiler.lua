local T = require("tests.testlib")
local love = require("tests.bootstrap").load()

local suite = T.suite("render profiler")

suite.test("commits a frame when present resets draw counters", function()
    package.loaded.render_profiler = nil
    local profiler = require("render_profiler")
    local old_get_stats = love.graphics.getStats
    local stats = { drawcalls = 12, drawcallsbatched = 4, cputime = 2, gputime = 3, texturememory = 1024 }
    love.graphics.getStats = function() return stats end

    profiler.capture()
    stats = { drawcalls = 30, drawcallsbatched = 8, cputime = 2, gputime = 3, texturememory = 2048 }
    profiler.capture()
    stats = { drawcalls = 5, drawcallsbatched = 2, cputime = 4, gputime = 6, texturememory = 2048 }
    profiler.capture()

    local snapshot = profiler.snapshot()
    T.assert_eq(snapshot.samples, 1)
    T.assert_eq(snapshot.drawcalls, 30)
    T.assert_eq(snapshot.submissions, 8)
    T.assert_eq(snapshot.texturememory, 2048)

    love.graphics.getStats = old_get_stats
end)

return suite
