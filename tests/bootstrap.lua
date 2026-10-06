--- Loads the game headlessly: installs the love stub, then requires the game modules
--- in main.lua's order.
---
--- The game is written against globals (`Object`, `Card`, `Hand`, `Game`, `G`, `Sfx`),
--- not module returns, so the order below matters and mirrors main.lua exactly. If
--- main.lua gains a require, add it here.
---
--- Loading is memoised: `bootstrap.load()` is cheap to call from every test file.

local bootstrap = {}

local loaded = false

--- Modules in main.lua's order. UI modules are included because game.lua requires
--- several of them at its own top level anyway, and loading them proves the stub is
--- complete enough for the real entry point.
local MODULES = {
    "engine.object",
    "engine.node",
    "engine.moveable",
    "engine.sprite",
    "card",
    "deck",
    "hand",
    "joker",
    "joker_catalog",
    "joker_unlocks",
    "shop_nodes",
    "consumable",
    "game",
    "globals",
    "consumable_catalog",
    "voucher_catalog",
    "topUI",
    "popup",
    "tag",
    "deck_catalog",
    "challenge_catalog",
}

--- Install the love stub and require every game module.
---@return table love the installed stub
function bootstrap.load()
    if loaded then return _G.love end

    local stub = require("tests.love_stub")
    local love = stub.install()

    -- main.lua wraps print so that non-debug runs stay quiet. Do the same, otherwise
    -- module-level diagnostics drown the test output.
    if not _G.__test_print_wrapped then
        local raw_print = print
        _G.__raw_print = raw_print
        _G.print = function(...)
            if _G.G and _G.G.DEBUG then raw_print(...) end
        end
        _G.__test_print_wrapped = true
    end

    for _, name in ipairs(MODULES) do
        require(name)
    end

    _G.Sfx = require("sfx")
    _G.Fx = require("fx")

    loaded = true
    return love
end

--- A Game instance with `Game:init` run, installed as the global `G` (much of the
--- codebase reads `G` rather than taking a receiver).
---
--- `Game:init` is heavy but it is the only way to get a coherent state, and it is
--- what every code path under test assumes has happened.
---@param seed number|nil
---@return table game
function bootstrap.new_game(seed)
    bootstrap.load()
    local g = Game()
    g:init(seed or 12345)
    return g
end

return bootstrap
