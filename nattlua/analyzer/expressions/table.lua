local types = require("nattlua.types.types")

return function(META)
    function META:AnalyzeTableExpression(node, env)
        local tbl = self:NewType(node, "table", nil, env == "typesystem")
        if env == "runtime" then
            tbl:SetReferenceId(tostring(tbl.data))
        end
        self.current_table = tbl
        for _, node in ipairs(node.children) do
            if node.kind == "table_key_value" then
                local key = self:NewType(node.tokens["identifier"], "string", node.tokens["identifier"].value, true)
                local val = self:AnalyzeExpression(node.expression, env)
                tbl:Set(key, val)
            elseif node.kind == "table_expression_value" then
                local key = self:AnalyzeExpression(node.expressions[1], env)
                local obj = self:AnalyzeExpression(node.expressions[2], env)

                tbl:Set(key, obj)
            elseif node.kind == "table_index_value" then
                local val = {self:AnalyzeExpression(node.expression, env)}
                
                if val[1].Type == "tuple" then
                    local tup = val[1]
                    for i = 1, tup:GetMinimumLength() do
                        tbl:Set(tbl:GetLength() + 1, tup:Get(i))
                    end

                    if tup.Remainder then
                        local current_index = types.Number(tbl:GetLength() + 1):MakeLiteral(true)
                        local max = types.Number(tup.Remainder:GetLength()):MakeLiteral(true)
                        tbl:Set(current_index:Max(max), tup.Remainder:Get(1))
                    end
                else 
                    if node.i then
                        tbl:Insert(val[1])
                    elseif val then
                        for _, val in ipairs(val) do
                            tbl:Insert(val)
                        end
                    end
                end
            end
        end
        self.current_table = nil
        return tbl
    end
end