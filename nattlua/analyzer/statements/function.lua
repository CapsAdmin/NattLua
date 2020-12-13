return function(META)
    function META:AnalyzeFunctionStatement(statement)
        if statement.kind == "local_function" or statement.kind == "local_type_function" or statement.kind == "local_generics_type_function" then
            local env = statement.kind == "local_function" and "runtime" or "typesystem"
            self:CreateLocalValue(
                statement.tokens["identifier"], 
                self:AnalyzeFunctionExpression(statement, env), 
                env
            )
        elseif statement.kind == "function" or statement.kind == "type_function" then
            local env = statement.kind == "function" and "runtime" or "typesystem"
            local key = statement.expression
            
            if key.kind == "binary_operator" then
                local existing_type

                if env == "runtime" then
                    local obj = self:AnalyzeExpression(key.left, "typesystem")
                    local key = self:AnalyzeExpression(key.right, "typesystem")
                    existing_type = obj:Get(key)
                end

                local obj = self:AnalyzeExpression(key.left, env)
                local key = self:AnalyzeExpression(key.right, env)
                local val = existing_type or self:AnalyzeFunctionExpression(statement, env)
                self:NewIndexOperator(obj, key, val, statement, env)
            else
                local existing_type = env == "runtime" and self:GetLocalOrEnvironmentValue(key, "typesystem")

                local val = existing_type or self:AnalyzeFunctionExpression(statement, env)
                self:SetLocalOrEnvironmentValue(key, val, env)
            end
        else
            self:FatalError("unhandled statement: " .. statement.kind)
        end
    end
end