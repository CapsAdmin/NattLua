return function(META)
    function META:AnalyzeDestructureAssignment(statement)
        local env = statement.environment or "runtime"
        local obj = self:AnalyzeExpression(statement.right, env)

        if obj.Type ~= "table" then
            self:Error(statement.right, "expected a table on the right hand side, got " .. tostring(obj))
        end

        if statement.default then
            if statement.kind == "local_destructure_assignment" then
                self:CreateLocalValue(statement.default, obj, env)
            elseif statement.kind == "destructure_assignment" then
                self:SetLocalOrEnvironmentValue(statement.default, obj, env)
            end
        end

        for _, node in ipairs(statement.left) do
            local obj = node.value and obj:Get(node.value.value, env) or self:NewType(node, "nil")

            if statement.kind == "local_destructure_assignment" then
                self:CreateLocalValue(node, obj, env)
            elseif statement.kind == "destructure_assignment" then
                self:SetLocalOrEnvironmentValue(node, obj, env)
            end
        end
    end
end