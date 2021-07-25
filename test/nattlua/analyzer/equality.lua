local T = require("test.helpers")
local run = T.RunCode

run[[
    -- this should be true | false because it might actually also be the same table
    local type get_a_table = function(): {}

    types.assert(get_a_table() == get_a_table(), _ as true | false)
]]

run[[
    -- if a table is created a runtime, it should have a reference id that it can compare itself to
    local a = {}
    local b = a
    types.assert(a == b, true)
]]

run[[
    local a = {}
    local b = {}
    types.assert(a == b, false)
]]

run[[
    -- in the typesystem comparing a table should compare their type
    local type a = {}
    local type b = {}
    types.assert<|a == b, true|>
]]

run[[
    local type a = {}
    local type b = {[number] = number}
    types.assert<|a == b, false|>
]]

run[[
    local type a = {[number] = number}
    local type b = {[number] = number}
    types.assert<|a == b, true|>
]]

run[[
    local type a = {[1] = 4}
    local type b = {[number] = number}
    
    types.assert<|a == b, false|>
]]

