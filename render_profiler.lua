--- Small rolling renderer profiler for hardware validation.
--- LövePotion resets draw-call counters in graphics.present(), so screen callbacks
--- are accumulated until the counter drops at the start of the next frame.
local RenderProfiler = {}

local SAMPLE_COUNT = 120
local samples = {}
local pending = nil

local function number(value)
    return tonumber(value) or 0
end

local function commit(sample)
    if not sample then return end
    samples[#samples + 1] = sample
    if #samples > SAMPLE_COUNT then
        table.remove(samples, 1)
    end
end

function RenderProfiler.capture()
    if not love.graphics or not love.graphics.getStats then return end
    local ok, stats = pcall(love.graphics.getStats)
    if not ok or type(stats) ~= "table" then return end

    local calls = number(stats.drawcalls)
    if pending and calls < pending.drawcalls then
        commit(pending)
        pending = nil
    end

    if not pending then
        pending = {
            drawcalls = calls,
            submissions = number(stats.drawcallsbatched),
            cpu = number(stats.cputime),
            gpu = number(stats.gputime),
            texturememory = number(stats.texturememory),
        }
        return
    end

    pending.drawcalls = math.max(pending.drawcalls, calls)
    pending.submissions = math.max(pending.submissions, number(stats.drawcallsbatched))
    pending.cpu = math.max(pending.cpu, number(stats.cputime))
    pending.gpu = math.max(pending.gpu, number(stats.gputime))
    pending.texturememory = math.max(pending.texturememory, number(stats.texturememory))
end

local function summarize(field)
    if #samples == 0 then return 0, 0 end
    local total, peak = 0, 0
    for i = 1, #samples do
        local value = number(samples[i][field])
        total = total + value
        peak = math.max(peak, value)
    end
    return total / #samples, peak
end

function RenderProfiler.snapshot()
    local calls, calls_peak = summarize("drawcalls")
    local submissions, submissions_peak = summarize("submissions")
    local cpu, cpu_peak = summarize("cpu")
    local gpu, gpu_peak = summarize("gpu")
    local latest = samples[#samples] or pending or {}
    return {
        samples = #samples,
        drawcalls = calls,
        drawcalls_peak = calls_peak,
        submissions = submissions,
        submissions_peak = submissions_peak,
        cpu = cpu,
        cpu_peak = cpu_peak,
        gpu = gpu,
        gpu_peak = gpu_peak,
        texturememory = number(latest.texturememory),
    }
end

function RenderProfiler.reset()
    samples = {}
    pending = nil
end

function RenderProfiler.draw(game)
    local stats = RenderProfiler.snapshot()
    local font = game and game.FONTS and game.FONTS.PIXEL and game.FONTS.PIXEL.TINY
    if not font then return end

    local memory_mb = stats.texturememory / (1024 * 1024)
    local lines = {
        string.format("DRAW %.0f/%.0f  GPU %.2f/%.2fms", stats.drawcalls, stats.drawcalls_peak,
            stats.gpu, stats.gpu_peak),
        string.format("GPUCALL %.0f/%.0f  CPU %.2f/%.2fms", stats.submissions,
            stats.submissions_peak, stats.cpu, stats.cpu_peak),
        string.format("TEX %.2fMB  N %d", memory_mb, stats.samples),
    }

    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 2, 2, 238, 35, 2, 2)
    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)
    for i = 1, #lines do
        love.graphics.print(lines[i], 5, 3 + (i - 1) * 10)
    end
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

return RenderProfiler
