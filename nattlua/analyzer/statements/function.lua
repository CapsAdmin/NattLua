return function(META)
    function META:AnalyzeFunctionStatement(statement)
        if statement.kind == "local_function" then
            self:CreateLocalValue(
                statement.tokens["identifier"], 
                self:AnalyzeFunctionExpression(statement, "runtime"), 
                "runtime"
            )
        elseif statement.kind == "local_type_function" then
            self:CreateLocalValue(
                statement.identifier, 
                self:AnalyzeFunctionExpression(statement:ToExpression("type_function"), "typesystem"), 
                "typesystem"
            )
        elseif statement.kind == "local_generics_type_function" then
            self:CreateLocalValue(
                statement.identifier, 
                self:AnalyzeFunctionExpression(statement, "typesystem"), 
                "typesystem"
            )
        elseif statement.kind == "function" then
            local key = statement.expression
            
            if key.kind == "binary_operator" then
                -- TODO: lookup existing types here

                local obj = self:AnalyzeExpression(key.left, "runtime")
                local key = self:AnalyzeExpression(key.right, "runtime")
                local val = self:AnalyzeFunctionExpression(statement, "runtime")

                self:NewIndexOperator(obj, key, val, statement)
            else
                local existing_type = self:GetLocalOrEnvironmentValue(key, "typesystem")
                local val = existing_type or self:AnalyzeFunctionExpression(statement, "runtime")
                self:SetLocalOrEnvironmentValue(key, val, "runtime")
            end
        elseif statement.kind == "type_function" then
            local key = statement.expression
            
            if key.kind == "binary_operator" then
                -- TODO: lookup existing types here

                local obj = self:AnalyzeExpression(key.left, "typesystem")
                local key = self:AnalyzeExpression(key.right, "typesystem")
                local val = self:AnalyzeFunctionExpression(statement:ToExpression("type_function"), "typesystem")

                self:NewIndexOperator(obj, key, val, statement)
            else
                local val = self:AnalyzeFunctionExpression(statement:ToExpression("type_function"), "typesystem")
                self:SetLocalOrEnvironmentValue(key, val, "typesystem")
            end
        else
            self:FatalError("unhandled statement: " .. statement.kind)
        end
    end
end