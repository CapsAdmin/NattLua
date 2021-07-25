local T = require("test.helpers")
local run = T.RunCode

run[[
    local type A = Tuple<|1,2|>
    local type B = Tuple<|3,4|>
    local type C = A .. B
    types.assert<|C, Tuple<|1,2,3,4|>|>
]]

