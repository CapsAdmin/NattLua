local types = require("nattlua.types.types")
types.Initialize()

local META = {}
META.__index = META

META.OnInitialize = {}

require("nattlua.analyzer.base.base_analyzer")(META)
require("nattlua.analyzer.control_flow")(META)

require("nattlua.analyzer.operators.index")(META)
require("nattlua.analyzer.operators.newindex")(META)
require("nattlua.analyzer.operators.call")(META)

require("nattlua.analyzer.statements")(META)
require("nattlua.analyzer.expressions")(META)

function META:NewType(node, type, data, literal)
    local obj

    if type == "table" then
        obj = self:Assert(node, types.Table(data))
    elseif type == "list" then
        obj = self:Assert(node, types.List(data))
    elseif type == "..." then
        obj = self:Assert(node, types.Tuple(data or {types.Any()}))
        obj:SetRepeat(math.huge)
    elseif type == "number" then
        obj = self:Assert(node, types.Number(data):MakeLiteral(literal))
    elseif type == "string" then
        obj = self:Assert(node, types.String(data):MakeLiteral(literal))
    elseif type == "boolean" then
        if literal then
            obj = types.Symbol(data)
        else
            obj = types.Boolean:Copy()
        end
    elseif type == "nil" then
        obj = self:Assert(node, types.Symbol(nil))
    elseif type == "any" then
        obj = self:Assert(node, types.Any())
    elseif type == "never" then
        obj = self:Assert(node, types.Never()) -- TEST ME
    elseif type == "error" then
        obj = self:Assert(node, types.Error(data)) -- TEST ME
    elseif type == "function" then
        obj = self:Assert(node, types.Function(data))
        obj.node = node

        if node.statements then 
            obj.function_body_node = node
        end
    end

    if not obj then error("NYI: " .. type) end

    obj.node = obj.node or node
    obj.node.inferred_type = obj
    
    return obj
end

do
    local guesses = {
        {pattern = "count", type = "number"},
        {pattern = "tbl", type = "table", ctor = function(obj) obj:Set(types.Any(), types.Any()) end},
        {pattern = "str", type = "string"},
    }

    table.sort(guesses, function(a, b) return #a.pattern > #b.pattern end)

    function META:GuessTypeFromIdentifier(node, env)

        if node.value then
            local str = node.value.value:lower()

            for _, v in ipairs(guesses) do
                if str:find(v.pattern, nil, true) then
                    local obj = self:NewType(node, v.type)
                    if v.ctor then
                        v.ctor(obj)
                    end
                    return obj
                end
            end
        end

        if env == "typesystem" then
            return self:NewType(node, "nil") -- TEST ME
        end

        return self:NewType(node, "any")
    end
end

return function()
    local self = setmetatable({}, META)
    for _, func in ipairs(META.OnInitialize) do
        func(self)
    end
    return self
end