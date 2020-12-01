local types = require("nattlua.types.types")

return function(META)
    function META:AnalyzeNumericForStatement(statement)
        local init = self:AnalyzeExpression(statement.expressions[1])
        local max = self:AnalyzeExpression(statement.expressions[2])
        local step = statement.expressions[3] and self:AnalyzeExpression(statement.expressions[3]) or nil

        local literal_init = init:IsLiteral() and init:GetData() or nil
        local literal_max = max:IsLiteral() and max:GetData() or nil
        local literal_step = not step and 1 or step:IsLiteral() and step:GetData() or nil

        local condition = types.Union()

        if literal_init and literal_max then
            -- also check step
            condition:AddType(types.Symbol(init:GetData() <= max:GetData()))
        else
            condition:AddType(types.Symbol(true))
            condition:AddType(types.Symbol(false))
        end
        
        self:CreateAndPushScope(statement, nil, {
            type = "numeric_for",
            init = init, 
            max = max, 
            condition = condition
        })

        if literal_init and literal_max and literal_step and literal_max < 1000 then
            local uncertain_break = nil
            for i = literal_init, literal_max, literal_step do
                self:CreateAndPushScope(statement, nil, {
                    type = "numeric_for_iteration",
                    i = i, 
                })
                local i = self:NewType(statement.expressions[1], "number", i):MakeLiteral(true)
                local brk = false
                
                if uncertain_break then
                    i:MakeLiteral(false)
                    brk = true
                end

                self:CreateLocalValue(statement.identifiers[1], i, "runtime")
                self:AnalyzeStatements(statement.statements)
                if self.break_out_scope then
                    if self.break_out_scope:IsUncertain() then
                        uncertain_break = i
                        self.break_out_scope = nil
                    else
                        self.break_out_scope = nil
                        brk = true
                    end
                end

                self:PopScope({
                    type = "numeric_for_iteration",
                    i = i, 
                })

                if brk then
                    break
                end
            end
        else
            if init.Type == "number" and (max.Type == "number" or (max.Type == "union" and max:IsType("number"))) then
                init = init:Max(max)
            end

            if max.Type == "any" then
                init:MakeLiteral(false)
            end

            local range = self:Assert(statement.expressions[1], init)

            self:CreateLocalValue(statement.identifiers[1], range, "runtime")
            self:AnalyzeStatements(statement.statements)
        end

    
        local children = self:GetScope():GetChildren()
        if children[1] then
            local merged_scope = children[1]:Copy()
            for i = 2, #children do
                merged_scope:Merge(children[i])
            end

            for i,v in ipairs(merged_scope.upvalues.runtime.list) do
                if v.data.node_label then
                    v.data.node_label.inferred_type = v.data
                end
            end
        end

        self:PopScope({init = init, max = max, condition = condition})
    end

    function META:AnalyzeBreakStatement(statement)
        self.break_out_scope = self:GetScope()
        self:FireEvent("break")
    end
end