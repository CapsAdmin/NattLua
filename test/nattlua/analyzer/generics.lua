local T = require("test.helpers")
local run = T.RunCode

run[=[
    -- without literal event_name


    local type declared = {}

    local events = {}

    local type function FunctionFromTuples(arg, ret)
        if arg.Type ~= "tuple" then arg = types.Tuple({arg})  end -- TODO
        if ret.Type ~= "tuple" then ret = types.Tuple({ret})  end -- TODO
        return types.Function({
            arg = arg,
            ret = ret,
        })
    end

    function events.Declare<|event_name: string, arguments: any, return_types: any|>
        declared[event_name] = FunctionFromTuples<|arguments, return_types|>
    end

    events.Declare<|"message", (string,), (boolean, string) | (number,)|>
    events.Declare<|"update", (number,), (boolean,)|>

    function events.AddListener(event_name: keysof<|declared|>, listener: declared[event_name])
        types.assert(event_name, _ as "message" | "update")
        types.assert(listener, _ as (function(number | string): ((false | true | (false | true, string) | (number,)))))
    end

    events.AddListener("message", function(data) 
        types.assert(data, _ as number | string)
        return 1337 
    end)
]=]

run[=[
    -- with literal event_name, causing it to choose the specific function

    local type declared = {}

    local events = {}

    local type function FunctionFromTuples(arg, ret)
        if arg.Type ~= "tuple" then arg = types.Tuple({arg})  end -- TODO
        if ret.Type ~= "tuple" then ret = types.Tuple({ret})  end -- TODO
        return types.Function({
            arg = arg,
            ret = ret,
        })
    end

    function events.Declare<|event_name: string, arguments: any, return_types: any|>
        declared[event_name] = FunctionFromTuples<|arguments, return_types|>
    end

    events.Declare<|"message", (string,), (boolean, string) | (number,)|>
    events.Declare<|"update", (number,), (boolean,)|>

    function events.AddListener(event_name: literal keysof<|declared|>, listener: declared[event_name])
        types.assert(event_name, _ as "message")
        types.assert(listener, _ as (function(string): (boolean, string) | (nil,)))
    end

    events.AddListener("message", function(data) types.assert(data, _ as string) return 1337 end)
]=]


run[[
    local type tbl = {}
    tbl.foo = 1337
    local function test(key: literal keysof<|tbl|>)
        return tbl[key]
    end
    types.assert(test("foo"), 1337)
]]

run([[
    local type tbl = {}
    tbl.foo = 1337
    local function test(key: literal keysof<|tbl|>)
        return tbl[key]
    end
    types.assert(test("bar"), 1337)
]], "bar.- is not a subset of.-foo")

run[[
    local function TypeToString<|T: any|>
        if T > number then
            return "number"
        end
        return "other"
    end
    
    local type a = TypeToString<|number|>
    types.assert<|a, "number"|>
    
    local type b = TypeToString<|string|>
    types.assert<|b, "other"|>
]]