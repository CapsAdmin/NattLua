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
            local existing_type = self:GetEnvironmentValue(statement.expression, "typesystem")

            if existing_type then
                self:SetEnvironmentValue(
                    statement.expression, 
                    existing_type, 
                    "runtime"
                )
            else
                self:SetEnvironmentValue(
                    statement.expression, 
                    self:AnalyzeFunctionExpression(statement, "runtime"), 
                    "runtime"
                )
            end
        elseif statement.kind == "type_function" then
            self:SetEnvironmentValue(
                statement.expression,
                self:AnalyzeFunctionExpression(statement:ToExpression("type_function"), "typesystem"), 
                "typesystem"
            )
        else
            self:FatalError("unhandled statement: " .. statement.kind)
        end
    end
end