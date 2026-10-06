--- Minimal test library. No external dependencies on purpose: the 3DS toolchain
--- already needs a plain luajit and nothing else, and CI should not need luarocks.
---
--- A test file returns a table of { ["name"] = function() ... end }, or calls
--- T.test(name, fn) to register into the ambient suite. Failures raise, and the
--- runner catches them, so an assertion failure aborts only its own test.

local T = {}

T._current = nil

--------------------------------------------------------------------------------
-- Failure reporting
--------------------------------------------------------------------------------

--- Raise a test failure. Level 3 so the reported position is the caller of the
--- assert helper, not the helper itself.
---@param msg string
local function fail(msg)
    error({ __test_failure = true, message = msg, where = debug.getinfo(3, "Sl") }, 3)
end

--- Render a value for a failure message. Tables are shown one level deep with
--- sorted keys so diffs read consistently.
---@param v any
---@param depth integer|nil
---@return string
local function repr(v, depth)
    depth = depth or 0
    local tv = type(v)
    if tv == "string" then return string.format("%q", v) end
    if tv ~= "table" then return tostring(v) end
    if depth >= 2 then return "{...}" end

    local keys, parts = {}, {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        parts[#parts + 1] = string.format("%s=%s", tostring(k), repr(v[k], depth + 1))
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end
T.repr = repr

--------------------------------------------------------------------------------
-- Assertions
--------------------------------------------------------------------------------

---@param cond any
---@param msg string|nil
function T.assert_true(cond, msg)
    if not cond then
        fail((msg or "expected truthy") .. " (got " .. repr(cond) .. ")")
    end
end

---@param cond any
---@param msg string|nil
function T.assert_false(cond, msg)
    if cond then
        fail((msg or "expected falsy") .. " (got " .. repr(cond) .. ")")
    end
end

---@param actual any
---@param expected any
---@param msg string|nil
function T.assert_eq(actual, expected, msg)
    if actual ~= expected then
        fail(string.format("%sexpected %s, got %s",
            msg and (msg .. ": ") or "", repr(expected), repr(actual)))
    end
end

---@param actual any
---@param unexpected any
---@param msg string|nil
function T.assert_ne(actual, unexpected, msg)
    if actual == unexpected then
        fail(string.format("%sexpected value to differ from %s",
            msg and (msg .. ": ") or "", repr(unexpected)))
    end
end

---@param actual number
---@param expected number
---@param tol number|nil absolute tolerance, default 1e-9
---@param msg string|nil
function T.assert_near(actual, expected, tol, msg)
    tol = tol or 1e-9
    if type(actual) ~= "number" then
        fail(string.format("%sexpected a number near %s, got %s",
            msg and (msg .. ": ") or "", repr(expected), repr(actual)))
    end
    local d = math.abs(actual - expected)
    if d > tol then
        fail(string.format("%sexpected %s +/- %s, got %s (off by %s)",
            msg and (msg .. ": ") or "", tostring(expected), tostring(tol),
            tostring(actual), tostring(d)))
    end
end

---@param v any
---@param msg string|nil
function T.assert_nil(v, msg)
    if v ~= nil then
        fail((msg or "expected nil") .. " (got " .. repr(v) .. ")")
    end
end

---@param v any
---@param msg string|nil
function T.assert_not_nil(v, msg)
    if v == nil then
        fail(msg or "expected non-nil")
    end
end

--- Deep structural equality. Compares table contents recursively; metatables and
--- table identity are ignored, which is what a save round-trip needs.
---@param actual any
---@param expected any
---@param msg string|nil
function T.assert_deep_eq(actual, expected, msg)
    local diff = T.deep_diff(actual, expected)
    if diff then
        fail(string.format("%s%s", msg and (msg .. ": ") or "", diff))
    end
end

--- Returns nil when equal, else a human-readable path-qualified description of the
--- first difference found.
---@param a any
---@param b any
---@param path string|nil
---@return string|nil
function T.deep_diff(a, b, path)
    path = path or "<root>"
    if type(a) ~= type(b) then
        return string.format("%s: type %s ~= %s (%s vs %s)",
            path, type(a), type(b), repr(a), repr(b))
    end
    if type(a) ~= "table" then
        if a ~= b then
            return string.format("%s: %s ~= %s", path, repr(a), repr(b))
        end
        return nil
    end
    for k, v in pairs(a) do
        local sub = T.deep_diff(v, b[k], path .. "." .. tostring(k))
        if sub then return sub end
    end
    for k, v in pairs(b) do
        if a[k] == nil then
            return string.format("%s.%s: missing in actual (expected %s)",
                path, tostring(k), repr(v))
        end
    end
    return nil
end

--- Assert that `fn` raises. Returns the error value so callers can inspect it.
---@param fn function
---@param msg string|nil
---@return any err
function T.assert_error(fn, msg)
    local ok, err = pcall(fn)
    if ok then
        fail(msg or "expected the call to raise, but it returned")
    end
    return err
end

--- Assert that `fn` does not raise. Reports the error text on failure, which is
--- the whole point -- a bare pcall assertion hides the reason.
---@param fn function
---@param msg string|nil
---@return any ... whatever fn returned
function T.assert_no_error(fn, msg)
    local res = { pcall(fn) }
    if not res[1] then
        local e = res[2]
        if type(e) == "table" and e.message then e = e.message end
        fail(string.format("%sunexpected error: %s",
            msg and (msg .. ": ") or "", tostring(e)))
    end
    return unpack(res, 2)
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

--- Build a fresh suite. A test file typically does:
---     local T = require("tests.testlib")
---     local suite = T.suite()
---     suite.test("name", function() ... end)
---     return suite
---@return table
function T.suite()
    local s = { _tests = {}, _order = {} }
    --- Register a test. Duplicate names are a mistake worth catching loudly.
    ---@param name string
    ---@param fn function
    function s.test(name, fn)
        if s._tests[name] then
            error("duplicate test name: " .. name, 2)
        end
        s._tests[name] = fn
        s._order[#s._order + 1] = name
    end
    return s
end

--- Mark a test as skipped from inside its body, with a reason. The runner counts
--- these separately and does not fail the suite.
---@param reason string
function T.skip(reason)
    error({ __test_skip = true, message = reason }, 2)
end

return T
