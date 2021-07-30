local T = require("test.helpers")
local run = T.RunCode

pending[=[
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

    events.Declare<|"message", Tuple<|string|>, Tuple<|boolean, string|> | Tuple<|nil|>|>
    events.Declare<|"update", Tuple<|number|>, Tuple<|boolean|>|>

    function events.AddListener(event_name: keysof<|declared|>, listener: declared[event_name])
        types.assert(event_name, _ as "message" | "update")
        types.assert(listener, _ as (function(number | string): (Tuple<|boolean|> | Tuple<|boolean, string|> | Tuple<|nil|> )))
    end

    events.AddListener("message", function(data) 
      types.assert(data, _ as string | number)
      return true, "test"
    end)
]=]

run[=[
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

    events.Declare<|"message", Tuple<|string|>, Tuple<|boolean, string|> | Tuple<|number|>|>
    events.Declare<|"update", Tuple<|number|>, Tuple<|boolean|>|>

    function events.AddListener(event_name: literal keysof<|declared|>, listener: declared[event_name])
        types.assert(event_name, _ as "message")
        types.assert(listener, _ as (function(string): Tuple<|boolean, string|> | Tuple<|nil|>))
    end

    events.AddListener("message", function(data) types.assert(data, _ as string) return 1337 end)
]=]