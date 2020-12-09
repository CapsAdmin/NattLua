local types = require("nattlua.types.types")

return function(META)

    local function get_largest_number(obj)
        if obj:IsLiteral() then
            if obj.Type == "union" then
                local max = -math.huge
                for i, v in ipairs(obj:GetData()) do
                    max = math.max(max, v:GetData())
                end
                return max
            end
            return obj:GetData()
        end
    end

    function META:AnalyzeNumericForStatement(statement)
        local init = self:AnalyzeExpression(statement.expressions[1])
        assert(init.Type == "number")
        local max = self:AnalyzeExpression(statement.expressions[2])
        assert(init.Type == "number")
        local step = statement.expressions[3] and self:AnalyzeExpression(statement.expressions[3]) or nil
        if step then
            assert(step.Type == "number")
        end

        local literal_init = get_largest_number(init)
        local literal_max = get_largest_number(max)
        local literal_step = not step and 1 or get_largest_number(step)

        local condition = types.Union()

        if literal_init and literal_max then
            -- also check step
            condition:AddType(self:BinaryOperator(statement, init, max, "runtime", "<="))
        else
            condition:AddType(types.Symbol(true))
            condition:AddType(types.Symbol(false))
        end

        statement.identifiers[1].inferred_type = init
        
        self:CreateAndPushScope()
        self:OnEnterConditionalScope({
            type = "numeric_for",
            init = init, 
            max = max, 
            condition = condition,
            step = step,
        })

        if literal_init and literal_max and literal_step and literal_max < 1000 then
            local uncertain_break = nil
            for i = literal_init, literal_max, literal_step do
                self:CreateAndPushScope()
                self:OnEnterConditionalScope({
                    type = "numeric_for_iteration",
                    condition = condition,
                    i = i, 
                })
                local i = self:NewType(statement.expressions[1], "number", i):MakeLiteral(true)
                local brk = false

                if not statement.identifiers[1].inferred_type then
                    statement.identifiers[1].inferred_type = types.Union({i})
                else
                    statement.identifiers[1].inferred_type = types.Union({statement.identifiers[1].inferred_type, i})
                end
                
                if uncertain_break then
                    i:MakeLiteral(false)
                    brk = true
                end

                self:CreateLocalValue(statement.identifiers[1], i, "runtime")
                self:AnalyzeStatements(statement.statements)

                if self.break_out_scope then

                    if self.break_out_scope:IsUncertain() then
                        uncertain_break = i
                    else
                        brk = true
                    end

                    self.break_out_scope = nil
                end

                self:PopScope()
                self:OnExitConditionalScope({
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
            local merged_scope = children[1]:Copy(true)
            for i = 2, #children do
                merged_scope:Merge(children[i])
            end

            merged_scope:MakeReadOnly(true)
            self:GetScope():AddChild(merged_scope)

            self:FireEvent("merge_iteration_scopes", merged_scope)

            self:PushScope(merged_scope)
                self:AnalyzeStatements(statement.statements)
            self:PopScope()
            
            self.break_out_scope = nil
        end

        self:PopScope()
        self:OnExitConditionalScope({init = init, max = max, condition = condition})
    end

    function META:AnalyzeBreakStatement(statement)
        self.break_out_scope = self:GetScope()
        self.break_loop = true
        self:FireEvent("break")
    end
end