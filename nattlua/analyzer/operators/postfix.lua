return function(META)
    function META:PostfixOperator(node, r, env)
        local op = node.value.value

        if op == "++" then
            return self:BinaryOperator({value = {value = "+"}}, r, r, env)
        end
    end

    function META:AnalyzePostfixOperatorExpression(node, env)
        return self:Assert(node, self:PostfixOperator(node, self:AnalyzeExpression(node.left, env), env))
    end
end