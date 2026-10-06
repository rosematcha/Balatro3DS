local T = require("tests.testlib")

local suite = T.suite("performance lab")

local function fresh()
    package.loaded.performance_lab = nil
    return require("performance_lab")
end

suite.test("every experiment starts disabled", function()
    local lab = fresh()
    for _, definition in ipairs(lab.definitions()) do
        T.assert_false(lab.is_enabled(definition.id), definition.id)
    end
end)

suite.test("unavailable experiments cannot be enabled", function()
    local lab = fresh()
    T.assert_false(lab.set_enabled("collection_batch", true))
    T.assert_false(lab.is_enabled("collection_batch"))
end)

suite.test("registered experiments toggle and emergency disable", function()
    local lab = fresh()
    T.assert_true(lab.register("collection_batch", { available = true }))
    T.assert_true(lab.toggle("collection_batch"))
    T.assert_true(lab.is_enabled("collection_batch"))
    lab.disable_all()
    T.assert_eq(lab.enabled_count(), 0)
end)

return suite
