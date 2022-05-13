local profiler = {}

local should_run = true
if _G.ON_EDITOR_SAVE or not jit then
    should_run = false
end

function profiler.Start()
    if not should_run then return end
    require("jit.p").start("plz -")
end

function profiler.Stop()
    if not should_run then return end
    require("jit.p").stop()
end

function profiler.PushZone(name--[[#: string]])
    if not should_run then return end
    require("jit.zone")(name)
end

function profiler.PopZone()
    if not should_run then return end
    require("jit.zone")()
end

return profiler