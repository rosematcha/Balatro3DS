--- Test runner. Discovers tests/test_*.lua, runs each, prints a summary and exits
--- non-zero on any failure.
---
--- Run from the repo root:
---     ./tests/run.sh
---     ./tests/run.sh test_hand_eval        -- only files whose name contains this
---
--- Each test file must return a suite table (see tests/testlib.lua). A file that
--- errors at load time counts as one failure rather than aborting the run, so one
--- half-edited module does not hide every other result.

local T = require("tests.testlib")

local root = os.getenv("BALATRO_ROOT") or "."

--- List tests/test_*.lua. Shelling out to `ls` keeps this dependency-free; LuaJIT
--- has no directory API without an FFI detour.
---@return string[] module names, e.g. "tests.test_do_random"
local function discover(filter)
    local names = {}
    local p = io.popen("ls " .. root .. "/tests/test_*.lua 2>/dev/null")
    if not p then return names end
    for line in p:lines() do
        local base = line:match("([^/]+)%.lua$")
        if base and (not filter or base:find(filter, 1, true)) then
            names[#names + 1] = "tests." .. base
        end
    end
    p:close()
    table.sort(names)
    return names
end

--- Unwrap the structured error a testlib assertion raises.
---@param err any
---@return string kind "fail"|"skip"|"error"
---@return string message
local function classify(err)
    if type(err) == "table" then
        if err.__test_skip then return "skip", tostring(err.message) end
        if err.__test_failure then
            local where = err.where
            local loc = where and string.format(" [%s:%d]",
                (where.short_src or "?"):gsub("^%./", ""), where.currentline or 0) or ""
            return "fail", tostring(err.message) .. loc
        end
    end
    return "error", tostring(err)
end

local passed, failed, skipped = 0, 0, 0
local failures = {}

local files = discover(arg and arg[1])
if #files == 0 then
    io.write("no test files found (looked for " .. root .. "/tests/test_*.lua)\n")
    os.exit(1)
end

for _, modname in ipairs(files) do
    io.write("\n== " .. modname .. "\n")

    local ok, suite = pcall(require, modname)
    if not ok then
        failed = failed + 1
        local _, msg = classify(suite)
        io.write("  LOAD FAIL  " .. msg .. "\n")
        failures[#failures + 1] = { modname, "<module load>", msg }
    elseif type(suite) ~= "table" or not suite._order then
        failed = failed + 1
        local msg = "test file did not return a suite table"
        io.write("  LOAD FAIL  " .. msg .. "\n")
        failures[#failures + 1] = { modname, "<module load>", msg }
    else
        for _, name in ipairs(suite._order) do
            local run_ok, err = pcall(suite._tests[name])
            if run_ok then
                passed = passed + 1
                io.write("  pass  " .. name .. "\n")
            else
                local kind, msg = classify(err)
                if kind == "skip" then
                    skipped = skipped + 1
                    io.write("  skip  " .. name .. "  -- " .. msg .. "\n")
                else
                    failed = failed + 1
                    io.write("  FAIL  " .. name .. "\n        " .. msg:gsub("\n", "\n        ") .. "\n")
                    failures[#failures + 1] = { modname, name, msg }
                end
            end
        end
    end
end

io.write("\n" .. string.rep("-", 60) .. "\n")
if #failures > 0 then
    io.write("failures:\n")
    for _, f in ipairs(failures) do
        io.write(string.format("  %s :: %s\n      %s\n", f[1], f[2], (f[3]:gsub("\n", "\n      "))))
    end
    io.write(string.rep("-", 60) .. "\n")
end
io.write(string.format("%d passed, %d failed, %d skipped\n", passed, failed, skipped))

os.exit(failed > 0 and 1 or 0)
