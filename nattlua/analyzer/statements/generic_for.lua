local types = require("nattlua.types.types")

return function(META)
    function META:AnalyzeGenericForStatement(statement)
        local args = self:AnalyzeExpressions(statement.expressions)
        local obj = table.remove(args, 1)
        
        if not obj then return end

        if obj.Type == "tuple" then obj = obj:Get(1) end
    
        local returned_key = nil
        local one_loop = args[1] and args[1].Type == "any"
        
        for i = 1, 1000 do
            local values = self:Assert(statement.expressions[1], self:Call(obj, types.Tuple(args), statement.expressions[1]))

            if not values:Get(1) or values:Get(1).Type == "symbol" and values:Get(1).data == nil then
                break
            end

            if i == 1 then
                returned_key = values:Get(1)
                if not returned_key:IsLiteral() then
                    returned_key = types.Union({types.Symbol(nil), returned_key})
                end
                self:CreateAndPushScope(statement, nil, {
                    type = "generic_for",
                    condition = returned_key
                })
            end

            for i,v in ipairs(statement.identifiers) do
                self:CreateLocalValue(v, values:Get(i), "runtime")
            end

            self:AnalyzeStatements(statement.statements)

            if i == 1000 then
                self:Error(statement, "too many iterations")
            end

            table.insert(values.data, 1, args[1])

            args = values:GetData()

            if one_loop then
                break
            end
        end

        if returned_key then
            self:PopScope({condition = returned_key})
        end

    end
end