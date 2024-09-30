local META = ...

function META:ParseLSXExpression()
	if
		not (
			self:IsTokenValue("<") and
			self:IsTokenType("letter", 1) and
			not self:IsTokenValue("local", -1)
		)
	then
		return
	end

	local node = self:StartNode("expression", "lsx")
	node.tokens["<"] = self:ExpectTokenValue("<")
	node.tag = self:ParseFunctionNameIndex()
	node.props = {}
	node.children = {}

	for _ = self:GetPosition(), self:GetLength() do
		if self:IsTokenValue("{") and self:IsTokenValue("...", 1) then
			local left = self:ExpectTokenValue("{")
			local spread = self:read_table_spread()

			if not spread then
				self:Error("expected table spread")
				return
			end

			local right = self:ExpectTokenValue("}")
			spread.tokens["{"] = left
			spread.tokens["}"] = right
			table.insert(node.props, spread)
		elseif self:IsTokenType("letter") and self:IsTokenValue("=", 1) then
			if self:IsTokenValue("{", 2) then
				local keyval = self:StartNode("sub_statement", "table_key_value")
				keyval.tokens["identifier"] = self:ExpectTokenType("letter")
				keyval.tokens["="] = self:ExpectTokenValue("=")
				keyval.tokens["{"] = self:ExpectTokenValue("{")
				keyval.value_expression = self:ExpectRuntimeExpression()
				keyval.tokens["}"] = self:ExpectTokenValue("}")
				keyval = self:EndNode(keyval)
				table.insert(node.props, keyval)
			elseif self:IsTokenType("string", 2) or self:IsTokenType("number", 2) then
				local keyval = self:StartNode("sub_statement", "table_key_value")
				keyval.tokens["identifier"] = self:ExpectTokenType("letter")
				keyval.tokens["="] = self:ExpectTokenValue("=")
				keyval.value_expression = self:ParseKeywordValueTypeExpression()
				keyval = self:EndNode(keyval)
				table.insert(node.props, keyval)
			else
				self:Error("expected = { or = string or = number got " .. self:GetToken(3).type)
			end
		else
			break
		end
	end

	if self:IsTokenValue("/") then
		node.tokens["/"] = self:ExpectTokenValue("/")
		node.tokens[">"] = self:ExpectTokenValue(">")
		node = self:EndNode(node)
		return node
	end

	node.tokens[">"] = self:ExpectTokenValue(">")

	for _ = self:GetPosition(), self:GetLength() do
		if self:IsTokenValue("{") then
			local left = self:ExpectTokenValue("{")
			local child = self:ExpectRuntimeExpression()
			child.tokens["lsx{"] = left
			table.insert(node.children, child)
			child.tokens["lsx}"] = self:ExpectTokenValue("}")
		end

		for _ = self:GetPosition(), self:GetLength() do
			if self:IsTokenValue("<") and self:IsTokenType("letter", 1) then
				table.insert(node.children, self:ParseLSXExpression())
			else
				break
			end
		end

		if self:IsTokenValue("<") and self:IsTokenValue("/", 1) then break end

		do
			local string_node = self:StartNode("expression", "value")
			string_node.value = self:ExpectTokenType("string")
			string_node = self:EndNode(string_node)
			table.insert(node.children, string_node)
		end
	end

	node.tokens["<2"] = self:ExpectTokenValue("<")
	node.tokens["/"] = self:ExpectTokenValue("/")
	node.tokens["type2"] = self:ExpectTokenType("letter")
	node.tokens[">2"] = self:ExpectTokenValue(">")
	node = self:EndNode(node)
	return node
end
