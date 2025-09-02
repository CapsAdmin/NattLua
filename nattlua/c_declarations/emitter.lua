local ipairs = _G.ipairs
local META = require("nattlua.emitter.base")()
local old_new = META.New

function META.New(...)
	local self = old_new(...)
	self.FFI_DECLARATION_EMITTER = true
	self.skip_emit = {}
	return self
end

do
	local function hmmm(node, walk_up, out)
		-- arrays have precedence over pointers
		if node.array_expression then
			for k, v in ipairs(node.array_expression) do
				table.insert(out, {type = "array", size = v.expression:Render()})
			end
		end

		-- after that read pointers
		if node.pointers then
			for k, v in ipairs(node.pointers) do
				local modifiers = {}

				for i = #v, 1, -1 do
					local v = v[i]

					if v.value ~= "*" then table.insert(modifiers, v.value) end
				end

				table.insert(out, {type = "pointer", modifiers = modifiers})
			end
		end

		if node.arguments then
			local args = {}

			for i, v in ipairs(node.arguments) do
				hmmm(v, nil, args)
			end

			table.insert(out, {type = "function", args = args})

			if node.parent.Type == "expression_c_declaration" then
				hmmm(node.parent, true, out)
				return
			end
		end

		if node.modifiers then
			local modifiers = {}

			for k, v in ipairs(node.modifiers) do
				if not self.skip_emit[v.value] then table.insert(modifiers, v.value) end
			end

			if modifiers[1] then
				table.insert(out, {type = "modifier", value = modifiers})
			end
		end

		if not walk_up then return end

		if node.parent.Type == "expression_c_declaration" then
			hmmm(node.parent, true, out)
		end
	end

	function META:EmitNattluaCDeclaration(node)
		self.skip_emit[node.tokens["potential_identifier"]] = true

		while node.expression do -- find the inner most expression
			node = node.expression
		end

		local out = {}
		hmmm(node, true, out)

		local function dump(out, str)
			local opened = 0
			local paren_close = {}

			for i, v in ipairs(out) do
				if v.type == "array" then
					table.insert(str, "FFIArray<|" .. (v.size or "inf") .. ",")
					opened = opened + 1
				end

				if v.type == "pointer" then
					table.insert(str, "FFIPointer<|")
					opened = opened + 1
				end

				if v.type == "modifier" then
					table.insert(str, "FFIType<|\"" .. table.concat(v.value, " ") .. "\"|>")
				end

				if v.type == "function" then
					table.insert(str, "function=((")
					dump(v.args, str)
					table.insert(str, "|>,))>(")
					opened = opened + 1
					table.insert(paren_close, opened)
				end
			end

			for i = 1, opened - 1 do
				for _, v in ipairs(paren_close) do
					if v == i then table.insert(str, ")") end
				end

				table.insert(str, "|>")
			end
		end

		local str = {}
		dump(out, str)
		self:Emit(table.concat(str))
	end
end

function META:BuildCode(block)
	self:EmitStatements(block.statements)
	return self:Concat()
end

function META:EmitStatement(node)
	if node.Type == "expression_typedef" then
		self:EmitTypeDef(node)
	elseif node.Type == "expression_c_declaration" then
		self:EmitCDeclaration(node)
	end

	if node.tokens[";"] then self:EmitToken(node.tokens[";"]) end

	if node.Type == "statement_end_of_file" then
		self:EmitToken(node.tokens["end_of_file"])
	end
end

function META:EmitTypeDef(node)
	self:EmitToken(node.tokens["typedef"])

	for _, v in ipairs(node.decls) do
		self:EmitCDeclaration(v)

		if v.tokens[","] then self:EmitToken(v.tokens[","]) end
	end
end

