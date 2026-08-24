local T = require("tests.testlib")
local ReferenceRNG = require("reference_rng")

local suite = T.suite()

local function native_sequence(seed, count, minimum, maximum)
    math.randomseed(seed)
    local native_random = Game and Game._rng_original_random or math.random
    local values = {}
    for i = 1, count do
        if minimum ~= nil then
            values[i] = native_random(minimum, maximum)
        else
            values[i] = native_random()
        end
    end
    return values
end

suite.test("matches LuaJIT math.random for Balatro's floating seeds", function()
    for _, seed in ipairs({ 0, 0.0000000000001, 0.125, 0.4999999999999, 0.9876543210123, 1 }) do
        local expected = native_sequence(seed, 20)
        local rng = ReferenceRNG.new(seed)
        for i = 1, #expected do
            T.assert_eq(rng:random(), expected[i], "seed " .. tostring(seed) .. ", draw " .. i)
        end
    end
end)

suite.test("matches LuaJIT bounded integer sampling", function()
    for _, seed in ipairs({ 0.1234567890123, 0.75 }) do
        local expected = native_sequence(seed, 40, 3, 151)
        local rng = ReferenceRNG.new(seed)
        for i = 1, #expected do
            T.assert_eq(rng:random(3, 151), expected[i], "seed " .. tostring(seed) .. ", draw " .. i)
        end
    end
end)

return suite
