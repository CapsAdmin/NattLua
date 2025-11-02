local META = require("nattlua.parser.base")()
require("nattlua.parser.expressions")(META)

function META:ParseLSXExpression()
	return nil
end

local table = _G.table
local ipairs = _G.ipairs
local old_new = META.New

function META.New(tokens, code)
	local keywords = {
		["struct"] = true,
		["typeof"] = true,
		["double"] = true,
		["float"] = true,
		["int8_t"] = true,
		["uint8_t"] = true,
		["int16_t"] = true,
		["uint16_t"] = true,
		["int32_t"] = true,
		["uint32_t"] = true,
		["char"] = true,
		["signed"] = true,
		["unsigned"] = true,
		["short"] = true,
		["int"] = true,
		["long"] = true,
		["float"] = true,
		["double"] = true,
		["size_t"] = true,
		["intptr_t"] = true,
		["uintptr_t"] = true,
		["uint64_t"] = true,
		["int64_t"] = true,
		["void"] = true,
		["const"] = true,
		["typedef"] = true,
		["union"] = true,
	}

	for _, token in ipairs(tokens) do
		if keywords[token:GetValueString()] then token.c_keyword = true end
	end

	local self = old_new(tokens, code)
	self.FFI_DECLARATION_PARSER = true
	return self
end

function META:ParseRootNode()
	local node = self:StartNode("statement_root")
	node.statements = self:ParseStatementsUntilCondition()
	local eof = self:StartNode("statement_end_of_file")
	eof.tokens["end_of_file"] = self:ExpectTokenType("end_of_file")
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

	self.statement_count = (self.statement_count or 0) + 1

	if self.statement_count <= 1 and self:IsTokenType("end_of_file") then
		-- it's allowed to have 1 statement without ;
		return node
	end

	-- multi declaration
	-- int foo, *bar;
	if not self:IsToken(";") then
		local decls = {}

		for i = 1, self:GetLength() do
			if self:IsToken(";") then break end

			local typ = self:ParseDeclarationStatement()
			table.insert(decls, typ)

			if self:IsToken(",") then typ.tokens[","] = self:ExpectTokenValue(",") end

			node.decls = decls
		end
	end

	node.tokens[";"] = self:ExpectTokenValue(";")
	return node
end

-- TODO: remove the need for this
function META:IsInArguments()
	if self:IsToken("(") then
		for i = 1, self:GetLength() do
			-- what happens if we have a function pointer in the arguments?
			-- void foo(void (*)(int, int))
			-- I guess it still works as a hacky solution
			if self:IsTokenOffset(",", i) then return true end

			if self:IsTokenOffset("(", i) and self:IsTokenOffset(")", i + 1) then
				return false
			end

			if
				self:IsTokenOffset(")", i) and
				(
					self:IsTokenOffset(";", i + 1) or
					self:IsTokenTypeOffset("end_of_file", i + 1)
				)
				and
				not self:IsTokenOffset(")", i - 1)
			then
				return true
			end
		end
	end

	return false
end

function META:ParseCDeclaration()
	local node = self:StartNode("expression_c_declaration")

	if self:IsToken("...") then
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
	if self:IsToken("(") then
		self:ParseCFunctionDeclaration(node)
	else
		self:ParseCTypeDeclaration(node)
	end

	node.tokens["potential_identifier"] = self:FindPotentialIdentifier(node)
	return self:EndNode(node)
end

function META:ParseDeclarationStatement()
	local node = self:ParseCDeclaration()

	if self:IsToken("=") then
		node.tokens["="] = self:ExpectTokenValue("=")
		node.default_expression = self:ParseRuntimeExpression()
	end

	return node
end

