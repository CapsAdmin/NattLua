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
    local function test(): Tuple<|1,"lol1"|> | Tuple<|2,"lol2"|>
        return 2, "lol2"
    end    
]]

run[[
    local foo: function=()>(true | false, string | nil)
    local ok, err = foo()
    types.assert(ok, _ as true | false)
    types.assert(err, _ as nil | string)
]]

run[[
    local foo: function=()>(Tuple<|true, 1|> | Tuple<|false, string, 2|>)
    local x,y,z = foo() 
    types.assert(x, _ as true | false)
    types.assert(y, _ as 1 | string)
    types.assert(z, _ as 2 | nil)
]]

run([[
    local function test(): Tuple<|1,"lol1"|> | Tuple<|2,"lol2"|>
        return "", "lol2"
    end
]], '"" is not the same type as 1')

