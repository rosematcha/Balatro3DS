--- LuaJIT-compatible PRNG used by the shipping game.
---
--- Balatro reseeds `math.random` with every `pseudoseed` result. Desktop
--- Balatro runs on LuaJIT, whose math library uses a 64-bit combined
--- Tausworthe generator. LövePotion runs PUC Lua 5.1, where `math.random`
--- delegates to the platform C library, so using the runtime implementation
--- makes the same visible seed diverge on 3DS hardware.
---
--- This is the LuaJIT generator expressed as pairs of unsigned 32-bit words.
--- The 3DS runtime already bundles Lua BitOp (`source/main.cpp`), so it avoids
--- both 64-bit integer requirements and runtime-specific random functions.
--- LuaJIT `src/lib_math.c:96-181`, `src/lj_prng.c:16-55`.

local bitlib = bit or require("bit")
local band, bor, bxor = bitlib.band, bitlib.bor, bitlib.bxor
local lshift, rshift = bitlib.lshift, bitlib.rshift

local ReferenceRNG = {}
ReferenceRNG.__index = ReferenceRNG

local U32 = 4294967296
local U20 = 1048576
local U52 = 4503599627370496

local function u32(value)
    value = tonumber(value) or 0
    if value < 0 then return value + U32 end
    return value
end

local function xor32(a, b)
    return u32(bxor(a, b))
end

local function or32(a, b)
    return u32(bor(a, b))
end

local function and32(a, b)
    return u32(band(a, b))
end

local function shl32(value, amount)
    return u32(lshift(value, amount))
end

local function shr32(value, amount)
    return u32(rshift(value, amount))
end

local function shift_left(hi, lo, amount)
    if amount == 0 then return hi, lo end
    if amount < 32 then
        return or32(shl32(hi, amount), shr32(lo, 32 - amount)), shl32(lo, amount)
    end
    if amount < 64 then return shl32(lo, amount - 32), 0 end
    return 0, 0
end

local function shift_right(hi, lo, amount)
    if amount == 0 then return hi, lo end
    if amount < 32 then
        return shr32(hi, amount), or32(shr32(lo, amount), shl32(hi, 32 - amount))
    end
    if amount < 64 then return 0, shr32(hi, amount - 32) end
    return 0, 0
end

--- Return the IEEE-754 binary64 words for a finite positive Lua number.
--- Every seed Balatro passes to `math.randomseed` is in this domain.
local function positive_double_words(value)
    if value == 0 then return 0, 0 end
    local mantissa, exponent = math.frexp(value)
    local biased = exponent - 1 + 1023
    local fraction = (mantissa * 2 - 1) * U52
    local fraction_hi = math.floor(fraction / U32)
    local lo = fraction - fraction_hi * U32
    return biased * U20 + fraction_hi, lo
end

local function step_word(state, index, k, q, s)
    local word = state[index]
    local hi, lo = word[1], word[2]
    local left_hi, left_lo = shift_left(hi, lo, q)
    local mixed_hi, mixed_lo = xor32(left_hi, hi), xor32(left_lo, lo)
    local first_hi, first_lo = shift_right(mixed_hi, mixed_lo, k - s)

    local clear_low = 64 - k
    local masked_lo = and32(lo, shl32(0xffffffff, clear_low))
    local second_hi, second_lo = shift_left(hi, masked_lo, s)
    local next_hi, next_lo = xor32(first_hi, second_hi), xor32(first_lo, second_lo)
    word[1], word[2] = next_hi, next_lo
    return next_hi, next_lo
end

function ReferenceRNG.new(seed)
    local self = setmetatable({ state = {} }, ReferenceRNG)
    self:seed(seed or 0)
    return self
end

function ReferenceRNG:_step()
    local result_hi, result_lo = 0, 0
    local hi, lo = step_word(self.state, 1, 63, 31, 18)
    result_hi, result_lo = xor32(result_hi, hi), xor32(result_lo, lo)
    hi, lo = step_word(self.state, 2, 58, 19, 28)
    result_hi, result_lo = xor32(result_hi, hi), xor32(result_lo, lo)
    hi, lo = step_word(self.state, 3, 55, 24, 7)
    result_hi, result_lo = xor32(result_hi, hi), xor32(result_lo, lo)
    hi, lo = step_word(self.state, 4, 47, 21, 8)
    return xor32(result_hi, hi), xor32(result_lo, lo)
end

function ReferenceRNG:seed(seed)
    local value = tonumber(seed) or 0
    local shifts = { 1, 6, 9, 17 }
    for i = 1, 4 do
        value = value * math.pi + 2.7182818284590452354
        local hi, lo = positive_double_words(value)
        local minimum = 2 ^ shifts[i]
        if hi == 0 and lo < minimum then lo = lo + minimum end
        self.state[i] = { hi, lo }
    end
    for _ = 1, 10 do self:_step() end
end

function ReferenceRNG:unit()
    local hi, lo = self:_step()
    local mantissa = (hi % U20) * U32 + lo
    return mantissa / U52
end

function ReferenceRNG:random(minimum, maximum)
    local unit = self:unit()
    if minimum == nil then return unit end
    if maximum == nil then
        maximum, minimum = minimum, 1
    end
    return math.floor(unit * (maximum - minimum + 1)) + minimum
end

function ReferenceRNG:restore(state)
    if type(state) ~= "table" or #state ~= 4 then return false end
    local restored = {}
    for i = 1, 4 do
        local word = state[i]
        if type(word) ~= "table" or tonumber(word[1]) == nil or tonumber(word[2]) == nil then
            return false
        end
        restored[i] = { u32(word[1]), u32(word[2]) }
    end
    self.state = restored
    return true
end

return ReferenceRNG
