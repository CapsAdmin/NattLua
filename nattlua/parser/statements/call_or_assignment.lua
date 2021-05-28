return function(self)		
    local start = self:GetCurrentToken()
    local left = self:ReadExpressionList(math.huge)

    if self:IsCurrentValue("=") then
        local node = self:Statement("assignment")
        node:ExpectKeyword("=")
        node.left = left
        node.right = self:ReadExpressionList(math.huge)
        return node:End()
    end

    if left[1] and (left[1].kind == "postfix_call" or left[1].kind == "import") and not left[2] then
        local node = self:Statement("call_expression")
        node.value = left[1]
        node.tokens = left[1].tokens
        return node:End()
    end

    self:Error(
        "expected assignment or call expression got $1 ($2)",
        start,
        self:GetCurrentToken(),
        self:GetCurrentToken().type,
        self:GetCurrentToken().value
    )
end