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

run[[
    local META = {} as {[string] = any}
    META.__index = META
    
    type META.i = number
    type META.code = string
    
    type_assert(META.i, _ as number)
    type_assert(META.code, _ as string)
    type_assert(META.codeawdawd, _ as any) 
]]

run[[
    local META = {} as {[string] = any, i = number, code = string}
    META.__index = META

    type_assert(META.i, _ as number)
    type_assert(META.code, _ as string)
    type_assert(META.codeawdawd, _ as any)
]]