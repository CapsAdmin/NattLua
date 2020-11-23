local types = require("nattlua.types.types")

return function(META)
    function META:AnalyzeVarargTupleExpression(node, env)
        local obj = self:NewType(node, "...")
        obj:AddRemainder(types.Tuple(({self:GetEnvironmentValue(node.value, "typesystem")})))
        return obj
    end
end