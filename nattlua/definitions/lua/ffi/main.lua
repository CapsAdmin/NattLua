--[[HOTRELOAD

run_test("test/tests/nattlua/c_declarations/cdef.nlua")
run_test("test/tests/nattlua/c_declarations/parsing.lua")
run_test("test/tests/nattlua/c_declarations/typed_ffi.lua")

]]
local pcall = _G.pcall
local assert = _G.assert
local ipairs = _G.ipairs
local select = _G.select
local table = _G.table
local jit = _G.jit
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
local Lexer = require("nattlua.lexer.lexer").New
local Parser = require("nattlua.definitions.lua.ffi.parser").New
local Emitter = require("nattlua.definitions.lua.ffi.emitter").New
local Analyzer = require("nattlua.definitions.lua.ffi.analyzer").New
local Code = require("nattlua.code").New
local Compiler = require("nattlua.compiler")
local variables = Table()
local types = Table()
local analyzer_context = require("nattlua.analyzer.context")

local function C_DECLARATIONS()
	local analyzer = assert(analyzer_context:GetCurrentAnalyzer(), "no analyzer in context")
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	local C, err = env.runtime.ffi:Get(ConstString("C"))

	if not C then
		print(err)
		analyzer:FatalError("cannot find C declarations")
	end

	return C
end

local function gen(parser, ...)
	local new = {}

	for i, v in ipairs(parser.dollar_signs) do
		local ct = select(i, ...)

		if not ct then
			error("expected ctype or value to fill $ or ? at argument #" .. i, 2)
		end

		if ct.Type == "union" then
			local u = {}

			for i, obj in ipairs(ct:GetData()) do
				u[i] = assert(obj:Get(LString("T")))
			end

			ct = Union(u)
		end

		if ct.Type == "table" then ct = assert(ct:Get(LString("T"))) end

		table.insert(new, ct)
	end

	return new
end

local function TCType(obj)
	local analyzer = analyzer_context:GetCurrentAnalyzer()
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	return analyzer:Call(env.typesystem.TCType, Tuple({obj})):GetFirstValue()
end

local function TCData(obj, ...)
	local analyzer = analyzer_context:GetCurrentAnalyzer()
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	return analyzer:Call(env.typesystem.TCData, Tuple({obj, ...})):GetFirstValue()
end

local function process_arg(obj)
	if obj.Type == "number" then
		return Union({TCData(obj), obj})
	elseif obj.Type == "table" then
		local typ = obj:Get(Number())

		if typ then
			if typ.Type == "number" then
				return Union({Nil(), TCData(obj), obj.is_string and String() or nil})
			end

			return Union({TCData(typ:Copy()), Nil(), TCData(obj), obj.is_string and String() or nil})
		end
	elseif obj.Type == "union" then
		local u = {}

		for i, obj in ipairs(obj:GetData()) do
			if obj.Type == "table" then u[i] = TCData(obj) else u[i] = obj end
		end

		return Union(u)
	end
end

local function process_type(key, obj, is_typedef, mode)
	if obj.Type == "function" then
		for i, v in ipairs(obj:GetInputSignature():GetData()) do
			local newtype = process_arg(v)

			if newtype then obj:GetInputSignature():Set(i, newtype) end
		end

		local ret = obj:GetOutputSignature():GetFirstValue()

		if ret then
			if ret.Type == "any" then
				obj:SetOutputSignature(Tuple({}))
			elseif ret.Type == "table" then
				if
					ret:GetData()[1].key.Type == "number" and
					not ret:GetData()[1].key:IsLiteral()
				then
					-- only pointers can be nil
					obj:GetOutputSignature():Set(1, Union({Nil(), TCData(ret)}))
				else
					obj:GetOutputSignature():Set(1, TCData(ret))
				end
			end
		end
	end

	if mode == "cdef" and not is_typedef then
		local analyzer = assert(analyzer_context:GetCurrentAnalyzer(), "no analyzer in context")
		analyzer:NewIndexOperator(C_DECLARATIONS(), key, obj)
	end

	return obj
end

local function analyze(c_code, mode, ...)
	if c_code.Type == "union" then
		local vars, typs, captured

		for _, v in ipairs(c_code:GetData()) do
			vars, typs, captured = analyze(v, mode, ...)
		end

		return vars, typs, captured
	end

	local c_code_string_obj = c_code
	local c_code_raw = c_code:GetData()
	assert(type(c_code_raw) == "string", "c_code:GetData() must return a string")

	if mode == "typeof" then
		c_code_raw = "typedef void (*TYPEOF_CDECL)(" .. c_code_raw .. ");"
	elseif mode == "ffinew" then
		c_code_raw = "void (*TYPEOF_CDECL)(" .. c_code_raw .. ");"
	end

	local code = Code(c_code_raw, "test.c")
	local lex = Lexer(code)
	local tokens = lex:GetTokens()
	c_code_string_obj.c_tokens = tokens
	local parser = Parser(tokens, code)
	parser.OnError = function(parser, code, msg, start, stop, ...)
		Compiler.OnDiagnostic({}, code, msg, "error", start, stop, nil, ...)
	end
	local ast = parser:ParseRootNode()
	local emitter = Emitter({skip_translation = true})
	local res = emitter:BuildCode(ast)
	local a = Analyzer()

	if parser.dollar_signs then
		a.dollar_signs_typs = gen(parser, ...)
		a.dollar_signs_vars = gen(parser, ...)
	end

	local vars, typs = a:AnalyzeRoot(ast, variables, types, process_type, mode)
	return vars, typs, a.captured
