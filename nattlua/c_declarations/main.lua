local cparser = {}
local Function = require("nattlua.types.function").Function
local LuaTypeFunction = require("nattlua.types.function").LuaTypeFunction
local LNumber = require("nattlua.types.number").LNumber
local Number = require("nattlua.types.number").Number
local LString = require("nattlua.types.string").LString
local String = require("nattlua.types.string").String
local Table = require("nattlua.types.table").Table
local ConstString = require("nattlua.types.string").ConstString
local Nil = require("nattlua.types.symbol").Nil
local Symbol = require("nattlua.types.symbol").Symbol
local Any = require("nattlua.types.any").Any
local Union = require("nattlua.types.union").Union
local Nilable = require("nattlua.types.union").Nilable
local Tuple = require("nattlua.types.tuple").Tuple
local Boolean = require("nattlua.types.union").Boolean

local function C_DECLARATIONS()
	local analyzer = assert(
		require("nattlua.analyzer.context"):GetCurrentAnalyzer(),
		"no analyzer in context"
	)
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	return env.typesystem.ffi:Get(ConstString("C"))
end

local function C_DECLARATIONS_RUNTIME()
	local analyzer = assert(
		require("nattlua.analyzer.context"):GetCurrentAnalyzer(),
		"no analyzer in context"
	)
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	return env.runtime.ffi:Get(ConstString("C"))
end

local function parse2(c_code, mode, env, analyzer, ...)
	local Lexer = require("nattlua.c_declarations.lexer").New
	local Parser = require("nattlua.c_declarations.parser").New
	local Emitter = require("nattlua.c_declarations.emitter").New
	local Analyzer = require("nattlua.c_declarations.analyzer").New
	local Code = require("nattlua.code").New
	local Compiler = require("nattlua.compiler")

	if mode == "typeof" then c_code = "typedef " .. c_code .. " TYPEOF_CDECL;" end

	if mode == "ffinew" then c_code = c_code .. " VAR_NAME;" end

	local code = Code(c_code, "test.c")
	local lex = Lexer(code)
	local tokens = lex:GetTokens()
	local parser = Parser(tokens, code)
	parser.CDECL_PARSING_MODE = mode
	local ast = parser:ParseRootNode()
	local emitter = Emitter({skip_translation = true})
	local res = emitter:BuildCode(ast)
	local a = Analyzer()

	if parser.dollar_signs then
		local function gen(...)
			local new = {}

			for i, v in ipairs(parser.dollar_signs) do
				local ct = select(i, ...)

				if not ct then error("expected ctype at argument #" .. i, 2) end

				table.insert(new, 1, ct)
			end

			return new
		end

		a.dollar_signs_typs = gen(...)
		a.dollar_signs_vars = gen(...)
	end

	a.env = env.typesystem
	a.analyzer = analyzer
	return a:AnalyzeRoot(ast, C_DECLARATIONS_RUNTIME(), C_DECLARATIONS())
end

function cparser.sizeof(cdecl, len)
	-- TODO: support non string sizeof
	if jit and cdecl.Type == "string" and cdecl:IsLiteral() then
		local analyzer = require("nattlua.analyzer.context"):GetCurrentAnalyzer()
		local env = analyzer:GetScopeHelper(analyzer.function_scope)
		local vars, typs = parse2(cdecl:GetData(), "typeof", env, analyzer)
		local ctype = typs:GetData()[1].val
		local ffi = require("ffi")
		local ok, val = pcall(ffi.sizeof, cdecl:GetData(), len and len:GetData() or nil)

		if ok then return val end
	end

	return Number()
end

function cparser.cdef(cdecl, ...)
	assert(cdecl:IsLiteral(), "cdecl must be a string literal")
	local analyzer = require("nattlua.analyzer.context"):GetCurrentAnalyzer()
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	local vars, typs = parse2(cdecl:GetData(), "cdef", env, analyzer, ...)

	for _, kv in ipairs(typs:GetData()) do
		analyzer:NewIndexOperator(C_DECLARATIONS(), kv.key, kv.val)
	end

	for _, kv in ipairs(vars:GetData()) do
		analyzer:NewIndexOperator(C_DECLARATIONS_RUNTIME(), kv.key, kv.val)
	end

	return nil
