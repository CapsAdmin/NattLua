
local T = require("test.helpers")
local run = T.RunCode

run[[
    local function foo(x: {foo = boolean | nil}) 
        if x.foo and attest.equal(x.foo, true) then end
        attest.equal(x.foo, _ as boolean | nil)
    end
]]

run[[
    local a: number | string
    
    if type(a) == "number" then
        attest.equal(a, _ as number)
    end

    attest.equal(a, _ as number | string)
]]

run[[
    local x = _ as 1 | 2
    local y = x == 1 and attest.equal(x, 1) or attest.equal(x, 2)
    attest.equal(x, _ as 1 | 2)
]]

run[[
    local x = _ as 1|2|3
    local y = x == 1 and attest.equal(x, 1) or x == 2 and attest.equal(x, 2) or false
    attest.equal(y, _ as 1|2|false)
]]

run[[
    local x = _ as 1|2|3

    if x == 1 or attest.equal(x, _ as 2|3) then

    end
]]

run[[
    local x: 1 | "str"
    if x ~= 1 or attest.equal(x, 1) then
    
    end
]]

run[[
    local x: 1 | "str"
    if x == 1 or attest.equal(x, "str") then
    
    end
]]
run[[
    local a = true
    local result = not a or 1
    attest.equal(result, 1)
]]

run[[
    local a = function(arg: ref any) 
        attest.equal(arg, 1)
        return 1337
    end
    
    local b = a(1) or a(2)
    attest.equal(b, 1337)
]]

run[[
    local a: 1, b: 2
    local result = a and b


    attest.equal(result, 2)

    §assert(env.runtime.result:GetNode().kind == "binary_operator")
]]
run[[
    local x = _ as number
    if not x then return false end
    local x = true and attest.equal(x, _ as number)
]]

run[[
    local a: 1 | 2 | 3
    if a == 1 or a == 3 then
        attest.equal(a, _ as 1 | 3)
    end
]]

run[[
    local a: 1 | 2 | 3 | nil
    local b: true | nil
    if (a == 1 or a == 3) and b then
        attest.equal(a, _ as 1 | 3)
        attest.equal(b, true)
    end
]]

run[[
    local c: {foo = true } | nil

    if c and c.foo then
        attest.equal(c.foo, true)
    end
]]

run[[
    local tbl = {} as {foo = nil | {bar = 1337 | false}}

    if tbl.foo and tbl.foo.bar then
        attest.equal(tbl.foo.bar, 1337)
    end
]]

run[[
    -- make sure table key values clear affected upvalues

    local buff: {x = number, y = number} | {x = number, y = string}
    
    local x = {
        bar = buff.y,
        foo = bit.band(buff.x, 1) ~= 0 and "directory" or "file" 
    }
]]

run[[
    local tbl = {} as {foo = nil | {bar = 1337 | false}}

    if tbl.foo and attest.equal(tbl.foo.bar, _ as 1337 | false) then
        attest.equal(tbl.foo.bar, 1337)
    end
]]

run[[
    local a: nil | 1

    if a or true and a or false then
        attest.equal(a, _ as 1 | nil)
    end

    attest.equal(a, _ as 1 | nil)
]]