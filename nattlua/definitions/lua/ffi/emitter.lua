--[[HOTRELOAD
	run_lua("/Users/caps/github/NattLua/examples/c_preprocessor.lua")
]]
local ipairs = _G.ipairs
local META = require("nattlua.emitter.base")()
local old_new = META.New

function META.New(...)
	local self = old_new(...)
	self.FFI_DECLARATION_EMITTER = true
	return self
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
	self:Whitespace(" ")

	for _, v in ipairs(node.decls) do
		self:EmitCDeclaration(v)

		if v.tokens[","] then self:EmitToken(v.tokens[","]) end
	end
end

function META:EmitCDeclaration(node)
	if self.config.comment_c_variables and node.default_expression then
		self:Emit("/*")
	end

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

		if i < #node.modifiers then self:Whitespace(" ") end
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
		self:Whitespace(" ")
		self:EmitToken(node.tokens["="])
		self:Whitespace(" ")
		self:EmitExpression(node.default_expression)
	end

	if node.decls then
		for _, v in ipairs(node.decls) do
			self:EmitCDeclaration(v)

			if v.tokens[","] then self:EmitToken(v.tokens[","]) end
		end
	end

	if self.config.comment_c_variables and node.default_expression then
		self:Emit("*/")
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
			self:Whitespace(" ")
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

function META:EmitNumberTokenUNUSED(token--[[#: Token]])
	local num = token:GetValueString()

	if num:sub(-3):lower() == "ull" then
		num = num:sub(1, -4)
	elseif num:sub(-2):lower() == "ll" then
		num = num:sub(1, -3)
	end

	self:EmitToken(token, num)
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
		self:Whitespace(" ")

		if node.tokens["identifier"] then
			self:EmitToken(node.tokens["identifier"])
		end

		self:Whitespace(" ")

		if node.tokens["{"] then
			self:EmitToken(node.tokens["{"])
			self:Indent()
			self:Whitespace("\n")

			for _, field in ipairs(node.fields) do
				self:Whitespace("\t")
				self:EmitStructField(field)

				if field.tokens["first_comma"] then
					self:EmitToken(field.tokens["first_comma"])

					for _, v in ipairs(field.multi_values) do
						self:EmitStructField(v)

						if v.tokens[","] then self:EmitToken(v.tokens[","]) end
					end
				end

				if field.tokens[";"] then self:EmitToken(field.tokens[";"]) end

				self:Whitespace("\n")
			end

			self:Outdent()
			self:EmitToken(node.tokens["}"])
		end
	end
end

function META:EmitEnum(node)
	self:EmitToken(node.tokens["enum"])
	self:Whitespace(" ")

	if node.tokens["identifier"] then
		self:EmitToken(node.tokens["identifier"])
	end

	if node.tokens["{"] then
		self:EmitToken(node.tokens["{"])
		self:Whitespace("\n")
		self:Indent()

		for _, v in ipairs(node.fields) do
			self:Whitespace("\t")
			self:EmitToken(v.tokens["identifier"])

			if v.tokens["="] then
				self:Whitespace(" ")
				self:EmitToken(v.tokens["="])
				self:Whitespace(" ")
				self:EmitExpression(v.expression)
			end

			if v.tokens[","] then self:EmitToken(v.tokens[","]) end

			self:Whitespace("\n")
		end

		self:Outdent()
		self:EmitToken(node.tokens["}"])
	end
end

return META