function META:EmitCDeclaration(node)
	if node.tokens["..."] then
		self:EmitToken(node.tokens["..."])
		return
	end

	if node.strings then
		for _, v in ipairs(node.strings) do
			self:EmitToken(v)
		end

		return
	end

	for i, v in ipairs(node.modifiers) do
		if v.Type == "expression_attribute_expression" then
			self:EmitAttributeExpression(v)
		elseif v.Type == "expression_struct" then
			self:EmitStruct(v)
		elseif v.Type == "expression_union" then
			self:EmitUnion(v)
		elseif v.Type == "expression_dollar_sign" then
			self:EmitDollarSign(v)
		elseif v.Type == "expression_enum" then
			self:EmitEnum(v)
		else
			self:EmitToken(v)
		end
	end

	if node.tokens["("] then self:EmitToken(node.tokens["("]) end

	if node.tokens["identifier_("] then
		self:EmitToken(node.tokens["identifier_("])
	end

	if node.pointers then self:EmitPointers(node.pointers) end

	if node.tokens["identifier"] then
		self:EmitToken(node.tokens["identifier"])
	end

	if node.expression then self:EmitCDeclaration(node.expression) end

	if node.array_expression then
		self:EmitArrayExpression(node.array_expression)
	end

	if node.tokens["identifier_)"] then
		self:EmitToken(node.tokens["identifier_)"])
	end

	if node.tokens[")"] then self:EmitToken(node.tokens[")"]) end

	if node.tokens["arguments_("] then
		self:EmitToken(node.tokens["arguments_("])
	end

	if node.arguments then self:EmitArguments(node.arguments) end

	if node.tokens["arguments_)"] then
		self:EmitToken(node.tokens["arguments_)"])
	end

	if node.tokens["asm"] then
		self:EmitToken(node.tokens["asm"])
		self:EmitToken(node.tokens["asm_("])
		self:EmitToken(node.tokens["asm_string"])
		self:EmitToken(node.tokens["asm_)"])
	end

	if node.default_expression then
		self:EmitToken(node.tokens["="])
		self:EmitExpression(node.default_expression)
	end

	if node.decls then
		for _, v in ipairs(node.decls) do
			self:EmitCDeclaration(v)

			if v.tokens[","] then self:EmitToken(v.tokens[","]) end
		end
	end
end

function META:EmitDollarSign(node)
	self:EmitToken(node.tokens["$"])
end

function META:EmitArguments(args)
	for i, v in ipairs(args) do
		self:EmitCDeclaration(v)

		if v.tokens[","] then self:EmitToken(v.tokens[","]) end
	end
end

function META:EmitPointers(pointers)
	for i, v in ipairs(pointers) do
		local a, b = v[1], v[2]

		if a.Type == "expression_attribute_expression" then
			self:EmitAttributeExpression(a)
		else
			self:EmitToken(a)
		end

		if b then self:EmitToken(b) end
	end
end

function META:EmitArrayExpression(expressions)
	for _, node in ipairs(expressions) do
		self:EmitToken(node.tokens["["])

		if node.expression then self:EmitExpression(node.expression) end

		self:EmitToken(node.tokens["]"])
	end
end

function META:EmitAttributeExpression(node)
	self:EmitToken(node.tokens["__attribute__"])
	self:EmitToken(node.tokens["("])
	self:EmitExpression(node.expression)
	self:EmitToken(node.tokens[")"])
end

function META:EmitStructField(node)
	self:EmitCDeclaration(node)

	if node.tokens[":"] then
		self:EmitToken(node.tokens[":"])
		self:EmitExpression(node.bitfield_expression)
	end
end

for _, type in ipairs({"Struct", "Union"}) do
	local Type = type
	local type = type:lower()
	-- EmitStruct, EmitUnion
	META["Emit" .. Type] = function(self, node)
		self:EmitToken(node.tokens[type])

		if node.tokens["identifier"] then
			self:EmitToken(node.tokens["identifier"])
		end

		if node.tokens["{"] then
			self:EmitToken(node.tokens["{"])

			for _, field in ipairs(node.fields) do
				self:EmitStructField(field)

				if field.tokens["first_comma"] then
					self:EmitToken(field.tokens["first_comma"])

					for _, v in ipairs(field.multi_values) do
						self:EmitStructField(v)

						if v.tokens[","] then self:EmitToken(v.tokens[","]) end
					end
				end

				if field.tokens[";"] then self:EmitToken(field.tokens[";"]) end
			end

			self:EmitToken(node.tokens["}"])
		end
	end
end

function META:EmitEnum(node)
	self:EmitToken(node.tokens["enum"])

	if node.tokens["identifier"] then
		self:EmitToken(node.tokens["identifier"])
	end

	if node.tokens["{"] then
		self:EmitToken(node.tokens["{"])

		for _, v in ipairs(node.fields) do
			self:EmitToken(v.tokens["identifier"])

			if v.tokens["="] then
				self:EmitToken(v.tokens["="])
				self:EmitExpression(v.expression)
			end

			if v.tokens[","] then self:EmitToken(v.tokens[","]) end
		end

		self:EmitToken(node.tokens["}"])
	end
end

return META
