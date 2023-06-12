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

	local node = self:ParseTypeDef() or self:ParseCType()

	if not node then
		self:Error("expected statement")
		return
	end

	if not self:IsTokenValue(";") then
		local decls = {}

		for i = 1, self:GetLength() do
			if self:IsTokenValue(";") then break end

			local typ = self:ParseCType()
			table.insert(decls, typ)

			if self:IsTokenValue(",") then
				typ.tokens[","] = self:ExpectTokenValue(",")
			end
		end
	end

	node.tokens[";"] = self:ExpectTokenValue(";")
	return node
end

function META:ParsePlainFunction()
	local node = self:StartNode("statement", "plain_function")
	node.return_type = self:ParseCType()
	return self:EndNode(node)
end

function META:ConsumeToken()
	local tk = self:GetToken()
	self:Advance(1)
	return tk
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

function META:ParseCType()
	local node = self:StartNode("expression", "c_type")

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

	local modifiers = {}

	-- long long __attribute__((stdcall)) 
	for i = 1, self:GetLength() do
		if
			self:IsTokenValue("(") or
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
		then
			break
		end

		if self:IsTokenValue("__attribute__") or self:IsTokenValue("__attribute") then
			local attrnode = self:StartNode("expression", "attribute_expression")
			attrnode.tokens["__attribute__"] = self:ExpectTokenType("letter")
			attrnode.tokens["("] = self:ExpectTokenValue("(")
			attrnode.expression = self:ParseRuntimeExpression()
			attrnode.tokens[")"] = self:ExpectTokenValue(")")
			table.insert(modifiers, self:EndNode(attrnode))
		elseif self:IsTokenValue("struct") then
			table.insert(modifiers, self:ParseStruct())

			break
		elseif self:IsTokenValue("union") then
			table.insert(modifiers, self:ParseUnion())

			break
		elseif self:IsTokenValue("enum") then
			table.insert(modifiers, self:ParseEnum())

			break
		else
			table.insert(modifiers, self:ExpectTokenType("letter"))
		end
	end

	-- TODO, completely neglecting the name of the declaration, may be consumed by modifiers
	node.modifiers = modifiers

	-- plain function or function pointer
	-- void >>(foo)<<() or void >>(*foo)<<()
	if self:IsTokenValue("(") then
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
				self:IsTokenValue("__attribute__", 1) or
				self:IsTokenValue("__attribute", 1)
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
				node.expression = self:ParseCType()
			end

			node.array_expression = self:ParseArrays()
			-- void (*foo()>>)<<
			node.tokens[")"] = self:ExpectTokenValue(")")

			if self:IsTokenValue("(") then
				node.tokens["arguments_("] = self:ExpectTokenValue("(")
				node.arguments = self:ParseFunctionArguments()
				node.tokens["arguments_)"] = self:ExpectTokenValue(")")
			end
		else
			if
				self:IsTokenValue("(") and
				self:IsTokenType("letter", 1) and
				self:IsTokenValue(")", 2)
			then
				-- void >>(foo)<<()
				node.tokens["identifier_("] = self:ExpectTokenValue("(")
				-- TODO, completely neglecting the name of the declaration
				node.tokens["identifier"] = self:ExpectTokenType("letter")
				node.tokens["identifier_)"] = self:ExpectTokenValue(")")
			end

			if self:IsTokenValue("(") then
				node.tokens["arguments_("] = self:ExpectTokenValue("(")
				node.arguments = self:ParseFunctionArguments()
				node.tokens["arguments_)"] = self:ExpectTokenValue(")")
			end
		end
	else
		-- variable declaration
		node.pointers = self:ParsePointers()

		if node.pointers[1] then node.expression = self:ParseCType() end
	end

	node.array_expression = self:ParseArrays()

	-- function declaration
	if self:IsTokenValue("asm") then
		node.tokens["asm"] = self:ExpectTokenValue("asm")
		node.tokens["asm_("] = self:ExpectTokenValue("(")
		node.tokens["asm_string"] = self:ExpectTokenType("string")
		node.tokens["asm_)"] = self:ExpectTokenValue(")")
	end

	return self:EndNode(node)
end

function META:ParseTypeDef()
	if not self:IsTokenValue("typedef") then return end

	local node = self:StartNode("expression", "typedef")
	node.tokens["typedef"] = self:ExpectTokenValue("typedef")
	node.from = self:ParseCType()
	node.to = self:ParseCType()
	node.more = {}

	if self:IsTokenValue(",") then
		for i = 1, self:GetLength() do
			if self:IsTokenValue(";") then break end

			local node2 = self:ParseCType()

			if not node2 then break end

			table.insert(node.more, node2)

			if self:IsTokenValue(",") then
				node2.tokens[","] = self:ExpectTokenValue(",")
			end
		end
	end

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

	for i = 1, self:GetLength() do
		if self:IsTokenValue("}") then break end

		local field = self:StartNode("expression", "enum_field")
		field.tokens["identifier"] = self:ExpectTokenType("letter")

		if self:IsTokenValue("=") then
			field.tokens["="] = self:ExpectTokenValue("=")
			field.expression = self:ParseRuntimeExpression()
		end

		table.insert(node, self:EndNode(field))

		if self:IsTokenValue(",") then
			node.tokens[","] = self:ExpectTokenValue(",")
		end
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

		local ctype = self:ParseCType()

		if self:IsTokenValue(":") then
			ctype.tokens[":"] = self:ExpectTokenValue(":")
			ctype.bitfield_expression = self:ParseRuntimeExpression()
		end

		if self:IsTokenValue(",") then
			local lol = {ctype}

			for i = 1, self:GetLength() do
				if self:IsTokenValue("}") then break end

				if self:IsTokenValue(",") then
					table.insert(lol, self:ExpectTokenValue(","))
					table.insert(lol, self:ParseCType())
				else
					break
				end
			end
		else
			table.insert(fields, ctype)
		end

		if self:IsTokenValue("=") then
			ctype.tokens["="] = self:ExpectTokenValue("=")
			ctype.default_expression = self:ParseRuntimeExpression()
		end

		if self:IsTokenValue(";") then
			ctype.tokens[";"] = self:ExpectTokenValue(";")
		end
	end

	node.tokens["}"] = self:ExpectTokenValue("}")
	return self:EndNode(node)
end

function META:ParseArrays()
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
			local attrnode = self:StartNode("expression", "attribute_expression")
			attrnode.tokens["__attribute__"] = self:ExpectTokenType("letter")
			attrnode.tokens["("] = self:ExpectTokenValue("(")
			attrnode.expression = self:ParseRuntimeExpression()
			attrnode.tokens[")"] = self:ExpectTokenValue(")")
			local t = {self:EndNode(attrnode)}

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

function META:ParseFunctionArguments()
	local out = {}

	for i = 1, self:GetLength() do
		if self:IsTokenValue(")") then break end

		local arg = self:ParseCType()
		table.insert(out, arg)

		if self:IsTokenValue(",") then arg.tokens[","] = self:ConsumeToken() end
	end

	return out
end

return META