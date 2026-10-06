--- Session-only controls for on-device rendering experiments.
--- Experiments default off and never persist: restarting always restores baseline.
local PerformanceLab = {}

local definitions = {
    { id = "profiler", label = "Profiler overlay", available = true },
    { id = "collection_batch", label = "Collection batch", available = false },
}

local by_id = {}
local enabled = {}
for _, definition in ipairs(definitions) do
    by_id[definition.id] = definition
    enabled[definition.id] = false
end

--- `options.on_change(enabled)` fires whenever the flag actually flips, so an experiment that has
--- to rebuild state (rather than just being read at a draw site) does not need the toggle UI to
--- know about it. It is not called on register: an experiment starts off, and off is baseline.
function PerformanceLab.register(id, options)
    local definition = by_id[id]
    if not definition then return false end
    options = options or {}
    definition.available = options.available ~= false
    definition.requires_restart = options.requires_restart == true
    if type(options.label) == "string" then definition.label = options.label end
    if options.on_change ~= nil then definition.on_change = options.on_change end
    return true
end

function PerformanceLab.definitions()
    return definitions
end

function PerformanceLab.available_definitions()
    local result = {}
    for _, definition in ipairs(definitions) do
        if definition.available then result[#result + 1] = definition end
    end
    return result
end

function PerformanceLab.is_available(id)
    local definition = by_id[id]
    return definition and definition.available == true or false
end

function PerformanceLab.is_enabled(id)
    return PerformanceLab.is_available(id) and enabled[id] == true
end

function PerformanceLab.set_enabled(id, value)
    if not PerformanceLab.is_available(id) then return false end
    value = value == true
    if enabled[id] == value then return true end
    enabled[id] = value
    local on_change = by_id[id].on_change
    if on_change then on_change(value) end
    return true
end

function PerformanceLab.toggle(id)
    return PerformanceLab.set_enabled(id, not PerformanceLab.is_enabled(id))
end

--- Panic button: everything back to baseline. Routed through `set_enabled` so experiments that
--- own state hear about it - otherwise "All Off" would clear the flag and leave the state applied.
function PerformanceLab.disable_all()
    for _, definition in ipairs(definitions) do
        PerformanceLab.set_enabled(definition.id, false)
    end
end

function PerformanceLab.enabled_count()
    local count = 0
    for id, value in pairs(enabled) do
        if value and PerformanceLab.is_available(id) then count = count + 1 end
    end
    return count
end

return PerformanceLab
