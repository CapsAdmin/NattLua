local types = require("nattlua.types.types")

return function(META)
    function META:CheckTypeAgainstContract(val, contract)
        if contract.Type == "list" and val.Type == "table" then
            val = types.List(val:GetEnvironmentValues())
        end
        
        local skip_uniqueness = contract:IsUnique() and not val:IsUnique()
    
        if skip_uniqueness then
            contract:DisableUniqueness()
        end
    
        local ok, reason = val:IsSubsetOf(contract)
    
        if skip_uniqueness then
            contract:EnableUniqueness()
            val.unique_id = contract.unique_id
        end
    
        if not ok then
            return ok, reason
        end
    
        if contract.Type == "table" then
            return val:ContainsAllKeysIn(contract)
        end
    
        return true
    end

    function META:AnalyzeAssignmentStatement(statement)
        local env = self.PreferTypesystem and "typesystem" or statement.environment or "runtime"

        local left = {}
        local right = {}

        for i, exp_key in ipairs(statement.left) do
            if exp_key.kind == "value" then
                left[i] = exp_key
                if exp_key.kind == "value" then
                    exp_key.is_upvalue = self:LocalValueExists(exp_key, env)
                end
            elseif exp_key.kind == "postfix_expression_index" then
                left[i] = self:AnalyzeExpression(exp_key.expression, env)
            elseif exp_key.kind == "binary_operator" then
                left[i] = self:AnalyzeExpression(exp_key.right, env)
            else
                self:FatalError("unhandled expression " .. tostring(exp_key))
            end
        end

        if statement.right then
            for right_pos, exp_val in ipairs(statement.right) do
                
                self.left_assigned = left[right_pos]

                local obj = self:AnalyzeExpression(exp_val, env)

                if obj.Type == "tuple" or (obj.Type == "union" and obj:GetType("tuple")) then
                    for i = 1, #statement.left do
                        if obj.Type == "union" then
                            for _, obj in ipairs(obj:GetTypes()) do
                                if obj.Get then
                                    local val, err = obj:Get(i)
                                    if val then
                                        if right[right_pos + i - 1] then
                                            right[right_pos + i - 1] = types.Union({right[right_pos + i - 1], val})
                                        else
                                            right[right_pos + i - 1] = val
                                        end
                                    elseif i == 1 then
                                        if right[right_pos + i - 1] then
                                            right[right_pos + i - 1] = types.Union({right[right_pos + i - 1], obj})
                                        else
                                            right[right_pos + i - 1] = obj
                                        end
                                    end
                                end
                            end
                        else
                            right[right_pos + i - 1] = obj:Get(i)
                        end
                        
                        if exp_val.explicit_type then
                            right[right_pos + i - 1]:Seal() -- TEST ME
                        end
                    end
                else
                    right[right_pos] = obj

                    if exp_val.explicit_type then
                        obj:Seal()
                    end
                end
            end

            -- complicated
            -- cuts the last arguments
            -- local a,b,c = (any...), 1
            -- should be any, 1, nil
            local last = statement.right[#statement.right]
            
            if last.kind == "value" and last.value.value ~= "..." then
                for _ = 1, #right - #statement.right do
                    table.remove(right, #right)
                end
            end
        end

        for i, exp_key in ipairs(statement.left) do
            local val = right[i] or self:NewType(exp_key, "nil")

            if exp_key.explicit_type then
                local contract = self:AnalyzeExpression(exp_key.explicit_type, "typesystem")

                if right[i] then
                    val:CopyLiteralness(contract)
                    self:Assert(statement or val.node or exp_key.explicit_type, self:CheckTypeAgainstContract(val, contract))
                end

                val.contract = contract

                if not right[i] then
                    val = contract:Copy()
                    val.contract = contract
                end
            end

            exp_key.inferred_type = val
            val.node_label = exp_key

            if statement.kind == "local_assignment" then
                self:CreateLocalValue(exp_key, val, env)
            elseif statement.kind == "assignment" then
                local key = left[i]
                
                if exp_key.kind == "value" then

                    do -- check for any previous upvalues
                        local upvalue = self:GetLocalOrEnvironmentValue(key, env)
                        local upvalues_contract = upvalue and upvalue.contract

                        if not upvalue and not upvalues_contract and env == "runtime" then
                            upvalue = self:GetLocalOrEnvironmentValue(key, "typesystem")
                            if upvalue then
                                upvalues_contract = upvalue
                            end
                        end
                        
                        if upvalues_contract then
                            val:CopyLiteralness(upvalues_contract)
                            self:Assert(statement or val.node or exp_key.explicit_type, self:CheckTypeAgainstContract(val, upvalues_contract))
                            val.contract = upvalues_contract
                        end
                    end
                    
                    self:SetLocalOrEnvironmentValue(key, val, env)
                else
                    local obj = self:AnalyzeExpression(exp_key.left, env)
                    self:Assert(exp_key, self:NewIndexOperator(exp_key, obj, key, val, env))
                    self:FireEvent("newindex", obj, key, val, env)
                end
            end
        end
    end
end