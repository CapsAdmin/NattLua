local table_insert = _G.table.insert
return function(META)
	function META:ParseLSXExpression()
		if
			not (
				self:IsToken("<") and
				not self:IsTokenOffset("local", -1)
			)
		then
			return
		end

		local node = self:StartNode("expression_lsx")
		node.tokens["<"] = self:ExpectToken("<")
		node.tag = self:ParseFunctionNameIndex()
		node.props = {}
		node.children = {}

		for _ = self:GetPosition(), self:GetLength() do
			if self:IsToken("{") and self:IsTokenOffset("...", 1) then
				local left = self:ExpectToken("{")
				local spread = self:read_table_spread()

				if not spread then
					self:Error("expected table spread")
					return self:ErrorExpression()
				end

				local right = self:ExpectToken("}")
				spread.tokens["{"] = left
				spread.tokens["}"] = right
				table_insert(node.props, spread)
			elseif self:IsTokenType("letter") and self:IsTokenOffset("=", 1) then
				if self:IsTokenTypeOffset("symbol", 2) and self:IsTokenOffset("{", 2) then
					local keyval = self:StartNode("sub_statement_table_key_value")
					keyval.tokens["identifier"] = self:ExpectTokenType("letter")
					keyval.tokens["="] = self:ExpectToken("=")
					keyval.tokens["{"] = self:ExpectToken("{")
					keyval.value_expression = self:ExpectRuntimeExpression()
					keyval.tokens["}"] = self:ExpectToken("}")
					keyval = self:EndNode(keyval)
					table_insert(node.props, keyval)
				elseif self:IsTokenTypeOffset("string", 2) or self:IsTokenType("number", 2) then
					local keyval = self:StartNode("sub_statement_table_key_value")
					keyval.tokens["identifier"] = self:ExpectTokenType("letter")
					keyval.tokens["="] = self:ExpectToken("=")
					keyval.value_expression = self:ParseKeywordValueTypeExpression()
					keyval = self:EndNode(keyval)
					table_insert(node.props, keyval)
				else
					self:Error("expected = { or = string or = number got " .. self:GetTokenOffset(3).type)
					local keyval = self:StartNode("sub_statement_table_key_value")
					keyval.tokens["identifier"] = self:NewToken("letter", "_")
					keyval.tokens["="] = self:NewToken("symbol", "=")
					keyval.value_expression = self:ErrorExpression()
					keyval = self:EndNode(keyval)
					table_insert(node.props, keyval)
				end
			else
				break
			end
		end

		if self:IsToken("/") then
			node.tokens["/"] = self:ExpectToken("/")
			node.tokens[">"] = self:ExpectToken(">")
			node = self:EndNode(node)
			return node
		end

		node.tokens[">"] = self:ExpectToken(">")

		for _ = self:GetPosition(), self:GetLength() do
			if self:IsTokenType("symbol") and self:IsToken("{") then
				local left = self:ExpectToken("{")
				local child = self:ExpectRuntimeExpression()
				child.tokens["lsx{"] = left
				table_insert(node.children, child)
				child.tokens["lsx}"] = self:ExpectToken("}")
			end

			for _ = self:GetPosition(), self:GetLength() do
				if
					self:IsTokenType("symbol") and
					self:IsToken("<") and
					self:IsTokenTypeOffset("letter", 1)
				then
					table_insert(node.children, self:ParseLSXExpression())
				else
					break
				end
			end

			if
				self:IsTokenType("symbol") and
				self:IsToken("<") and
				self:IsTokenTypeOffset("symbol", 1) and
				self:IsTokenOffset("/", 1)
			then
				break
			end

			do
				local string_node = self:StartNode("expression_value")
				string_node.value = self:ExpectTokenType("string")
				string_node = self:EndNode(string_node)
				table_insert(node.children, string_node)
			end
		end

		node.tokens["<2"] = self:ExpectToken("<")
		node.tokens["/"] = self:ExpectToken("/")
		node.tokens["type2"] = self:ExpectTokenType("letter")
		node.tokens[">2"] = self:ExpectToken(">")
		node = self:EndNode(node)
		return node
	end
end
