local META = loadfile("nattlua/transpiler/emitter.lua")()
META.FFI_DECLARATION_EMITTER = true

function META:BuildCode(block)
	self:EmitStatements(block.statements)
	return self:Concat()
end

function META:EmitStatement(node)
	if node.kind == "typedef" then
		self:EmitTypeDef(node)
	elseif node.kind == "c_declaration" then
		self:EmitCType(node)
	end

	if node.tokens[";"] then self:EmitToken(node.tokens[";"]) end

	if node.kind == "end_of_file" then
		self:EmitToken(node.tokens["end_of_file"])
	end
end

function META:EmitTypeDef(node)
	self:EmitToken(node.tokens["typedef"])

	for _, v in ipairs(node.decls) do
		self:EmitCType(v)
		if v.tokens[","] then self:EmitToken(v.tokens[","]) end
	end
end

function META:EmitCType(node)
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
		if v.kind == "attribute_expression" then
			self:EmitAttributeExpression(v)
		elseif v.kind == "struct" then
			self:EmitStruct(v)
		elseif v.kind == "union" then
			self:EmitUnion(v)
		elseif v.kind == "enum" then
			self:EmitEnum(v)
		else
			self:EmitToken(v)
		end
	end

	if node.tokens["("] then
		self:EmitToken(node.tokens["("])
	end

	if node.tokens["identifier_("] then
		self:EmitToken(node.tokens["identifier_("])
	end

	if node.pointers then
		self:EmitPointers(node.pointers)
	end

	if node.tokens["identifier"] then
		self:EmitToken(node.tokens["identifier"])
	end	

	if node.expression then
		self:EmitCType(node.expression)
	end

	if node.array_expression then
		self:EmitArrayExpression(node.array_expression)
	end

	if node.tokens["identifier_)"] then
		self:EmitToken(node.tokens["identifier_)"])
	end

	if node.tokens[")"] then
		self:EmitToken(node.tokens[")"])
	end

	if node.tokens["arguments_("] then
		self:EmitToken(node.tokens["arguments_("])
	end

	if node.arguments then
		self:EmitArguments(node.arguments)
	end

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
			self:EmitCType(v)
			if v.tokens[","] then self:EmitToken(v.tokens[","]) end
		end
	end
end

function META:EmitArguments(args)
	for i, v in ipairs(args) do
		self:EmitCType(v)

		if v.tokens[","] then
			self:EmitToken(v.tokens[","])
		end
	end
end

function META:EmitPointers(pointers)
	for i, v in ipairs(pointers) do
		local a, b = v[1], v[2]

		if a.kind == "attribute_expression" then
			self:EmitAttributeExpression(a)
		else
			self:EmitToken(a)
		end

		if b then
			self:EmitToken(b)
		end
	end
end

function META:EmitArrayExpression(expressions)
	for _, node in ipairs(expressions) do
		self:EmitToken(node.tokens["["])
		if node.expression then
			self:EmitExpression(node.expression)
		end
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
	self:EmitCType(node)

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
		self:EmitToken(node.tokens[type] )

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

						if v.tokens[","] then
							self:EmitToken(v.tokens[","])
						end
					end
				end

				if field.tokens[";"] then
					self:EmitToken(field.tokens[";"])
				end
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

			if v.tokens[","] then
				self:EmitToken(v.tokens[","])
			end
		end

		self:EmitToken(node.tokens["}"])
	end
end

return META