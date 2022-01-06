local T = require("test.helpers")
local run = T.RunCode

pending[[
    local function test(): ErrorReturn<|{foo = number}|>
        if math.random() > 0.5 then
            return {foo = number}
        end
        return nil, "uh oh"
    end    
]]

pending[[

    local function last_error()
        if math.random() > 0.5 then
            return "strerror returns null"
        end

        if math.random() > 0.5 then
            return _ as string
        end
    end

    local function test(): ErrorReturn<|{foo = number}|>
        if math.random() > 0.5 then
            return {foo = number}
        end
        return nil, last_error()
    end    

]]
run[[
    local function test(): (1,"lol1") | (2,"lol2")
        return 2, "lol2"
    end    
]]

run[[
    local foo: function=()>(true | false, string | nil)
    local ok, err = foo()
    attest.equal(ok, _ as true | false)
    attest.equal(err, _ as nil | string)
]]

run[[
    local foo: function=()>((true, 1) | (false, string, 2))
    local x,y,z = foo() 
    attest.equal(x, _ as true | false)
    attest.equal(y, _ as 1 | string)
    attest.equal(z, _ as 2 | nil)
]]

run([[
    local function test(): (1,"lol1") | (2,"lol2")
        return "", "lol2"
    end
]], '"" is not the same type as 1')