function META:ParseStructField()
	local node = self:ParseCDeclaration()

	if self:IsToken(":") then
		node.tokens[":"] = self:ExpectTokenValue(":")
		node.bitfield_expression = self:ParseRuntimeExpression()
	end

	if self:IsToken("=") then
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

				if last_modifier and last_modifier.is_token and last_modifier.type == "letter" then
					return node.modifiers[#node.modifiers]
				else
					for _, modifier in ipairs(node.modifiers) do
						if
							modifier.Type == "expression_struct" or
							modifier.Type == "expression_union" or
							modifier.Type == "expression_enum"
						then
							return modifier.tokens["identifier"]
						end
					end
				end
			end
		end
	end
end

function META:IsEndOfTypeQualifiersAndSpecifiers()
	return self:GetToken().type == "symbol" and
		(
			self:IsToken("(") or
			self:IsToken("*") or
			self:IsToken("[") or
			-- void foo(int >>,<< long >>)<<
			self:IsToken(",") or
			self:IsToken(")") or
			-- long foo>>;<<
			self:IsToken(";") or
			-- struct and union bit fields
			self:IsToken(":") or
			self:IsToken("=")
		)
end

function META:ParseAttributes(node)
	local out = {}

	-- long long __attribute__((stdcall)) 
	for i = 1, self:GetLength() do
		if self:IsEndOfTypeQualifiersAndSpecifiers() then break end

		-- declaration specifier: extern or static
		-- type specifier: 		  void, char int, short, struct, union, etc
		-- type qualifier:		  const, volatile
		if self:IsTokenValue("$") then
			table.insert(out, self:ParseDollarSign())
		elseif self:IsTokenValue("__attribute__") or self:IsTokenValue("__attribute") then
			table.insert(out, self:ParseAttributeExtension())
		elseif self:IsTokenValue("struct") then
			table.insert(out, self:ParseStruct())
		elseif self:IsTokenValue("union") then
			table.insert(out, self:ParseUnion())
		elseif self:IsTokenValue("enum") then
			table.insert(out, self:ParseEnum())
		elseif self:IsTokenType("end_of_file") then
			break
		else
			-- type specifier, typedef name or storage class specifier
			table.insert(out, self:ExpectTokenType("letter"))
		end
	end

	-- TODO, completely neglecting the name of the declaration, may be consumed by modifiers
	return out
end

function META:ParseDollarSign()
	local node = self:StartNode("expression_dollar_sign")

	if self:IsTokenValue("?") then
		node.tokens["$"] = self:ExpectTokenValue("?")
	else
		node.tokens["$"] = self:ExpectTokenValue("$")
	end

	node = self:EndNode(node)
	self.dollar_signs = self.dollar_signs or {}
	table.insert(self.dollar_signs, node)
	return node
end

function META:ParseCTypeDeclaration(node)
	-- variable declaration
	node.pointers = self:ParsePointers()

	if node.pointers[1] then node.expression = self:ParseCDeclaration() end

	node.array_expression = self:ParseArrayIndex()
end

function META:HasOpeningParenthesis()
	if not self:IsToken("(") then return false end

	for i = 1, self:GetLength() do
		if self:IsTokenOffset(";", i) then return false end

		if self:IsTokenOffset(")", i) and self:IsTokenOffset("(", i + 1) then
			return true
		end
	end

	return false
end

function META:ParseCFunctionDeclaration(node)
	if
		self:IsTokenOffset("*", 1) or
		(
			self:IsTokenTypeOffset("letter", 1) and
			self:IsTokenOffset("*", 2) and
			-- TODO:
			-- void foo(char *>>,<< short *)
			not self:IsInArguments()
		)
		or
		(
			(
				self:IsTokenValueOffset("__attribute__", 1) or
				self:IsTokenValueOffset("__attribute", 1)
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
		if self:IsToken("(") then
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
			self:IsToken("(") and
			self:IsTokenTypeOffset("letter", 1) and
			self:IsTokenOffset(")", 2) and
			-- make sure it's not void foo(int);
			not self:IsTokenOffset(";", 3)
		then
			-- void >>(foo)<<()
			node.tokens["identifier_("] = self:ExpectTokenValue("(")
			-- TODO, completely neglecting the name of the declaration
			node.tokens["identifier"] = self:ExpectTokenType("letter")
			node.tokens["identifier_)"] = self:ExpectTokenValue(")")
		end
	end

	if self:IsToken("(") then
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

	local node = self:StartNode("expression_typedef")
	node.tokens["typedef"] = self:ExpectTokenValue("typedef")
	local decls = {}

	for i = 1, self:GetLength() do
		if self:IsToken(";") then break end

		local typ = self:ParseCDeclaration()
		table.insert(decls, typ)

		if self:IsToken(",") then typ.tokens[","] = self:ExpectTokenValue(",") end

		node.decls = decls
	end

	node.tokens["potential_identifier"] = node.decls[1].tokens["potential_identifier"]
	return self:EndNode(node)
end

function META:ParseEnum()
	local node = self:StartNode("expression_enum")
	node.tokens["enum"] = self:ExpectTokenValue("enum")

	if self:IsTokenType("letter") then
		node.tokens["identifier"] = self:ExpectTokenType("letter")
	end

	if not self:IsToken("{") then -- forward declaration
		return self:EndNode(node)
	end

	node.tokens["{"] = self:ExpectTokenValue("{")
	node.fields = {}

	for i = 1, self:GetLength() do
		if self:IsToken("}") then break end

		local field = self:StartNode("expression_enum_field")
		field.tokens["identifier"] = self:ExpectTokenType("letter")

		if self:IsToken("=") then
			field.tokens["="] = self:ExpectTokenValue("=")
			field.expression = self:ParseRuntimeExpression()
		end

		table.insert(node.fields, self:EndNode(field))

		if self:IsToken(",") then field.tokens[","] = self:ExpectTokenValue(",") end
	end

	node.tokens["}"] = self:ExpectTokenValue("}")
	return self:EndNode(node)
end

for _, type in ipairs({"Struct", "Union"}) do
	local Type = type
	local type = type:lower()
	-- META:ParseStruct, META:ParseUnion
	META["Parse" .. Type] = function(self)
		local node = self:StartNode("expression_" .. type)
		node.tokens[type] = self:ExpectTokenValue(type)

		if self:IsTokenType("letter") then
			node.tokens["identifier"] = self:ExpectTokenType("letter")
		end

		if not self:IsToken("{") then -- forward declaration
			return self:EndNode(node)
		end

		node.tokens["{"] = self:ExpectTokenValue("{")
		local fields = {}

		for i = 1, self:GetLength() do
			if self:IsToken("}") then break end

			local CDeclaration = self:ParseStructField()

			if self:IsToken(",") then
				CDeclaration.tokens["first_comma"] = self:ConsumeToken()
				CDeclaration.multi_values = {}

				for i = 1, self:GetLength() do
					local t = self:ParseStructField()

					if not self:IsToken(";") then
						t.tokens[","] = self:ExpectTokenValue(",")
					end

					table.insert(CDeclaration.multi_values, t)

					if self:IsToken(";") then break end
				end
			end

			table.insert(fields, CDeclaration)

			if self:IsToken(";") then
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
		if self:IsToken("[") then
			local node = self:StartNode("expression_array")
			node.tokens["["] = self:ExpectTokenValue("[")

			if self:IsTokenValue("?") then
				node.expression = self:ParseDollarSign()
			else
				node.expression = self:ParseRuntimeExpression()
			end

			node.tokens["]"] = self:ExpectTokenValue("]")
			table.insert(out, self:EndNode(node))
		else
			break
		end
	end

	if not out[1] then return false end

	return out
end

function META:ParsePointers()
	local out = {}

	for i = 1, self:GetLength() do
		if (self:IsTokenValue("__attribute__") or self:IsTokenValue("__attribute")) then
			-- void (>>__attribute__((stdcall))*<<foo)()
			local t = {self:ParseAttributeExtension()}

			if self:IsToken("*") then
				t[2] = self:ExpectTokenValue("*") -- TODO: __ptr32?
			end

			table.insert(out, t)
		elseif self:IsToken("*") then
			-- void (>>*volatile<< foo())
			local ptr = self:ConsumeToken()
			local t = {ptr}

			if self:IsTokenType("letter") then
				t[2] = self:ExpectTokenType("letter")
			end

			table.insert(out, t)
		elseif self:IsTokenType("letter") and self:IsTokenOffset("*", 1) then
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
	local node = self:StartNode("expression_attribute_expression")
	node.tokens["__attribute__"] = self:ExpectTokenType("letter")
	node.tokens["("] = self:ExpectTokenValue("(")
	node.expression = self:ParseRuntimeExpression()
	node.tokens[")"] = self:ExpectTokenValue(")")
	return self:EndNode(node)
end

function META:ParseFunctionArguments()
	local out = {}

	for i = 1, self:GetLength() do
		if self:IsToken(")") then break end

		local arg = self:ParseCDeclaration()
		table.insert(out, arg)

		if self:IsToken(",") then arg.tokens[","] = self:ConsumeToken() end
	end

	return out
end

return META
