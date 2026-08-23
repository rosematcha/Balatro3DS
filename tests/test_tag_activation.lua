local T = require("tests.testlib")
local bootstrap = require("tests.bootstrap")
local suite = T.suite()

local function fresh_game()
    return bootstrap.new_game(9182)
end

suite.test("tag activation retains the existing sprite briefly", function()
    local g = fresh_game()
    local atlas, quad = { image = {} }, {}
    g:begin_tag_activation({ atlas = atlas, quad = quad, X = 91, Y = 17 })
    T.assert_eq(g._tag_activation.atlas, atlas)
    T.assert_eq(g._tag_activation.quad, quad)
    T.assert_eq(g._tag_activation.x, 91)
    T.assert_eq(g._tag_activation.y, 17)
end)

suite.test("tag activation draw uses one retained textured draw", function()
    local g = fresh_game()
    g._tag_activation = {
        age = 0.2, duration = 0.48, atlas = { image = {} }, quad = {}, x = 20, y = 30,
    }
    local draws = 0
    local previous = love.graphics.draw
    love.graphics.draw = function() draws = draws + 1 end
    g:draw_tag_activation()
    love.graphics.draw = previous
    T.assert_eq(draws, 1)
end)

return suite
