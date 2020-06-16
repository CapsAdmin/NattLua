local T = require("spec.lua.helpers")
local run = T.RunCode

local check = function(analyzer, to)
    assert.equal(to:gsub("%s+", " "), tostring(analyzer:GetValue("a", "runtime")):gsub("%s+", " "))
end

it("{[number]: any}", function()
    check(run[[local a: {[number] = any} = {[1] = 1}]], "{ number ⊃ number(1) = any ⊃ number(1) }")
    run([[local a: {[number] = any} = {foo = 1}]], [[is not the same type as number]])
end)

it("{[1 .. inf]: any}", function()
    check(run[[local a: {[1 .. inf] = any} = {[1234] = 1}]], "{ 1..inf ⊃ 1234 = any ⊃ number(1) }")

    run([[local a: {[1 .. inf] = any} = {[-1234] = 1}]], [[number%(%-1234%) is not a subset of 1%.%.inf]])
end)