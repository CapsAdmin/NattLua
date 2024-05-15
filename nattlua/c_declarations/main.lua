local cparser = {}
local table_print = require("nattlua.other.table_print")
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


local function parse2(c_code, env, analyzer, ...)
	local Lexer = require("nattlua.c_declarations.lexer").New
	local Parser = require("nattlua.c_declarations.parser").New
	local Emitter = require("nattlua.c_declarations.emitter").New
	local Analyzer = require("nattlua.c_declarations.analyzer").New
	local Code = require("nattlua.code").New
	local Compiler = require("nattlua.compiler")

	local code = Code(c_code, "test.c")
	local lex = Lexer(code)
	local tokens = lex:GetTokens()
	local parser = Parser(tokens, code)
	local ast = parser:ParseRootNode()
	local emitter = Emitter({skip_translation = true})
	local res = emitter:BuildCode(ast)
	local a = Analyzer()
	if parser.dollar_signs then
		local function gen(...)
			local new = {}
			for i, v in ipairs(parser.dollar_signs) do
				local ct = select(i, ...)
				if not ct then
					error("expected ctype at argument #" .. i, 2)
				end
				table.insert(new, 1, ct)
			end
			return new
		end

		a.dollar_signs_typs = gen(...)
		a.dollar_signs_vars = gen(...)
	end
	a.env = env.typesystem
	a.analyzer = analyzer
	return a:AnalyzeRoot(ast)
end

local fbcparser = require("nattlua.c_declarations.legacy")
local function parse(str, mode, ...)
	local res = assert(fbcparser.parseString(
		str, 
		{
			typeof = mode == "typeof",
			ffinew = mode == "ffinew",
		}, 
		{...}
	))

	return res
end

local function C_DECLARATIONS()
	local analyzer = assert(
		require("nattlua.analyzer.context"):GetCurrentAnalyzer(),
		"no analyzer in context"
	)
	local env = analyzer:GetScopeHelper(analyzer.function_scope)
	return env.typesystem.ffi:Get(ConstString("C"))
end

local function cdata_metatable(from, const)
	local analyzer = assert(
		require("nattlua.analyzer.context"):GetCurrentAnalyzer(),
		"no analyzer in context"
	)
	local meta = Table()
	meta:Set(
		ConstString("__index"),
		LuaTypeFunction(
			function(self, key)
				-- i'm not really sure about this
				-- boxed luajit ctypes seem to just get the metatable from the ctype
				return analyzer:Assert(analyzer:IndexOperator(from, key))
			end,
			{Any(), Any()},
			{}
		)
	)

	if const then
		meta:Set(
			ConstString("__newindex"),
			LuaTypeFunction(
				function(self, key, value)
					error("attempt to write to constant location")
				end,
				{Any(), Any(), Any()},
				{}
			)
		)
	end

	meta:Set(
		ConstString("__add"),
		LuaTypeFunction(function(self, key)
			return self
		end, {Any(), Any()}, {})
	)
	meta:Set(
		ConstString("__sub"),
		LuaTypeFunction(function(self, key)
			return self
		end, {Any(), Any()}, {})
	)
	return meta
end