end

local ok, ffi = pcall(require, "ffi")

function cparser.sizeof(cdecl, len)
	-- TODO: support non string sizeof
	if ffi and cdecl.Type == "string" and cdecl:IsLiteral() then
		local vars, typs, ctype = analyze(cdecl, "typeof")
		local ok, val = pcall(ffi.sizeof, cdecl:GetData(), len and len:GetData() or nil)

		if ok then return val end
	end

	return Number()
end

function cparser.cdef(cdecl, ...)
	assert(cdecl:IsLiteral(), "cdecl must be a string literal")
	local vars, typs = analyze(cdecl, "cdef", ...)
	variables = vars
	types = typs
	return vars, typs
end

function cparser.reset()
	variables = Table()
	types = Table()
	local analyzer = assert(analyzer_context:GetCurrentAnalyzer(), "no analyzer in context")
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	env.runtime.ffi:ClearMutations()
	analyzer:ErrorIfFalse(env.runtime.ffi:Set(ConstString("C"), Table()))
end

function cparser.cast(cdecl, src)
	if cdecl.Type == "string" and cdecl:IsLiteral() then
		local vars, typs, ctype = analyze(cdecl, "ffinew")
		return TCData(ctype)
	elseif cdecl.Type == "function" then
		local vars, typs, ctype = analyze(LString("void(*)()"), "ffinew")
		return TCData(ctype)
	elseif cdecl.Type == "table" then
		if src.Type == "string" then
			local vars, typs, ctype = analyze(LString("const char *"), "ffinew")
			return TCData(ctype)
		end

		return src:Copy()
	end
end

function cparser.typeof(cdecl, ...)
	if cdecl.Type == "string" and cdecl:IsLiteral() then
		local args = {...}

		if args[1] and args[1].Type == "tuple" then args = args[1]:ToTable() end

		local vars, typs, ctype = analyze(cdecl, "typeof", ...)
		return TCType(ctype)
	end

	local vars, typs, ctype = analyze(LString("void *"), "typeof")
	return TCType(ctype)
end

function cparser.typeof_arg(cdecl, ...)
	assert(cdecl:IsLiteral(), "c_declaration must be a string literal")
	local vars, typs, ctype = analyze(cdecl, "typeof", ...)
	return process_arg(ctype) or ctype
end

function cparser.get_type(cdecl, ...)
	assert(cdecl:IsLiteral(), "c_declaration must be a string literal")
	local vars, typs, ctype = analyze(cdecl, "typeof", ...)
	return TCData(ctype)
end

function cparser.get_raw_type(cdecl, ...)
	assert(cdecl:IsLiteral(), "c_declaration must be a string literal")
	local vars, typs, ctype = analyze(cdecl, "typeof", ...)
	return ctype
end

function cparser.new(cdecl, ...)
	local vars, typs, ctype = analyze(cdecl, "ffinew", ...)
	return TCData(ctype, ...)
end

function cparser.metatype(ctype, meta)
	error("metatype is not supported yet")

	if ctype.Type == "string" then ctype = cparser.get_type(ctype) end

	for _, kv in ipairs(meta:GetData()) do
		if kv.key:GetData() == "__index" then  else ctype:Set(kv.key, kv.val) end
	end

	local new = meta:Get(ConstString("__new"))
	local analyzer = analyzer_context:GetCurrentAnalyzer()

	if new then
		local new_func = LuaTypeFunction(
			function(self, ...)
				local analyzer = analyzer_context:GetCurrentAnalyzer()
				local val = analyzer:Assert(analyzer:Call(new, Tuple({ctype, ...}))):GetFirstValue()

				if analyzer:IsRuntime() then
					meta.PotentialSelf = meta.PotentialSelf or Union()
					meta.PotentialSelf:AddType(val)
				end

				return val
			end,
			new:GetInputSignature():GetData(),
			new:GetOutputSignature():GetData()
		)
		meta:Set(ConstString("__call"), new_func)
		analyzer:AddToUnreachableCodeAnalysis(new_func)
	end

	return ctype
end

function cparser.load(lib--[[#: string]])
	return variables
end

return cparser
