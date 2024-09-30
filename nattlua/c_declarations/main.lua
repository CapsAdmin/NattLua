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
local Lexer = require("nattlua.c_declarations.lexer").New
local Parser = require("nattlua.c_declarations.parser").New
local Emitter = require("nattlua.c_declarations.emitter").New
local Analyzer = require("nattlua.c_declarations.analyzer").New
local Code = require("nattlua.code").New
local Compiler = require("nattlua.compiler")
local variables = Table()
local types = Table()
local analyzer_context = require("nattlua.analyzer.context")

local function C_DECLARATIONS()
	local analyzer = assert(analyzer_context:GetCurrentAnalyzer(), "no analyzer in context")
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	return analyzer:Assert(env.runtime.ffi:Get(ConstString("C")))
end

local function gen(parser, ...)
	local new = {}

	for i, v in ipairs(parser.dollar_signs) do
		local ct = select(i, ...)

		if not ct then error("expected ctype at argument #" .. i, 2) end

		table.insert(new, ct)
	end

	return new
end

local function analyze(c_code, mode, env, analyzer, ...)
	if mode == "typeof" then
		c_code = "typedef void (*TYPEOF_CDECL)(" .. c_code .. ");"
	elseif mode == "ffinew" then
		c_code = "void (*TYPEOF_CDECL)(" .. c_code .. ");"
	end

	local code = Code(c_code, "test.c")
	local lex = Lexer(code)
	local tokens = lex:GetTokens()
	local parser = Parser(tokens, code)
	parser.OnError = function(parser, code, msg, start, stop, ...)
		Compiler.OnDiagnostic({}, code, msg, "fatal", start, stop, nil, ...)
		error("error parsing")
	end
	parser.CDECL_PARSING_MODE = mode
	local ast = parser:ParseRootNode()
	local emitter = Emitter({skip_translation = true})
	local res = emitter:BuildCode(ast)
	local a = Analyzer()

	if parser.dollar_signs then
		a.dollar_signs_typs = gen(parser, ...)
		a.dollar_signs_vars = gen(parser, ...)
	end

	a.env = env.typesystem
	a.analyzer = analyzer
	return a:AnalyzeRoot(ast, variables, types, mode)
end

local function extract_anonymous_type(typs)
	local ctype = typs:Get(LString("TYPEOF_CDECL"))
	ctype:RemoveType(Nil())
	return ctype:GetData()[1]:Get(Number()):GetInputSignature():Get(1)
end

function cparser.sizeof(cdecl, len)
	-- TODO: support non string sizeof
	if jit and cdecl.Type == "string" and cdecl:IsLiteral() then
		local ffi = require("ffi")
		local analyzer = analyzer_context:GetCurrentAnalyzer()
		local env = analyzer:GetScopeHelper(analyzer.function_scope)
		local vars, typs = analyze(cdecl:GetData(), "typeof", env, analyzer)
		local ctype = extract_anonymous_type(typs)
		local ok, val = pcall(ffi.sizeof, cdecl:GetData(), len and len:GetData() or nil)

		if ok then return val end
	end

	return Number()
end

function cparser.cdef(cdecl, ...)
	assert(cdecl:IsLiteral(), "cdecl must be a string literal")
	local analyzer = analyzer_context:GetCurrentAnalyzer()
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	local vars, typs = analyze(cdecl:GetData(), "cdef", env, analyzer, ...)
	variables = vars
	types = typs

	for _, kv in ipairs(variables:GetData()) do
		analyzer:NewIndexOperator(C_DECLARATIONS(), kv.key, kv.val)
	end

	return vars, typs
end

function cparser.reset()
	variables = Table()
	types = Table()
	local analyzer = assert(analyzer_context:GetCurrentAnalyzer(), "no analyzer in context")
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	analyzer:Assert(env.typesystem.ffi:Set(ConstString("C"), Table()))
	analyzer:Assert(env.runtime.ffi:Set(ConstString("C"), Table()))
end

function cparser.cast(cdecl, src)
	assert(cdecl:IsLiteral(), "cdecl must be a string literal")
	local analyzer = analyzer_context:GetCurrentAnalyzer()
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	local vars, typs = analyze(cdecl:GetData(), "typeof", env, analyzer)
	local ctype = extract_anonymous_type(typs)

	if ctype.Type == "union" then
		for _, v in ipairs(ctype:GetData()) do
			if v.Type == "table" then
				ctype = v

				break
			end
		end
	end

	if ctype.Type == "any" then return ctype end

	ctype:SetMetaTable(ctype)
	return ctype
end

function cparser.typeof(cdecl, ...)
	assert(cdecl:IsLiteral(), "c_declaration must be a string literal")
	local args = {...}

	if args[1] and args[1].Type == "tuple" then args = {args[1]:Unpack()} end

	local analyzer = analyzer_context:GetCurrentAnalyzer()
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	local vars, typs = analyze(cdecl:GetData(), "typeof", env, analyzer, ...)
	local ctype = extract_anonymous_type(typs)

	-- TODO, this tries to extract cdata from cdata | nil, since if we cast a valid pointer it cannot be invalid when returned
	if ctype.Type == "union" then
		for _, v in ipairs(ctype:GetData()) do
			if v.Type == "table" then
				ctype = v

				break
			end
		end
	end

	return analyzer:Call(env.typesystem.FFICtype, Tuple({ctype}), analyzer.current_expression)
end

function cparser.get_type(cdecl, ...)
	assert(cdecl:IsLiteral(), "c_declaration must be a string literal")
	local analyzer = analyzer_context:GetCurrentAnalyzer()
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	local vars, typs = analyze(cdecl:GetData(), "typeof", env, analyzer, ...)
	local ctype = extract_anonymous_type(typs)
	return ctype
end

function cparser.new(cdecl, ...)
	local analyzer = analyzer_context:GetCurrentAnalyzer()
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	local vars, typs = analyze(cdecl:GetData(), "ffinew", env, analyzer, ...)
	local ctype = extract_anonymous_type(vars)

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
					local analyzer = analyzer_context:GetCurrentAnalyzer()
					local val = analyzer:Assert(analyzer:Call(new, Tuple({ctype, ...}))):Unpack()

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
	return variables
end

return cparser