local function cast(node, args)
	local analyzer = require("nattlua.analyzer.context"):GetCurrentAnalyzer()

	if node.tag == "Enum" then
		local tbl = Table()
		local keys = {}

		for i, node in ipairs(node) do
			local key = LString(node[1])
			local val = LNumber(node[2] or i - 1)
			tbl:Set(key, val)
			table.insert(keys, key)
		end

		local key_union = Union(keys)
		local meta = Table()
		meta:Set(
			ConstString("__call"),
			LuaTypeFunction(
				function(self, key)
					return analyzer:Assert(tbl:Get(key))
				end,
				{Any(), key_union},
				{}
			)
		)
		tbl:SetMetaTable(meta)
		tbl.is_enum = true
		return tbl
	elseif node.tag == "Struct" or node.tag == "Union" then
		local tbl = Table()

		if node.n then
			tbl.ffi_name = "struct " .. node.n
			analyzer.current_tables = analyzer.current_tables or {}
			table.insert(analyzer.current_tables, tbl)
		end

		for _, node in ipairs(node) do
			if node.tag == "Pair" then
				local key = LString(node[2])
				local val = cast(node[1], args)
				tbl:Set(key, val)
			else
				table_print(node)
				error("NYI: " .. node.tag)
			end
		end

		if node.n then table.remove(analyzer.current_tables) end

		return tbl
	elseif node.tag == "Function" then
		local arguments = {}

		for _, arg in ipairs(node) do
			if arg.ellipsis then
				table.insert(arguments, Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge)))
			else
				_G.FUNCTION_ARGUMENT = true
				local arg = cast(arg[1], args)
				_G.FUNCTION_ARGUMENT = nil
				table.insert(arguments, arg)
			end
		end

		local return_type

		if
			node.t.tag == "Pointer" and
			node.t.t.tag == "Qualified" and
			node.t.t.t.n == "char"
		then
			local ptr = Table()
			ptr:Set(Number(), Number())
			return_type = Union({ptr, Nil()})
		else
			return_type = cast(node.t, args)
		end

		local obj = Function(Tuple(arguments), Tuple({return_type}))
		return obj
	elseif node.tag == "Array" then
		local tbl = Table()
		-- todo node.size: array length
		_G.FUNCTION_ARGUMENT = true
		local t = cast(node.t, args)
		_G.FUNCTION_ARGUMENT = nil
		tbl:Set(Number(), t)
		local meta = cdata_metatable(tbl)
		tbl:SetContract(tbl)
		tbl:SetMetaTable(meta)
		return tbl
	elseif node.tag == "Type" then
		if
			node.n == "double" or
			node.n == "float" or
			node.n == "int8_t" or
			node.n == "uint8_t" or
			node.n == "int16_t" or
			node.n == "uint16_t" or
			node.n == "int32_t" or
			node.n == "uint32_t" or
			node.n == "char" or
			node.n == "signed char" or
			node.n == "unsigned char" or
			node.n == "short" or
			node.n == "short int" or
			node.n == "signed short" or
			node.n == "signed short int" or
			node.n == "unsigned short" or
			node.n == "unsigned short int" or
			node.n == "int" or
			node.n == "signed" or
			node.n == "signed int" or
			node.n == "unsigned" or
			node.n == "unsigned int" or
			node.n == "long" or
			node.n == "long int" or
			node.n == "signed long" or
			node.n == "signed long int" or
			node.n == "unsigned long" or
			node.n == "unsigned long int" or
			node.n == "float" or
			node.n == "double" or
			node.n == "long double" or
			node.n == "size_t" or
			node.n == "intptr_t" or
			node.n == "uintptr_t"
		then
			return Number()
		elseif
			node.n == "int64_t" or
			node.n == "uint64_t" or
			node.n == "long long" or
			node.n == "long long int" or
			node.n == "signed long long" or
			node.n == "signed long long int" or
			node.n == "unsigned long long" or
			node.n == "unsigned long long int"
		then
			return Number()
		elseif node.n == "bool" or node.n == "_Bool" then
			return Boolean()
		elseif node.n == "void" then
			return Nil()
		elseif node.n == "va_list" then
			return Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
		elseif node.n:find("%$%d+%$") then
			local val = table.remove(args, 1)

			if not val then error("unable to lookup type $ #" .. (#args + 1), 2) end

			return val
		elseif node.parent and node.parent.tag == "TypeDef" then
			if node.n:sub(1, 6) == "struct" then
				local name = node.n:sub(7)
				local tbl = Table()
				tbl:SetName(LString(name))
				return tbl
			end
		else
			if node.n:sub(1, 6) == "struct" then
				local val = analyzer:IndexOperator(C_DECLARATIONS(), LString(node.n:sub(8)))
				if val and (val.Type ~= "symbol" or val:GetData() ~= nil) then
					return val
				end
			end
			
			local val = analyzer:IndexOperator(C_DECLARATIONS(), LString(node.n))

			if not val or val.Type == "symbol" and val:GetData() == nil then
				if analyzer.current_tables then
					local current_tbl = analyzer.current_tables[#analyzer.current_tables]

					if current_tbl and current_tbl.ffi_name == node.n then return current_tbl end
				end

				analyzer:Error("cannot find value " .. node.n)
				return Any()
			end

			return val
		end
	elseif node.tag == "Qualified" then
		return cast(node.t, args)
	elseif node.tag == "Pointer" then
		if node.t.tag == "Type" and node.t.n == "void" then return Any() end

		local ptr = Table()
		local ctype = cast(node.t, args)
		ptr:Set(Number(), ctype)
		local meta = cdata_metatable(ctype, node.t.const)
		ptr:SetMetaTable(meta)

		if node.t.tag == "Qualified" and node.t.t.n == "char" then
			ptr:Set(Number(), ctype)
			ptr:SetName(ConstString("const char*"))

			if _G.FUNCTION_ARGUMENT then return Union({ptr, String(), Nil()}) end

			return ptr
		end

		if node.t.tag == "Type" and node.t.n:sub(1, 1) ~= "$" then
			ptr:SetName(LString(node.t.n .. "*"))
		end

		return Union({ptr, Nil()})
	else
		table_print(node)
		error("NYI: " .. node.tag)
	end
end

function cparser.sizeof(cdecl, len)
	-- TODO: support non string sizeof
	if jit and cdecl.Type == "string" and cdecl:IsLiteral() then
		parse(cdecl:GetData(), "typeof")
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
	local vars, typs = parse2(cdecl:GetData(), env, analyzer, ...)

	for _, kv in ipairs(typs:GetData()) do
		analyzer:NewIndexOperator(C_DECLARATIONS(), kv.key, kv.val)
	end
	for _, kv in ipairs(vars:GetData()) do
		analyzer:NewIndexOperator(C_DECLARATIONS(), kv.key, kv.val)
	end

	return nil
end

function cparser.cast(cdecl, src)
	assert(cdecl:IsLiteral(), "cdecl must be a string literal")
	local declarations = parse(cdecl:GetData(), "typeof")
	local ctype = cast(declarations[#declarations].type)

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

	local declarations = parse(cdecl:GetData(), "typeof", unpack(args))
	local ctype = cast(declarations[#declarations].type, args)

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
	local declarations = parse(cdecl:GetData(), "typeof", ...)
	local ctype = cast(declarations[#declarations].type, {...})
	return ctype
end

function cparser.new(cdecl, ...)
	local declarations = parse(cdecl:GetData(), "ffinew", ...)
	local ctype = cast(declarations[#declarations].type, {...})

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