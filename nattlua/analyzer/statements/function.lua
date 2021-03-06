return function(META)
    function META:AnalyzeFunctionStatement(statement)
        if statement.kind == "local_function" or statement.kind == "local_type_function" or statement.kind == "local_generics_type_function" then
            local env = statement.kind == "local_function" and "runtime" or "typesystem"
            self:CreateLocalValue(
                statement.tokens["identifier"], 
                self:AnalyzeFunctionExpression(statement, env), 
                env
            )
        elseif statement.kind == "function" or statement.kind == "type_function" or statement.kind == "generics_type_function" then
            local env = statement.kind == "function" and "runtime" or "typesystem"
            local key = statement.expression
            
            if key.kind == "binary_operator" then
                local existing_type

                if env == "runtime" then
                    
                    self.SuppressDiagnostics = true
                    existing_type = self:AnalyzeExpression(key, "typesystem")
                    self.SuppressDiagnostics = false

                    if existing_type.Type == "symbol" and existing_type:GetData() == nil then
                        existing_type = nil
                    end
                end

                local obj = self:AnalyzeExpression(key.left, env)
                local key = self:AnalyzeExpression(key.right, env)
                local val = self:AnalyzeFunctionExpression(statement, env)

                if existing_type and existing_type.Type == "function" then
                    val:SetArguments(existing_type:GetArguments())
                    val:GetData().ret = existing_type:GetReturnTypes() -- TODO
                end
                
                self:NewIndexOperator(statement, obj, key, val, env)
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