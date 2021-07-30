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
]], "number is not the same type as string")

run[[
    local type contract = {}
    type contract.test = function(number): string

    local lib = {} as contract

    function lib.test(lol) 
        types.assert<|lol, number|>
        return "test"
    end
]]

run[[
    local META = {} as {[string] = any}
    META.__index = META
    
    type META.i = number
    type META.code = string
    
    types.assert(META.i, _ as number)
    types.assert(META.code, _ as string)
    types.assert(META.codeawdawd, _ as any) 
]]

run[[
    local META = {} as {[string] = any, i = number, code = string}
    META.__index = META

    types.assert(META.i, _ as number)
    types.assert(META.code, _ as string)
    types.assert(META.codeawdawd, _ as any)
]]