end

function cparser.cast(cdecl, src)
	assert(cdecl:IsLiteral(), "cdecl must be a string literal")
	local analyzer = require("nattlua.analyzer.context"):GetCurrentAnalyzer()
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	local vars, typs = parse2(cdecl:GetData(), "typeof", env, analyzer)
	local ctype = typs:GetData()[1].val

	-- TODO, this tries to extract cdata from cdata | nil, since if we cast a valid pointer it cannot be invalid when returned
	if ctype.Type == "union" then
		for _, v in ipairs(ctype:GetData()) do
			if v.Type == "table" then
				ctype = v

				break
			end
		end
	end

	if ctype.Type == "any" then return ctype end

	local nilable_ctype = ctype:Copy()

	for _, keyval in ipairs(nilable_ctype:GetData()) do
		keyval.val = Nilable(keyval.val)
	end

	ctype:SetMetaTable(ctype)
	return ctype
end

function cparser.typeof(cdecl, ...)
	assert(cdecl:IsLiteral(), "c_declaration must be a string literal")
	local args = {...}

	if args[1] and args[1].Type == "tuple" then args = {args[1]:Unpack()} end

	local analyzer = require("nattlua.analyzer.context"):GetCurrentAnalyzer()
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	local vars, typs = parse2(cdecl:GetData(), "typeof", env, analyzer, ...)
	local ctype = typs:GetData()[1].val

	-- TODO, this tries to extract cdata from cdata | nil, since if we cast a valid pointer it cannot be invalid when returned
	if ctype.Type == "union" then
		for _, v in ipairs(ctype:GetData()) do
			if v.Type == "table" then
				ctype = v

				break
			end
		end
	end

	if ctype.Type == "any" then return ctype end

	local nilable_ctype = ctype:Copy()

	if ctype.Type == "table" then
		for _, keyval in ipairs(nilable_ctype:GetData()) do
			keyval.val = Nilable(keyval.val)
		end
	end

	if ctype.is_enum and ctype:GetMetaTable() then return ctype end

	local old = ctype:GetContract()
	ctype:SetContract()
	ctype:Set(
		ConstString("__call"),
		LuaTypeFunction(
			function(self, init)
				local analyzer = require("nattlua.analyzer.context"):GetCurrentAnalyzer()

				if init then analyzer:Assert(init:IsSubsetOf(nilable_ctype)) end

				return self:Copy()
			end,
			{ctype, Nilable(nilable_ctype)},
			{ctype}
		)
	)
	ctype:SetMetaTable(ctype)
	ctype:SetContract(old)
	return ctype
end

function cparser.get_type(cdecl, ...)
	assert(cdecl:IsLiteral(), "c_declaration must be a string literal")
	local analyzer = require("nattlua.analyzer.context"):GetCurrentAnalyzer()
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	local vars, typs = parse2(cdecl:GetData(), "typeof", env, analyzer, ...)
	local ctype = typs:GetData()[1].val
	return ctype
end

function cparser.new(cdecl, ...)
	local analyzer = require("nattlua.analyzer.context"):GetCurrentAnalyzer()
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	local vars, typs = parse2(cdecl:GetData(), "ffinew", env, analyzer, ...)
	local ctype = vars:GetData()[1].val

	if ctype.is_enum then return ... end

	return ctype
end

function cparser.metatype(ctype, meta)
	local new = meta:Get(ConstString("__new"))

	if new then
		meta:Set(
			ConstString("__call"),
			LuaTypeFunction(
				function(self, ...)
					local analyzer = require("nattlua.analyzer.context"):GetCurrentAnalyzer()
					local val = analyzer:Assert(new:Call(analyzer, Tuple({ctype, ...}))):Unpack()

					if val.Type == "union" then
						for i, v in ipairs(val:GetData()) do
							if v.Type == "table" then v:SetMetaTable(meta) end
						end
					else
						val:SetMetaTable(meta)
					end

					return val
				end,
				new:GetInputSignature():GetData(),
				new:GetOutputSignature():GetData()
			)
		)
	end

	ctype:SetMetaTable(meta)
end

function cparser.load(lib--[[#: string]])
	return C_DECLARATIONS()
end

return cparser