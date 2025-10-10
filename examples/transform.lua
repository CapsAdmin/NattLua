local nl = require("nattlua")
local LuaEmitter = require("nattlua.emitter.emitter").New
local ast = assert(nl.File("nattlua/parser/parser.lua"):Parse()).SyntaxTree
local em = LuaEmitter({pretty_print = true, no_newlines = false})

function em:OnEmitStatement()
	self:Emit(";")
end

local translate = {
	["not"] = "!",
	["and"] = "&&",
	["or"] = "||",
	["local"] = "var",
	--["for"] = "for (",
	["do"] = "{",
	["end"] = "}",
	["if"] = "if (",
	["then"] = ") {",
	["elseif"] = "} else if (",
	["else"] = "} else {",
}

function em:EmitForStatement(node)
	self:Whitespace("\t")
	self:EmitToken(node.tokens["for"])
	self:Whitespace(" ")
	self:Emit("(")

	if node.fori then
		self:Emit("let ")
		self:EmitIdentifierList(node.identifiers)
		self:Whitespace(" ")
		self:EmitToken(node.tokens["="])
		self:Whitespace(" ")
		self:EmitExpression(node.expressions[1])
		self:Emit("; ")
		self:EmitIdentifierList(node.identifiers)
		self:Emit(" <= ")
		self:EmitExpression(node.expressions[2])
		self:Emit("; ")
		self:EmitIdentifierList(node.identifiers)
		self:Emit(" = ")
		self:EmitIdentifierList(node.identifiers)
		self:Emit(" + ")

		if node.expressions[3] then
			self:EmitExpression(node.expressions[3])
		else
			self:Emit("1")
		end
	else
		self:EmitIdentifierList(node.identifiers)
		self:Whitespace(" ")
		self:EmitToken(node.tokens["in"])
		self:Whitespace(" ")
		self:EmitExpressionList(node.expressions)
	end

	self:Emit(")")
	self:Whitespace(" ")
	self:EmitToken(node.tokens["do"])
	self:Whitespace("\n")
	self:EmitBlock(node.statements)
	self:Whitespace("\t")
	self:EmitToken(node.tokens["end"])
end

function em:TranslateToken(token)
	local value = token:GetValueString()
	if translate[value] then return translate[value] end

	if token.type == "line_comment" then
		return "//" .. value:sub(3)
	elseif token.type == "multiline_comment" then
		local content = value:sub(5, -3):gsub("%*/", "* /"):gsub("/%*", "/ *")
		return "/*" .. content .. "*/"
	end

	if token.type == "letter" and value:upper() ~= value then
		return value:sub(1, 1):lower() .. value:sub(2)
	end
end

local code = em:BuildCode(ast)
print(code)