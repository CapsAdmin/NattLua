local META = loadfile("nattlua/transpiler/emitter.lua")()

function META:BuildCode(block)
	self:EmitStatements(block.statements)
	return self:Concat()
end

function META:EmitStatement(node)
	if node.kind == "typedef" then
		self:EmitTypeDef(node)
	elseif node.kind == "union" then
		self:EmitUnion(node)
	elseif node.kind == "enum" then
		self:EmitEnum(node)
	elseif node.kind == "struct" then
		self:EmitStruct(node)
	elseif node.kind == "end_of_file" then
		self:EmitToken(node.tokens["end_of_file"])
	elseif node.kind == "function_declaration" then
		self:EmitFunctionDeclarationStatement(node)
	end

	if node.tokens[";"] then self:EmitToken(node.tokens[";"]) end
end

function META:EmitFunctionDeclarationStatement(node)
	self:EmitTypeExpression(node.return_type)

	if node.tokens["(2"] then self:EmitToken(node.tokens["(2"]) end

	self:EmitToken(node.tokens["identifier"])

	if node.tokens[")2"] then self:EmitToken(node.tokens[")2"]) end

	self:EmitToken(node.tokens["("])

	for i, arg in ipairs(node.arguments) do
		self:EmitTypeExpression(arg)

		if arg.tokens[","] then self:EmitToken(arg.tokens[","]) end
	end

	self:EmitToken(node.tokens[")"])

	if node.tokens["asm"] then
		self:EmitToken(node.tokens["asm"])
		self:EmitToken(node.tokens["asm_("])
		self:EmitToken(node.tokens["asm_string"])
		self:EmitToken(node.tokens["asm_)"])
	end
end

function META:EmitTypeDef(node)
	self:EmitToken(node.tokens["typedef"])

	if node.value then
		if node.value.type == "statement" then
			self:EmitStatement(node.value)
		else
			self:EmitTypeExpression(node.value)
		end
	end

	if node.tokens["identifier"] then
		self:EmitToken(node.tokens["identifier"])
	end
end

function META:EmitEnum(node)
	self:EmitToken(node.tokens["enum"])

	if node.tokens["identifier"] then
		self:EmitToken(node.tokens["identifier"])
	end

	self:EmitToken(node.tokens["{"])

	for _, field in ipairs(node.fields) do
		if field.tokens["identifier"] then
			self:EmitToken(field.tokens["identifier"])
		end

		if field.tokens["="] then
			self:EmitToken(field.tokens["="])
			self:EmitExpression(field.value)
		end

		if field.tokens[","] then self:EmitToken(field.tokens[","]) end
	end

	self:EmitToken(node.tokens["}"])
end

function META:EmitStruct(node)
	return self:EmitStructOrUnion(node, "struct")
end

function META:EmitUnion(node)
	return self:EmitStructOrUnion(node, "union")
end

function META:EmitStructOrUnion(node, type)
	self:EmitToken(node.tokens[type])

	if node.tokens["identifier"] then
		self:EmitToken(node.tokens["identifier"])
	end

	-- forward declaration
	if not node.tokens["{"] then return end

	self:EmitToken(node.tokens["{"])

	for _, field in ipairs(node.fields) do
		if field.shorthand_identifiers then
			self:EmitTypeExpression(field.type_declaration)

			if field.tokens[":"] then self:EmitToken(field.tokens[":"]) end

			if field.bit_field then self:EmitToken(field.bit_field) end

			for _, identifier in ipairs(field.shorthand_identifiers) do
				if identifier.token then self:EmitToken(identifier.token) end

				if identifier[":"] then self:EmitToken(identifier[":"]) end

				if identifier.bit_field then self:EmitToken(identifier.bit_field) end

				if identifier[","] then self:EmitToken(identifier[","]) end
			end

			self:EmitToken(field.tokens[";"])
		else
			if field.kind == "struct_field" then
				self:EmitTypeExpression(field.type_declaration)

				if field.tokens[":"] then self:EmitToken(field.tokens[":"]) end

				if field.bit_field then self:EmitToken(field.bit_field) end

				if field.tokens["="] then
					self:EmitToken(field.tokens["="])
					self:EmitExpression(field.value)
				end
			elseif field.kind == "struct" then
				if field.tokens["const"] then self:EmitToken(field.tokens["const"]) end

				self:EmitStruct(field)

				if field.tokens["identifier2"] then
					self:EmitToken(field.tokens["identifier2"])
				end
			elseif field.kind == "union" then
				if field.tokens["const"] then self:EmitToken(field.tokens["const"]) end

				self:EmitUnion(field)

				if field.tokens["identifier2"] then
					self:EmitToken(field.tokens["identifier2"])
				end
			elseif field.kind == "enum" then
				if field.tokens["const"] then self:EmitToken(field.tokens["const"]) end

				self:EmitEnum(field)

				if field.tokens["identifier2"] then
					self:EmitToken(field.tokens["identifier2"])
				end
			end

			self:EmitToken(field.tokens[";"])
		end
	end

	self:EmitToken(node.tokens["}"])
