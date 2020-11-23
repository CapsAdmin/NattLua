local types = require("nattlua.types.types")

return function(META)
    table.insert(META.OnInitialize, function(self) 
        self.returned_from_certain_scope = false
        self.returned_from_block = 0
        self.return_to_this_level = 0
        self.returns = {}
    end)

    -- return statement
    function META:CollectReturnExpressions(types)
        table.insert(self.returns[1], types)

        self.returned_from_certain_scope = not self:GetScope().uncertain
        self.returned_from_block = self.returned_from_block + 1
    end

    function META:ResetReturnState()
        self.returned_from_certain_scope = false
    end

    -- used in exit scope
    function META:DidJustReturnFromBlock()
        local a = self.returned_from_block > 0
        self.returned_from_block = self.returned_from_block - 1
        return a
    end

    function META:AnalyzeStatementsAndCollectReturnTypes(statement)
        self:ResetReturnState()
        self.return_to_this_level = #self:GetScopeStack()
        table.insert(self.returns, 1, {})
        self:AnalyzeStatements(statement.statements)
        local out = {}
        if self.returns then
            local return_types = table.remove(self.returns, 1)
            if return_types then
                for _, ret in ipairs(return_types) do
                    for i, obj in ipairs(ret) do
                        if out[i] then
                            out[i] = types.Union({out[i], obj})
                        else
                            out[i] = obj
                        end
                    end
                end
            end
        end
        return types.Tuple(out)
    end

    function META:AnalyzeStatements(statements)
        for i, statement in ipairs(statements) do
            self:AnalyzeStatement(statement)

            -- if we're analyzing statements and encounter a return statement
            -- certain: do return x end
            -- certain: if true then return x end
            -- uncertain: if math.random() > 0.5 then return x end
            if self.returned_from_certain_scope and self.return_to_this_level == #self:GetScopeStack() then
                if 
                    statement.kind ~= "return" and 
                    statement.kind ~= "if" and 
                    statement.kind ~= "numeric_for" and
                    statement.kind ~= "do"
                then
                    self:FatalError("returning from invalid statement: " .. tostring(statement))
                end
                
                self.return_to_this_level = nil
                self.returned_from_certain_scope = false
                
                break
            end
        end
    end
end