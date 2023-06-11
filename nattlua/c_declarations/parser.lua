local META = loadfile("nattlua/parser.lua")()

function META:ParseRootNode()
	local node = self:StartNode("statement", "root")
	node.statements = self:ParseStatements()

	if self:IsTokenType("end_of_file") then
		local eof = self:StartNode("statement", "end_of_file")
		eof.tokens["end_of_file"] = self.tokens[#self.tokens]
		eof = self:EndNode(eof)
		table.insert(node.statements, eof)
		node.tokens["eof"] = eof.tokens["end_of_file"]
	end

	return self:EndNode(node)
end

function META:ParseStatement()
	if self:IsTokenType("end_of_file") then return end

	local node = self:ParseTypeDefStatement() or
		self:ParseStruct() or
		self:ParseEnum() or
		self:ParseUnion() or
		self:ParseFunctionDeclarationStatement()

	if not node then
		self:Error("expected statement")
		return
	end

	if not self:IsTokenValue(";") then
		print("expected semicolon after statement: ", node and node.kind or "wtf")
	end

	node.tokens[";"] = self:ExpectTokenValue(";")
	return node
end

function META:ParseFunctionDeclarationStatement()
	local node = self:StartNode("statement", "function_declaration")
	self.nameless = true
	node.return_type = self:ParseTypeDeclaration()
	self.nameless = nil

	if self:IsTokenValue("(") then
		self.parsing_function = true
		node.expression = self:ParseCExpression()
		self.parsing_function = false
	else
		node.tokens["identifier"] = self:ExpectTokenType("letter")
	end

	node.tokens["("] = self:ExpectTokenValue("(")
	node.arguments = self:ParseFunctionArguments()
	node.tokens[")"] = self:ExpectTokenValue(")")

	if self:IsTokenValue("asm") then
		node.tokens["asm"] = self:ExpectTokenValue("asm")
		node.tokens["asm_("] = self:ExpectTokenValue("(")
		node.tokens["asm_string"] = self:ExpectTokenType("string")
		node.tokens["asm_)"] = self:ExpectTokenValue(")")
	end

	return self:EndNode(node)
end

function META:ParseFunctionArguments()
	local out = {}

	while not self:IsTokenValue(")") do
		if self:IsTokenValue("...") then
			local node = self:StartNode("expression", "vararg")
			node.tokens["..."] = self:ExpectTokenValue("...")
			table.insert(out, node)
		else
			local node = self:ParseTypeDeclaration()

			-- belongs to function node?
			if self:IsTokenValue(",") then
				node.tokens[","] = self:ExpectTokenValue(",")
			end

			table.insert(out, node)
		end
	end

	return out
end

function META:ParseTypeDefStatement()
	if not self:IsTokenValue("typedef") then return end

	local node = self:StartNode("statement", "typedef")
	node.tokens["typedef"] = self:ExpectTokenType("letter")

	if self:IsTokenValue("struct") then
		node.value = self:ParseStruct()
	elseif self:IsTokenValue("union") then
		node.value = self:ParseUnion()
	elseif self:IsTokenValue("enum") then
		node.value = self:ParseEnum()
	else
		node.value = self:ParseTypeDeclaration()
	end

	if self:IsTokenType("letter") then
		node.tokens["identifier"] = self:ExpectTokenType("letter")
	end

	return self:EndNode(node)
end

function META:ParseEnum()
	if not self:IsTokenValue("enum") then return end

	local node = self:StartNode("statement", "enum")
	node.tokens["enum"] = self:ExpectTokenValue("enum")
	node.fields = {}

	if self:IsTokenType("letter") then
		node.tokens["identifier"] = self:ExpectTokenType("letter")
	end

	if not self:IsTokenValue("{") then
		-- forward declaration
		return self:EndNode(node)
	end

	node.tokens["{"] = self:ExpectTokenValue("{")

	while true do
		if self:IsTokenValue("}") then break end

		local field = self:StartNode("statement", "enum_field")
		field.tokens["identifier"] = self:ExpectTokenType("letter")

		if self:IsTokenValue("=") then
			field.tokens["="] = self:ExpectTokenValue("=")
			field.value = self:ExpectRuntimeExpression()
		end

		if self:IsTokenValue(",") then
			field.tokens[","] = self:ExpectTokenValue(",")
		end

		table.insert(node.fields, self:EndNode(field))
	end

	node.tokens["}"] = self:ExpectTokenValue("}")
	return self:EndNode(node)
end

function META:ParseStruct()
	return self:ParseStructOrUnion("struct")
end

function META:ParseUnion()
	return self:ParseStructOrUnion("union")
end

function META:ParseStructOrUnion(type)
	if not self:IsTokenValue(type) then return end

	local node = self:StartNode("statement", type)
	node.tokens[type] = self:ExpectTokenValue(type)

	if self:IsTokenType("letter") then
		node.tokens["identifier"] = self:ExpectTokenType("letter")
	end

	if not self:IsTokenValue("{") then
		-- forward declaration
		return self:EndNode(node)
	end

	node.tokens["{"] = self:ExpectTokenValue("{")
	node.fields = {}

	while true do
		if self:IsTokenValue("}") then break end

		if
			self:IsTokenValue("enum") or
			(
				self:IsTokenValue("const") and
				self:IsTokenValue("enum", 1)
			)
		then
			local const

			if self:IsTokenValue("const") then
				const = self:ExpectTokenValue("const")
			end

			local field = self:ParseEnum()
			field.tokens["const"] = const

			if self:IsTokenType("letter") then
				field.tokens["identifier2"] = self:ExpectTokenType("letter")
			end

			if self:IsTokenValue("[") or self:IsTokenValue("*") then
				field.expression = self:ParseCExpression()
			end

			field.tokens[";"] = self:ExpectTokenValue(";")
			table.insert(node.fields, self:EndNode(field))
		elseif
			self:IsTokenValue("struct") or
			(
				self:IsTokenValue("const") and
				self:IsTokenValue("struct", 1)
			)
		then
			local const

			if self:IsTokenValue("const") then
				const = self:ExpectTokenValue("const")
			end

			local field = self:ParseStruct()
			field.tokens["const"] = const

			if self:IsTokenType("letter") then
				field.tokens["identifier2"] = self:ExpectTokenType("letter")
			end

			if self:IsTokenValue("[") or self:IsTokenValue("*") then
				field.expression = self:ParseCExpression()
			end

			field.tokens[";"] = self:ExpectTokenValue(";")
			table.insert(node.fields, self:EndNode(field))
		elseif
			self:IsTokenValue("union") or
			(
				self:IsTokenValue("const") and
				self:IsTokenValue("union", 1)
			)
		then
			local const

			if self:IsTokenValue("const") then
				const = self:ExpectTokenValue("const")
			end

			local field = self:ParseUnion()
			field.tokens["const"] = const

			if self:IsTokenType("letter") then
				field.tokens["identifier2"] = self:ExpectTokenType("letter")
			end

			if self:IsTokenValue("[") or self:IsTokenValue("*") then
				field.expression = self:ParseCExpression()
			end

			field.tokens[";"] = self:ExpectTokenValue(";")
			table.insert(node.fields, self:EndNode(field))
		else
			local field = self:StartNode("statement", "struct_field")
			field.type_declaration = self:ParseTypeDeclaration()

			if self:IsTokenValue(":") then
				field.tokens[":"] = self:ExpectTokenValue(":")
				field.bit_field = self:ExpectTokenType("number")
			end

			if self:IsTokenValue("=") then
				field.tokens["="] = self:ExpectTokenValue("=")
				field.value = self:ExpectRuntimeExpression()
			elseif self:IsTokenValue(",") then
				field.shorthand_identifiers = {}
				local shorthand = {}
				shorthand[","] = self:ExpectTokenValue(",")
				table.insert(field.shorthand_identifiers, shorthand)

				while true do
					local shorthand = {}
					shorthand.token = self:ExpectTokenType("letter")

					if self:IsTokenValue(":") then
						shorthand[":"] = self:ExpectTokenValue(":")
						shorthand.bit_field = self:ExpectTokenType("number")
					end

					if self:IsTokenValue(";") then
						table.insert(field.shorthand_identifiers, shorthand)

						break
					end

					shorthand[","] = self:ExpectTokenValue(",")
					table.insert(field.shorthand_identifiers, shorthand)
				end
			end

			field.tokens[";"] = self:ExpectTokenValue(";")
			table.insert(node.fields, self:EndNode(field))
		end
	end

	node.tokens["}"] = self:ExpectTokenValue("}")
	return self:EndNode(node)
end

do
	function META:ParseCExpression()
		local node = self:StartNode("expression", "type_expression")

		if self:IsTokenValue("*") then
			node.expression = self:ParsePointerExpression()
		elseif self:IsTokenValue("(") then
			node.expression = self:ParseParenExpression()
		elseif self:IsTokenValue("[") then
			node.expression = self:ParseArrayExpression()
		end

		return self:EndNode(node)
	end

	function META:ParseReturnTypexpression()
		local node = self:StartNode("expression", "type_expression")

		if self:IsTokenValue("*") then
			node.expression = self:ParsePointerExpression()
		end

		return self:EndNode(node)
	end

	function META:ParseArrayExpression()
		local node = self:StartNode("expression", "array_expression")

		if self:IsTokenType("letter") then
			node.tokens["identifier"] = self:ExpectTokenType("letter")
		end

		node.tokens["["] = self:ExpectTokenValue("[")
		node.size_expression = self:ParseRuntimeExpression()
		node.tokens["]"] = self:ExpectTokenValue("]")

		if self:IsTokenValue("[") then
			node.expression = self:ParseArrayExpression()
		end

		return self:EndNode(node)
	end

	function META:ParseParenExpression()
		local open = self:ExpectTokenValue("(")
		local expression = self:ParseCExpression()

		if not expression.value then
			if self.parsing_function then
				expression = self:ExpectTokenType("letter")
			end
		end

		local close = self:ExpectTokenValue(")")

		if not self.parsing_function then
			if self:IsTokenValue("(") then
				local node = self:StartNode("expression", "function_expression")
				node.tokens["("] = open
				node.expression = expression
				node.tokens[")"] = close
				node.tokens["arguments_("] = self:ExpectTokenValue("(")
				node.arguments = self:ParseFunctionArguments()
				node.tokens["arguments_)"] = self:ExpectTokenValue(")")
				return self:EndNode(node)
			end
		end

		local node = self:StartNode("expression", "paren_expression")
		node.tokens["("] = open
		node.expression = expression
		node.tokens[")"] = close

		if self:IsTokenValue("[") then
			local array_exp = self:ParseArrayExpression()
			array_exp.left_expression = node
			self:EndNode(node)
			return array_exp
		end

		return self:EndNode(node)
	end

	function META:ParsePointerExpression()
		local node = self:StartNode("expression", "pointer_expression")
		node.tokens["*"] = self:ExpectTokenValue("*")

		if self:IsTokenValue("__ptr32") then
			node.tokens["__ptr32"] = self:ExpectTokenValue("__ptr32")
		elseif self:IsTokenValue("__ptr64") then
			node.tokens["__ptr64"] = self:ExpectTokenValue("__ptr64")
		end

		if not self.nameless then
			if self:IsTokenType("letter") then
				node.tokens["identifier"] = self:ExpectTokenType("letter")
			end
		end

		node.expression = self:ParseCExpression()
		return self:EndNode(node)
	end

	function META:FindEndOfReturnType()
		--[[
			unsigned int bgfx_set_transform(const void*,unsigned short);
    		unsigned int(bgfx_set_transform)(const void*,unsigned short);
    		unsigned int (*bgfx_set_transform)(const void*,unsigned short);
		]]

		local offset = 0
		local found_opening = false
		while true do
			if self:IsTokenValue("(", offset) then
				found_opening = true
			end

			if found_opening then
				if self:IsTokenValue(")", offset) then
					return offset
				end
			end

			offset = offset + 1
		end
	end

	function META:ParseTypeDeclaration()
		local node = self:StartNode("expression", "type_declaration")
		local modifiers = {}

		while self:IsTokenType("letter") do -- skip function declaration
			if self:IsTokenValue("union") then
				table.insert(modifiers, self:ParseUnion())
			elseif self:IsTokenValue("struct") then
				table.insert(modifiers, self:ParseStruct())
			elseif self:IsTokenValue("enum") then
				table.insert(modifiers, self:ParseEnum())
			elseif self:IsTokenValue("__attribute__") or self:IsTokenValue("__attribute") then
				local attrnode = self:StartNode("expression", "attribute_expression")
				attrnode.tokens["__attribute__"] = self:ExpectTokenType("letter")
				attrnode.tokens["("] = self:ExpectTokenValue("(")
				attrnode.expression = self:ParseRuntimeExpression()
				attrnode.tokens[")"] = self:ExpectTokenValue(")")
				table.insert(modifiers, self:EndNode(attrnode))
			else
				table.insert(modifiers, self:ExpectTokenType("letter"))
			end

			for i = 0, 10 do
				if self:IsTokenValue(")", i) and self:IsTokenValue("(", i + 1) then 
					
				end
			end
		end

		print(self:GetToken(), "!")
		node.modifiers = modifiers

		if self:IsTokenValue("(") then

		else
			node.expression = self:ParseCExpression()
		end

		return self:EndNode(node)
	end
end

if false then
	for k, v in pairs(META) do
		if type(v) == "function" then
			META[k] = function(self, ...)
				if
					getmetatable(self) and
					k ~= "GetToken" and
					debug.getinfo(2).source:find("c_declarations")
				then
					print(
						debug.getinfo(2).source:sub(2) .. ":" .. debug.getinfo(2).currentline,
						k,
						self:GetToken().value,
						...
					)
				end

				return v(self, ...)
			end
		end
	end
end

return META