end

function META:EmitTypeDeclaration(node)
	if node.tokens["type"] then self:EmitToken(node.tokens["type"]) end
end

function META:EmitAttributeExpression(node)
	self:EmitToken(node.tokens["__attribute__"])
	self:EmitToken(node.tokens["("])
	self:EmitExpression(node.expression)
	self:EmitToken(node.tokens[")"])
end

function META:EmitTypeExpression(node)
	if node.kind == "vararg" then
		self:EmitToken(node.tokens["..."])
	elseif node.kind == "type_declaration" then
		if node.modifiers then
			for _, modifier in ipairs(node.modifiers) do
				if modifier.kind == "attribute_expression" then
					self:EmitAttributeExpression(modifier)
				elseif modifier.kind == "struct" then
					self:EmitStruct(modifier)
				elseif modifier.kind == "union" then
					self:EmitUnion(modifier)
				elseif modifier.kind == "enum" then
					self:EmitEnum(modifier)
				else
					self:EmitToken(modifier)
				end
			end
		end

		if node.expression then self:EmitTypeExpression(node.expression) end
	elseif node.kind == "type_expression" then
		if node.modifiers then
			for _, modifier in ipairs(node.modifiers) do
				if modifier.kind == "attribute_expression" then
					self:EmitAttributeExpression(modifier)
				else
					self:EmitToken(modifier)
				end
			end
		end

		if node.expression then self:EmitTypeExpression(node.expression) end
	elseif node.kind == "function_expression" then
		self:EmitToken(node.tokens["("])
		self:EmitTypeExpression(node.expression)
		self:EmitToken(node.tokens[")"])

		if node.arguments then
			self:EmitToken(node.tokens["arguments_("])

			for i, argument in ipairs(node.arguments) do
				self:EmitTypeExpression(argument)

				if argument.tokens[","] then self:EmitToken(argument.tokens[","]) end
			end

			self:EmitToken(node.tokens["arguments_)"])
		end
	elseif node.kind == "pointer_expression" then
		self:EmitToken(node.tokens["*"])

		if node.tokens["__ptr32"] then self:EmitToken(node.tokens["__ptr32"]) end

		if node.tokens["__ptr64"] then self:EmitToken(node.tokens["__ptr64"]) end

		if node.tokens["identifier"] then
			self:EmitToken(node.tokens["identifier"])
		end

		self:EmitTypeExpression(node.expression)
	elseif node.kind == "paren_expression" then
		self:EmitToken(node.tokens["("])
		self:EmitTypeExpression(node.expression)
		self:EmitToken(node.tokens[")"])
	elseif node.kind == "array_expression" then
		if node.left_expression then self:EmitTypeExpression(node.left_expression) end

		self:EmitToken(node.tokens["["])

		if node.size_expression then self:EmitExpression(node.size_expression) end

		self:EmitToken(node.tokens["]"])

		if node.expression then self:EmitTypeExpression(node.expression) end
	end
end

return META