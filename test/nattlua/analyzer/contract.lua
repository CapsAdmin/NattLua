local T = require("test.helpers")
local run = T.RunCode

run([[
    local type contract = {}
    type contract.test = function(number): string

    local lib = {} as contract

    function lib.unknown() 

    end
]], "is not the same value as")

run([[
    local type contract = {}
    type contract.test = function(number): string

    local lib = {} as contract

    function lib.test(lol: string) 
        return 1,2,3
    end
]], "1 is not the same type as string")

run[[
    local type contract = {}
    type contract.test = function(number): string

    local lib = {} as contract

    function lib.test(lol) 
        type_assert<|lol, number|>
        return "test"
    end
]]