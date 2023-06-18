local class = require("nattlua.other.class")
local META = class.CreateTemplate("analyzer")

function META:WalkRoot(node)
	for _, node in ipairs(node.statements) do
		self:WalkCDeclaration(node)
	end
end

function META:WalkCDeclaration_(node, walk_up)
	-- arrays have precedence over pointers
	if node.array_expression then
		for k, v in ipairs(node.array_expression) do
			self.cdecl.of = {
				type = "array",
				size = v.expression:Render(),
			}
			self.cdecl = self.cdecl.of
		end
	end

	-- after that read pointers
	if node.pointers then
		for k, v in ipairs(node.pointers) do
			local modifiers = {}

			for i = #v, 1, -1 do
				local v = v[i]

				if not v.DONT_WRITE then
					if v.value ~= "*" then table.insert(modifiers, v.value) end
				end
			end

			self.cdecl.of = {
				type = "pointer",
				modifiers = modifiers,
			}
			self.cdecl = assert(self.cdecl.of)
		end
	end

	if node.modifiers then
		local modifiers = {}

		for k, v in ipairs(node.modifiers) do
			if not v.DONT_WRITE then table.insert(modifiers, v.value) end
		end

		if modifiers[1] then
			self.cdecl.of = {
				type = "type",
				modifiers = modifiers,
			}
			self.cdecl = assert(self.cdecl.of)
		end
	end

	if node.arguments then
		local args = {}
		local old = self.cdecl

		for i, v in ipairs(node.arguments) do
			local t = {type = "root"}
			self.cdecl = t
			self:WalkCDeclaration_(v, nil)
			table.insert(args, t.of)
		end

		self.cdecl = old
		self.cdecl.of = {
			type = "function",
			args = args,
			rets = {type = "root"},
		}
		self.cdecl = assert(self.cdecl.of.rets)
	end

	if not walk_up then return end

	if node.parent.kind == "c_declaration" then
		self:WalkCDeclaration_(node.parent, true)
	end
end

function META:WalkCDeclaration(node)
	while node.expression do -- find the inner most expression
		node = node.expression
	end

	self.cdecl = {type = "root", of = nil}
	local lol = self.cdecl
	self:WalkCDeclaration_(node, true, out)
	self.Callback(lol.of)
end

function META.New(ast, callback)
	local self = setmetatable({}, META)
	self.Callback = callback
	self:WalkRoot(ast)
	return self
end

_G.TEST = nil
local nl = require("nattlua")
nl.Compiler([==[
local analyzer function cdef(str: string)
	local Lexer = require("nattlua.c_declarations.lexer").New
	local Parser = require("nattlua.c_declarations.parser").New
	local Emitter = require("nattlua.c_declarations.emitter").New
	local Analyzer = require("nattlua.c_declarations.analyzer").New
	local Code = require("nattlua.code").New
	local Compiler = require("nattlua.compiler")
	local c_code = str:GetData()
	local code = Code(c_code, "test.c")
	local lex = Lexer(code)
	local tokens = lex:GetTokens()
	local parser = Parser(tokens, code)
	local ast = parser:ParseRootNode()
	local emitter = Emitter({skip_translation = true})
	local res = emitter:BuildCode(ast)

	local function cast(node)
		if node.type == "array" then
			return (env.typesystem.FFIArray:Call(analyzer, types.Tuple({types.LNumber(tonumber(node.size) or math.huge), cast(assert(node.of))})):Unpack())
		elseif node.type == "pointer" then
			if not node.of then table.print(node) end
			return (env.typesystem.FFIPointer:Call(analyzer, types.Tuple({cast(assert(node.of))})):Unpack())
		elseif node.type == "type" then
			return types.Number()
		elseif node.type == "function" then
			local args = {}
			local rets = {}

			for i, v in ipairs(node.args) do
				table.insert(args, cast(v))
			end

			return (types.Function(types.Tuple(args), types.Tuple({cast(assert(node.rets))})))
		elseif node.type == "root" then
			if not node.of then table.print(node) end

			return cast(assert(node.of))
		else
			error("unknown type " .. node.type)
		end
	end

	Analyzer(ast, function(node)
		if node then
			print(cast(node))
		end
	end)
end

cdef([[
	unsigned long long * volatile (* (* *NAME [1][2])(char *))[3][4];
]])

]==]):Analyze()
return META