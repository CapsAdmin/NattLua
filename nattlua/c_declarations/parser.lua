local META = loadfile("nattlua/parser.lua")()
META.FFI_DECLARATION_PARSER = true

function META:ParseRootNode()
	local node = self:StartNode("statement", "root")
	node.statements = self:ParseStatements()
	local eof = self:StartNode("statement", "end_of_file")
	eof.tokens["end_of_file"] = self.tokens[#self.tokens]
	eof = self:EndNode(eof)
	table.insert(node.statements, eof)
	node.tokens["eof"] = eof.tokens["end_of_file"]
	return self:EndNode(node)
end

function META:ParseStatement()
	if self:IsTokenType("end_of_file") then return end

	local node = self:ParseTypeDef() or self:ParseDeclarationStatement()

	if not node then
		self:Error("expected statement")
		return
	end

	-- multi declaration
	-- int foo, *bar;
	if not self:IsTokenValue(";") then
		local decls = {}

		for i = 1, self:GetLength() do
			if self:IsTokenValue(";") then break end

			local typ = self:ParseDeclarationStatement()
			table.insert(decls, typ)

			if self:IsTokenValue(",") then
				typ.tokens[","] = self:ExpectTokenValue(",")
			end

			node.decls = decls
		end
	end

	node.tokens[";"] = self:ExpectTokenValue(";")
	return node
end

-- TODO: remove the need for this
function META:IsInArguments()
	if self:IsTokenValue("(") then
		for i = 1, self:GetLength() do
			-- what happens if we have a function pointer in the arguments?
			-- void foo(void (*)(int, int))
			-- I guess it still works as a hacky solution
			if self:IsTokenValue(",", i) then return true end
		end
	end

	return false
end

function META:ParseCDeclaration()
	local node = self:StartNode("expression", "c_declaration")

	if self:IsTokenValue("...") then
		node.tokens["..."] = self:ExpectTokenValue("...")
		return self:EndNode(node)
	end

	if self:IsTokenType("string") then
		local found = {}

		-- char[sizeof("foo" "bar")]
		for i = 1, self:GetLength() do
			if self:IsTokenType("string") then
				table.insert(found, self:ConsumeToken())
			else
				break
			end
		end

		node.strings = found
		return self:EndNode(node)
	end

	node.modifiers = self:ParseAttributes(node)

	-- plain function or function pointer
	-- void >>(foo)<<() or void >>(*foo)<<()
	if self:IsTokenValue("(") then
		self:ParseCFunctionDeclaration(node)
	else
		self:ParseCTypeDeclaration(node)
	end

	node.tokens["potential_identifier"] = self:FindPotentialIdentifier(node)
	return self:EndNode(node)
end

function META:ParseDeclarationStatement()
	local node = self:ParseCDeclaration()

	if self:IsTokenValue("=") then
		node.tokens["="] = self:ExpectTokenValue("=")
		node.default_expression = self:ParseRuntimeExpression()
	end

	return node
end

function META:ParseStructField()
	local node = self:ParseCDeclaration()

	if self:IsTokenValue(":") then
		node.tokens[":"] = self:ExpectTokenValue(":")
		node.bitfield_expression = self:ParseRuntimeExpression()
	end

	if self:IsTokenValue("=") then
		node.tokens["="] = self:ExpectTokenValue("=")
		node.default_expression = self:ParseRuntimeExpression()
	end

	return node
end

function META:FindPotentialIdentifier(node)
	if node.expression and node.expression.tokens["potential_identifier"] then
		return node.expression.tokens["potential_identifier"]
	end

	if node.tokens["potential_identifier"] then
		return node.expression.tokens["potential_identifier"]
	end

	if node.tokens["identifier"] then
		return node.tokens["identifier"]
	else
		local last_pointer = node.pointers and node.pointers[#node.pointers]

		if last_pointer and last_pointer[2] and last_pointer[2].type == "letter" then
			return last_pointer[2]
		else
			if node.expression and node.expression.tokens["potential_identifier"] then
				return node.expression.tokens["potential_identifier"]
			else
				local last_modifier = node.modifiers[#node.modifiers]

				if last_modifier and last_modifier.type == "letter" then
					return node.modifiers[#node.modifiers]
				else
					for _, modifier in ipairs(node.modifiers) do
						if modifier.kind == "struct" or modifier.kind == "union" or modifier.kind == "enum" then
							return modifier.tokens["identifier"]
						end
					end
				end
			end
		end
	end
end

function META:IsEndOfTypeQualifiersAndSpecifiers()
	return self:IsTokenValue("(") or
		self:IsTokenValue("*") or
		self:IsTokenValue("[") or
		-- void foo(int >>,<< long >>)<<
		self:IsTokenValue(",") or
		self:IsTokenValue(")") or
		-- long foo>>;<<
		self:IsTokenValue(";") or
		-- struct and union bit fields
		self:IsTokenValue(":") or
		self:IsTokenValue("=")
end

function META:ParseAttributes(node)
	local out = {}

	-- long long __attribute__((stdcall)) 
	for i = 1, self:GetLength() do
		if self:IsEndOfTypeQualifiersAndSpecifiers() then break end

		-- declaration specifier: extern or static
		-- type specifier: 		  void, char int, short, struct, union, etc
		-- type qualifier:		  const, volatile
		if self:IsTokenValue("__attribute__") or self:IsTokenValue("__attribute") then
			table.insert(out, self:ParseAttributeExtension())
		elseif self:IsTokenValue("struct") then
			table.insert(out, self:ParseStruct())
		elseif self:IsTokenValue("union") then
			table.insert(out, self:ParseUnion())
		elseif self:IsTokenValue("enum") then
			table.insert(out, self:ParseEnum())
		else
			-- type specifier, typedef name or storage class specifier
			table.insert(out, self:ExpectTokenType("letter"))
		end
	end

	-- TODO, completely neglecting the name of the declaration, may be consumed by modifiers
	return out
end

function META:ParseCTypeDeclaration(node)
	-- variable declaration
	node.pointers = self:ParsePointers()

	if node.pointers[1] then node.expression = self:ParseCDeclaration() end

	node.array_expression = self:ParseArrayIndex()
end

function META:HasOpeningParenthesis()
	if not self:IsTokenValue("(") then return false end

	for i = 1, self:GetLength() do
		if self:IsTokenValue(";", i) then return false end

		if self:IsTokenValue(")", i) and self:IsTokenValue("(", i + 1) then
			return true
		end
	end

	return false
end

function META:ParseCFunctionDeclaration(node)
	if
		self:IsTokenValue("*", 1) or
		(
			self:IsTokenType("letter", 1) and
			self:IsTokenValue("*", 2) and
			-- TODO:
			-- void foo(char *>>,<< short *)
			not self:IsInArguments()
		)
		or
		(
			(
				self:IsTokenValue("__attribute__", 1) or
				self:IsTokenValue("__attribute", 1)
			) and
			self:HasOpeningParenthesis()
		)
	then
		node.tokens["("] = self:ExpectTokenValue("(")
		-- void (>>**foo<<()) or void (>>**foo<<)()
		node.pointers = self:ParsePointers()

		-- void (* volatile * volatile >>foo<<())
		if self:IsTokenType("letter") then
			-- TODO, completely neglecting the name of the declaration
			node.tokens["identifier"] = self:ExpectTokenType("letter")
		end

		-- void (*foo>>()<<)()
		-- TODO: this is just a nested function..
		if self:IsTokenValue("(") then
			--node.tokens["inner_("] = self:ExpectTokenValue("(")
			--node.inner_arguments = self:ParseFunctionArguments()
			--node.tokens["inner_)"] = self:ExpectTokenValue(")")
			node.expression = self:ParseCDeclaration()
		end

		node.array_expression = self:ParseArrayIndex()
		-- void (*foo()>>)<<
		node.tokens[")"] = self:ExpectTokenValue(")")
	else
		if
			self:IsTokenValue("(") and
			self:IsTokenType("letter", 1) and
			self:IsTokenValue(")", 2) and
			-- make sure it's not void foo(int);
			not self:IsTokenValue(";", 3)
		then
			-- void >>(foo)<<()
			node.tokens["identifier_("] = self:ExpectTokenValue("(")
			-- TODO, completely neglecting the name of the declaration
			node.tokens["identifier"] = self:ExpectTokenType("letter")
			node.tokens["identifier_)"] = self:ExpectTokenValue(")")
		end
	end

	if self:IsTokenValue("(") then
		node.tokens["arguments_("] = self:ExpectTokenValue("(")
		node.arguments = self:ParseFunctionArguments()
		node.tokens["arguments_)"] = self:ExpectTokenValue(")")
	end

	self:ParseAsmCall(node)
end

function META:ParseAsmCall(node)
	if self:IsTokenValue("asm") then
		node.tokens["asm"] = self:ExpectTokenValue("asm")
		node.tokens["asm_("] = self:ExpectTokenValue("(")
		node.tokens["asm_string"] = self:ExpectTokenType("string")
		node.tokens["asm_)"] = self:ExpectTokenValue(")")
	end
end

function META:ParseTypeDef()
	if not self:IsTokenValue("typedef") then return end

	local node = self:StartNode("expression", "typedef")
	node.tokens["typedef"] = self:ExpectTokenValue("typedef")
	local decls = {}

	for i = 1, self:GetLength() do
		if self:IsTokenValue(";") then break end

		local typ = self:ParseCDeclaration()
		table.insert(decls, typ)

		if self:IsTokenValue(",") then
			typ.tokens[","] = self:ExpectTokenValue(",")
		end

		node.decls = decls
	end

	node.tokens["potential_identifier"] = node.decls[1].tokens["potential_identifier"]
	return self:EndNode(node)
end

function META:ParseEnum()
	local node = self:StartNode("expression", "enum")
	node.tokens["enum"] = self:ExpectTokenValue("enum")

	if self:IsTokenType("letter") then
		node.tokens["identifier"] = self:ExpectTokenType("letter")
	end

	if not self:IsTokenValue("{") then -- forward declaration
		return self:EndNode(node)
	end

	node.tokens["{"] = self:ExpectTokenValue("{")
	node.fields = {}

	for i = 1, self:GetLength() do
		if self:IsTokenValue("}") then break end

		local field = self:StartNode("expression", "enum_field")
		field.tokens["identifier"] = self:ExpectTokenType("letter")

		if self:IsTokenValue("=") then
			field.tokens["="] = self:ExpectTokenValue("=")
			field.expression = self:ParseRuntimeExpression()
		end

		table.insert(node.fields, self:EndNode(field))

		if self:IsTokenValue(",") then
			field.tokens[","] = self:ExpectTokenValue(",")
		end
	end

	node.tokens["}"] = self:ExpectTokenValue("}")
	return self:EndNode(node)
end

for _, type in ipairs({"Struct", "Union"}) do
	local Type = type
	local type = type:lower()
	-- META:ParseStruct, META:ParseUnion
	META["Parse" .. Type] = function(self)
		local node = self:StartNode("expression", type)
		node.tokens[type] = self:ExpectTokenValue(type)

		if self:IsTokenType("letter") then
			node.tokens["identifier"] = self:ExpectTokenType("letter")
		end

		if not self:IsTokenValue("{") then -- forward declaration
			return self:EndNode(node)
		end

		node.tokens["{"] = self:ExpectTokenValue("{")
		local fields = {}

		for i = 1, self:GetLength() do
			if self:IsTokenValue("}") then break end

			local CDeclaration = self:ParseStructField()

			if self:IsTokenValue(",") then
				CDeclaration.tokens["first_comma"] = self:ConsumeToken()
				CDeclaration.multi_values = {}

				for i = 1, self:GetLength() do
					local t = self:ParseStructField()

					if not self:IsTokenValue(";") then
						t.tokens[","] = self:ExpectTokenValue(",")
					end

					table.insert(CDeclaration.multi_values, t)

					if self:IsTokenValue(";") then break end
				end
			end

			table.insert(fields, CDeclaration)

			if self:IsTokenValue(";") then
				CDeclaration.tokens[";"] = self:ExpectTokenValue(";")
			end
		end

		node.fields = fields
		node.tokens["}"] = self:ExpectTokenValue("}")
		return self:EndNode(node)
	end
end

function META:ParseArrayIndex()
	local out = {}

	for i = 1, self:GetLength() do
		if self:IsTokenValue("[") then
			local node = self:StartNode("expression", "array")
			node.tokens["["] = self:ExpectTokenValue("[")
			node.expression = self:ParseRuntimeExpression()
			node.tokens["]"] = self:ExpectTokenValue("]")
			table.insert(out, self:EndNode(node))
		else
			break
		end
	end

	return out
end

function META:ParsePointers()
	local out = {}

	for i = 1, self:GetLength() do
		if (self:IsTokenValue("__attribute__") or self:IsTokenValue("__attribute")) then
			-- void (>>__attribute__((stdcall))*<<foo)()
			local t = {self:ParseAttributeExtension()}

			if self:IsTokenValue("*") then
				t[2] = self:ExpectTokenValue("*") -- TODO: __ptr32?
			end

			table.insert(out, t)
		elseif self:IsTokenValue("*") then
			-- void (>>*volatile<< foo())
			local ptr = self:ConsumeToken()
			local t = {ptr}

			if self:IsTokenType("letter") then
				t[2] = self:ExpectTokenType("letter")
			end

			table.insert(out, t)
		elseif self:IsTokenType("letter") and self:IsTokenValue("*", 1) then
			-- void void (>>__ptr32*<<*foo())
			local type = self:ExpectTokenType("letter")
			local ptr = self:ConsumeToken()
			table.insert(out, {type, ptr})
		else
			break
		end
	end

	return out
end

function META:ParseAttributeExtension()
	local node = self:StartNode("expression", "attribute_expression")
	node.tokens["__attribute__"] = self:ExpectTokenType("letter")
	node.tokens["("] = self:ExpectTokenValue("(")
	node.expression = self:ParseRuntimeExpression()
	node.tokens[")"] = self:ExpectTokenValue(")")
	return self:EndNode(node)
end

function META:ParseFunctionArguments()
	local out = {}

	for i = 1, self:GetLength() do
		if self:IsTokenValue(")") then break end

		local arg = self:ParseCDeclaration()
		table.insert(out, arg)

		if self:IsTokenValue(",") then arg.tokens[","] = self:ConsumeToken() end
	end

	return out
end

return META