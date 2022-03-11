function table.destructure(tbl, fields, with_default)
	local out = {}

	for i, key in ipairs(fields) do
		out[i] = tbl[key]
	end

	if with_default then table.insert(out, 1, tbl) end

	return table.unpack(out)
end

function table.mergetables(tables)
	local out = {}

	for i, tbl in ipairs(tables) do
		for k, v in pairs(tbl) do
			out[k] = v
		end
	end

	return out
end

function table.spread(tbl)
	if not tbl then return nil end

	return table.unpack(tbl)
end

function LSX(tag, constructor, props, children)
	local e = constructor and
		constructor(props, children) or
		{
			props = props,
			children = children,
		}
	e.tag = tag
	return e
end

local table_print = require("nattlua.other.table_print")

function table.print(...)
	return table_print(...)
end

IMPORTS = IMPORTS or {}
IMPORTS['nattlua/definitions/utility.nlua'] = function(...) --[[#type boolean = true | false]]
--[[#type integer = number]]
--[[#type Table = {[any] = any} | {}]]
--[[#type Function = function=(...any)>(...any)]]
--[[#type userdata = Table]]
--[[#type cdata = {[number] = any}]]
--[[#type cdata.@TypeOverride = "cdata"]]
--[[#type ctype = any]]
--[[#type thread = Table]]
--[[#type empty_function = function=(...)>(...any)]]

--[[#analyzer function NonLiteral(obj: any)
	if obj.Type == "symbol" and (obj:GetData() == true or obj:GetData() == false) then
		return types.Boolean()
	end

	if obj.Type == "number" or obj.Type == "string" then
		obj = obj:Copy()
		obj:SetLiteral(false)
		return obj
	end

	return obj
end]]

--[[#function List<|val|>
	return {[number] = val | nil}
end]]

--[[#function Map<|key, val|>
	return {[key] = val | nil}
end]]

--[[#function ErrorReturn<|...|>
	return (...,) | (nil, string)
end]]

--[[#analyzer function return_type(func: Function, i: number | nil)
	local i = i and i:GetData() or nil
	return {func:GetReturnTypes():Slice(i, i)}
end]]

--[[#analyzer function set_return_type(func: Function, tup: any)
	func:SetReturnTypes(tup)
end]]

--[[#analyzer function argument_type(func: Function, i: number | nil)
	local i = i and i:GetData() or nil
	return {func:GetArguments():Slice(i, i)}
end]]

--[[#analyzer function exclude(T: any, U: any)
	T = T:Copy()
	T:RemoveType(U)
	return T
end]]

--[[#analyzer function enum(tbl: Table)
	assert(tbl:IsLiteral())
	local union = types.Union()
	analyzer:PushAnalyzerEnvironment("typesystem")

	for key, val in tbl:pairs() do
		analyzer:SetLocalOrGlobalValue(key, val)
		union:AddType(val)
	end

	analyzer:PopAnalyzerEnvironment()
	union:SetLiteral(true)
	return union
end]]

--[[#analyzer function keysof(tbl: Table | {})
	local union = types.Union()

	for _, keyval in ipairs(tbl:GetData()) do
		union:AddType(keyval.key)
	end

	return union
end]]

--[[#--
analyzer function seal(tbl: Table)
	if tbl:GetContract() then return end

	for key, val in tbl:pairs() do
		if val.Type == "function" and val:GetArguments():Get(1).Type == "union" then
			local first_arg = val:GetArguments():Get(1)

			if first_arg:GetType(tbl) and first_arg:GetType(types.Any()) then
				val:GetArguments():Set(1, tbl)
			end
		end
	end

	tbl:SetContract(tbl)
end]]

--[[#function nilable<|tbl|>
	tbl = copy(tbl)

	for key, val in pairs(tbl) do
		tbl[key] = val | nil
	end

	return tbl
end]]

--[[#analyzer function copy(obj: any)
	local copy = obj:Copy()
	copy.mutations = nil
	copy.scope = nil
	copy.potential_self = nil
	return copy
end]]

--[[#analyzer function UnionPairs(values: any)
	if values.Type ~= "union" then values = types.Union({values}) end

	local i = 1
	return function()
		local value = values:GetData()[i]
		i = i + 1
		return value
	end
end]]

--[[#-- typescript utility functions
function Partial<|tbl|>
	local copy = {}

	for key, val in pairs(tbl) do
		copy[key] = val | nil
	end

	return copy
end]]

--[[#function Required<|tbl|>
	local copy = {}

	for key, val in pairs(tbl) do
		copy[key] = val ~ nil
	end

	return copy
end]]

--[[#-- this is more like a seal function as it allows you to modify the table
function Readonly<|tbl|>
	local copy = {}

	for key, val in pairs(tbl) do
		copy[key] = val
	end

	copy.@Contract = copy
	return copy
end]]

--[[#function Record<|keys, tbl|>
	local out = {}

	for value in UnionPairs(keys) do
		out[value] = tbl
	end

	return out
end]]

--[[#function Pick<|tbl, keys|>
	local out = {}

	for value in UnionPairs(keys) do
		if tbl[value] == nil then
			error("missing key '" .. value .. "' in table", 2)
		end

		out[value] = tbl[value]
	end

	return out
end]]

--[[#analyzer function Delete(tbl: Table, key: string)
	local out = tbl:Copy()
	tbl:Delete(key)
	return out
end]]

--[[#function Omit<|tbl, keys|>
	local out = copy<|tbl|>

	for value in UnionPairs(keys) do
		if tbl[value] == nil then
			error("missing key '" .. value .. "' in table", 2)
		end

		Delete<|out, value|>
	end

	return out
end]]

--[[#function Exclude<|a, b|>
	return a ~ b
end]]

--[[#analyzer function Union(...)
	return types.Union({...})
end]]

--[[#function Extract<|a, b|>
	local out = Union<||>

	for aval in UnionPairs(a) do
		for bval in UnionPairs(b) do
			if aval < bval then out = out | aval end
		end
	end

	return out
end]]

--[[#analyzer function Parameters(func: Function)
	return {func:GetArguments():Copy():Unpack()}
end]]

--[[#analyzer function ReturnType(func: Function)
	return {func:GetReturnTypes():Copy():Unpack()}
end]]

--[[#function Uppercase<|val|>
	return val:upper()
end]]

--[[#function Lowercase<|val|>
	return val:lower()
end]]

--[[#function Capitalize<|val|>
	return val:sub(1, 1):upper() .. val:sub(2)
end]]

--[[#function Uncapitalize<|val|>
	return val:sub(1, 1):lower() .. val:sub(2)
end]]

--[[#analyzer function PushTypeEnvironment(obj: any)
	local tbl = types.Table()
	tbl:Set(types.LString("_G"), tbl)
	local g = analyzer:GetGlobalEnvironment("typesystem")
	tbl:Set(
		types.LString("__index"),
		types.LuaTypeFunction(
			function(self, key)
				local ok, err = obj:Get(key)

				if ok then return ok end

				local val, err = analyzer:IndexOperator(key:GetNode(), g, key)

				if val then return val end

				analyzer:Error(key:GetNode(), err)
				return types.Nil()
			end,
			{types.Any(), types.Any()},
			{}
		)
	)
	tbl:Set(
		types.LString("__newindex"),
		types.LuaTypeFunction(
			function(self, key, val)
				return analyzer:Assert(analyzer.curent_expression, obj:Set(key, val))
			end,
			{types.Any(), types.Any(), types.Any()},
			{}
		)
	)
	tbl:SetMetaTable(tbl)
	analyzer:PushGlobalEnvironment(analyzer.current_statement, tbl, "typesystem")
	analyzer:PushAnalyzerEnvironment("typesystem")
end]]

--[[#analyzer function PopTypeEnvironment()
	analyzer:PopAnalyzerEnvironment("typesystem")
	analyzer:PopGlobalEnvironment("typesystem")
end]] end
IMPORTS['nattlua/definitions/attest.nlua'] = function(...) --[[#local type attest = {}]]

--[[#analyzer function attest.equal(A: any, B: any)
	if not A:Equal(B) then
		error("expected " .. tostring(B) .. " got " .. tostring(A), 2)
	end

	return A
end]]

--[[#analyzer function attest.literal(A: any)
	analyzer:ErrorAssert(A:IsLiteral())
	return A
end]]

--[[#analyzer function attest.superset_of(A: any, B: any)
	analyzer:ErrorAssert(B:IsSubsetOf(A))
	return A
end]]

--[[#analyzer function attest.subset_of(A: any, B: any)
	analyzer:ErrorAssert(A:IsSubsetOf(B))
	return A
end]]

_G.attest = attest end
IMPORTS['nattlua/definitions/lua/globals.nlua'] = function(...) --[[#type @Name = "_G"]]
--[[#type setmetatable = function=(table: Table, metatable: Table | nil)>(Table)]]
--[[#type select = function=(index: number | string, ...)>(...)]]
--[[#type rawlen = function=(v: Table | string)>(number)]]
--[[#type unpack = function=(list: Table, i: number, j: number)>(...) | function=(list: Table, i: number)>(...) | function=(list: Table)>(...)]]
--[[#type require = function=(modname: string)>(any)]]
--[[#type rawset = function=(table: Table, index: any, value: any)>(Table)]]
--[[#type getmetatable = function=(object: any)>(Table | nil)]]
--[[#type type = function=(v: any)>(string)]]
--[[#type collectgarbage = function=(opt: string, arg: number)>(...) | function=(opt: string)>(...) | function=()>(...)]]
--[[#type getfenv = function=(f: empty_function | number)>(Table) | function=()>(Table)]]
--[[#type pairs = function=(t: Table)>(empty_function, Table, nil)]]
--[[#type rawequal = function=(v1: any, v2: any)>(boolean)]]
--[[#type loadfile = function=(filename: string, mode: string, env: Table)>(empty_function | nil, string | nil) | function=(filename: string, mode: string)>(empty_function | nil, string | nil) | function=(filename: string)>(empty_function | nil, string | nil) | function=()>(empty_function | nil, string | nil)]]
--[[#type dofile = function=(filename: string)>(...) | function=()>(...)]]
--[[#type ipairs = function=(t: Table)>(empty_function, Table, number)]]
--[[#type tonumber = function=(e: number | string, base: number | nil)>(number | nil)]]
_G.arg = _

--[[#analyzer function type_print(...)
	print(...)
end]]

--[[#analyzer function print(...)
	print(...)
end]]

--[[#type tostring = function=(val: any)>(string)]]

--[[#analyzer function type_assert_truthy(obj: any, err: string | nil)
	if obj:IsTruthy() then return obj end

	error(err and err:GetData() or "assertion failed")
end]]

--[[#analyzer function next(t: Map<|any, any|>, k: any)
	if t.Type == "any" then return types.Any(), types.Any() end

	if t:IsLiteral() then
		if k and not (k.Type == "symbol" and k:GetData() == nil) then
			for i, kv in ipairs(t:GetData()) do
				if kv.key:IsSubsetOf(k) then
					local kv = t:GetData()[i + 1]

					if kv then
						if not k:IsLiteral() then
							return type.Union({types.Nil(), kv.key}), type.Union({types.Nil(), kv.val})
						end

						return kv.key, kv.val
					end

					return nil
				end
			end
		else
			local kv = t:GetData() and t:GetData()[1]

			if kv then return kv.key, kv.val end
		end
	end

	if t.Type == "union" then t = t:GetData() else t = {t} end

	local k = types.Union()
	local v = types.Union()

	for _, t in ipairs(t) do
		if not t:GetData() then return types.Any(), types.Any() end

		for i, kv in ipairs(t:GetContract() and t:GetContract():GetData() or t:GetData()) do
			if kv.Type then
				k:AddType(types.Number())
				v:AddType(kv)
			else
				kv.key:SetNode(t:GetNode())
				kv.val:SetNode(t:GetNode())
				k:AddType(kv.key)
				v:AddType(kv.val)
			end
		end
	end

	return k, v
end]]

--[[#analyzer function pairs(tbl: Table)
	if tbl.Type == "table" and tbl:HasLiteralKeys() then
		local i = 1
		return function()
			local kv = tbl:GetData()[i]

			if not kv then return nil end

			i = i + 1
			local o = analyzer:GetMutatedTableValue(tbl, kv.key, kv.val)
			return kv.key, o or kv.val
		end
	end

	analyzer:PushAnalyzerEnvironment("typesystem")
	local next = analyzer:GetLocalOrGlobalValue(types.LString("next"))
	analyzer:PopAnalyzerEnvironment()
	local k, v = analyzer:CallLuaTypeFunction(analyzer.current_expression, next:GetData().lua_function, analyzer:GetScope(), tbl)
	local done = false

	if v and v.Type == "union" then v:RemoveType(types.Symbol(nil)) end

	return function()
		if done then return nil end

		done = true
		return k, v
	end
end]]

--[[#analyzer function ipairs(tbl: {[number] = any} | {})
	if tbl:IsLiteral() then
		local i = 1
		return function(key, val)
			local kv = tbl:GetData()[i]

			if not kv then return nil end

			i = i + 1
			return kv.key, kv.val
		end
	end

	if tbl.Type == "table" and not tbl:IsNumericallyIndexed() then
		analyzer:Warning(analyzer.current_expression, {tbl, " is not numerically indexed"})
		local done = false
		return function()
			if done then return nil end

			done = true
			return types.Any(), types.Any()
		end
	end

	analyzer:PushAnalyzerEnvironment("typesystem")
	local next = analyzer:GetLocalOrGlobalValue(types.LString("next"))
	analyzer:PopAnalyzerEnvironment()
	local k, v = analyzer:CallLuaTypeFunction(analyzer.current_expression, next:GetData().lua_function, analyzer:GetScope(), tbl)
	local done = false
	return function()
		if done then return nil end

		done = true

		-- v must never be nil here
		if v.Type == "union" then v = v:Copy():RemoveType(types.Symbol(nil)) end

		return k, v
	end
end]]

--[[#analyzer function require(name: string)
	if not name:IsLiteral() then return types.Any() end

	local str = name
	local base_environment = analyzer:GetDefaultEnvironment("typesystem")
	local val = base_environment:Get(str)

	if val then return val end

	local modules = {
		"table.new",
		"jit.util",
		"jit.opt",
	}

	for _, mod in ipairs(modules) do
		if str:GetData() == mod then
			local tbl

			for key in mod:gmatch("[^%.]+") do
				tbl = tbl or base_environment
				tbl = tbl:Get(types.LString(key))
			end

			-- in case it's not found
			-- TODO, add ability to configure the analyzer
			analyzer:Warning(analyzer.current_expression, "module '" .. mod .. "' might not exist")
			return tbl
		end
	end

	if analyzer:GetLocalOrGlobalValue(str) then
		return analyzer:GetLocalOrGlobalValue(str)
	end

	if package.loaders then
		for _, searcher in ipairs(package.loaders) do
			local loader = searcher(str:GetData())

			if type(loader) == "function" then
				local path = debug.getinfo(loader).source

				if path:sub(1, 1) == "@" then
					local path = path:sub(2)

					if analyzer.loaded and analyzer.loaded[path] then
						return analyzer.loaded[path]
					end

					local compiler = require("nattlua").File(analyzer:ResolvePath(path))
					assert(compiler:Lex())
					assert(compiler:Parse())
					local res = analyzer:AnalyzeRootStatement(compiler.SyntaxTree)
					analyzer.loaded = analyzer.loaded or {}
					analyzer.loaded[path] = res
					return res
				end
			end
		end
	end

	analyzer:Error(name:GetNode(), "module '" .. str:GetData() .. "' not found")
	return types.Any
end]]

--[[#analyzer function type_error(str: string, level: number | nil)
	error(str:GetData(), level and level:GetData() or nil)
end]]

--[[#analyzer function load(code: string | function=()>(string | nil), chunk_name: string | nil)
	if not code:IsLiteral() or code.Type == "union" then
		return types.Tuple(
			{
				types.Union({types.Nil(), types.AnyFunction()}),
				types.Union({types.Nil(), types.String()}),
			}
		)
	end

	local str = code:GetData()
	local compiler = nl.Compiler(str, chunk_name and chunk_name:GetData() or nil)
	assert(compiler:Lex())
	assert(compiler:Parse())
	return types.Function(
		{
			arg = types.Tuple({}),
			ret = types.Tuple({}),
			lua_function = function(...)
				return analyzer:AnalyzeRootStatement(compiler.SyntaxTree)
			end,
		}
	):SetNode(compiler.SyntaxTree)
end]]

--[[#type loadstring = load]]

--[[#analyzer function dofile(path: string)
	if not path:IsLiteral() then return types.Any() end

	local f = assert(io.open(path:GetData(), "rb"))
	local code = f:read("*all")
	f:close()
	local compiler = nl.Compiler(code, "@" .. path:GetData())
	assert(compiler:Lex())
	assert(compiler:Parse())
	return analyzer:AnalyzeRootStatement(compiler.SyntaxTree)
end]]

--[[#analyzer function loadfile(path: string)
	if not path:IsLiteral() then return types.Any() end

	local f = assert(io.open(path:GetData(), "rb"))
	local code = f:read("*all")
	f:close()
	local compiler = nl.Compiler(code, "@" .. path:GetData())
	assert(compiler:Lex())
	assert(compiler:Parse())
	return types.Function(
		{
			arg = types.Tuple({}),
			ret = types.Tuple({}),
			lua_function = function(...)
				return analyzer:AnalyzeRootStatement(compiler.SyntaxTree, ...)
			end,
		}
	):SetNode(compiler.SyntaxTree)
end]]

--[[#analyzer function rawset(tbl: {[any] = any} | {}, key: any, val: any)
	tbl:Set(key, val, true)
end]]

--[[#analyzer function rawget(tbl: {[any] = any} | {}, key: any)
	local t, err = tbl:Get(key, true)

	if t then return t end
end]]

--[[#analyzer function assert(obj: any, msg: string | nil)
	if not analyzer:IsDefinetlyReachable() then
		analyzer:ThrowSilentError(obj)

		if obj.Type == "union" then
			obj = obj:Copy()
			obj:DisableFalsy()
			return obj
		end

		return obj
	end

	if obj.Type == "union" then
		for _, tup in ipairs(obj:GetData()) do
			if tup.Type == "tuple" and tup:Get(1):IsTruthy() then return tup end
		end
	end

	if obj:IsTruthy() and not obj:IsFalsy() then
		if obj.Type == "union" then
			obj = obj:Copy()
			obj:DisableFalsy()
			return obj
		end
	end

	if obj:IsFalsy() then
		analyzer:ThrowError(msg and msg:GetData() or "assertion failed!", obj, obj:IsTruthy())

		if obj.Type == "union" then
			obj = obj:Copy()
			obj:DisableFalsy()
			return obj
		end
	end

	return obj
end]]

--[[#analyzer function error(msg: string, level: number | nil)
	if not analyzer:IsDefinetlyReachable() then
		analyzer:ThrowSilentError()
		return
	end

	if msg:IsLiteral() then
		analyzer:ThrowError(msg:GetData())
	else
		analyzer:ThrowError("error thrown from expression " .. tostring(analyzer.current_expression))
	end
end]]

--[[#analyzer function pcall(callable: function=(...any)>((...any)), ...)
	local count = #analyzer:GetDiagnostics()
	analyzer:PushProtectedCall()
	local res = analyzer:Assert(analyzer.current_statement, analyzer:Call(callable, types.Tuple({...})))
	analyzer:PopProtectedCall()
	local diagnostics = analyzer:GetDiagnostics()
	analyzer:ClearError()

	for i = count, #diagnostics do
		local diagnostic = diagnostics[i]

		if diagnostic and diagnostic.severity == "error" then
			return types.Boolean(), types.Union({types.LString(diagnostic.msg), types.Any()})
		end
	end

	return types.True(), res
end]]

--[[#analyzer function type_pcall(func: Function, ...)
	local diagnostics_index = #analyzer.diagnostics
	analyzer:PushProtectedCall()
	local tuple = analyzer:Assert(analyzer.current_statement, analyzer:Call(func, types.Tuple({...})))
	analyzer:PopProtectedCall()

	do
		local errors = {}

		for i = diagnostics_index + 1, #analyzer.diagnostics do
			local d = analyzer.diagnostics[i]
			local msg = require("nattlua.other.helpers").FormatError(analyzer.compiler:GetCode(), d.msg, d.start, d.stop)
			table.insert(errors, msg)
		end

		if errors[1] then return false, table.concat(errors, "\n") end
	end

	return true, tuple:Unpack()
end]]

--[[#analyzer function xpcall(callable: any, error_cb: any, ...)
	return analyzer:Assert(analyzer.current_statement, callable:Call(callable, types.Tuple(...), node))
end]]

--[[#analyzer function select(index: 1 .. inf | "#", ...)
	return select(index:GetData(), ...)
end]]

--[[#analyzer function type(obj: any)
	if obj.Type == "union" then
		analyzer.type_checked = obj
		local copy = types.Union()
		copy:SetUpvalue(obj:GetUpvalue())

		for _, v in ipairs(obj:GetData()) do
			if v.GetLuaType then copy:AddType(types.LString(v:GetLuaType())) end
		end

		return copy
	end

	if obj.Type == "any" then return types.String() end

	if obj.GetLuaType then return obj:GetLuaType() end

	return types.String()
end]]

--[[#function MetaTableFunctions<|T|>
	return {
		__gc = function=(T)>(),
		__pairs = function=(T)>(function=(T)>(any, any)),
		__tostring = function=(T)>(string),
		__call = function=(T, ...any)>(...any),
		__index = function=(T, key: any)>(),
		__newindex = function=(T, key: any, value: any)>(),
		__len = function=(a: T)>(number),
		__unm = function=(a: T)>(any),
		__bnot = function=(a: T)>(any),
		__add = function=(a: T, b: any)>(any),
		__sub = function=(a: T, b: any)>(any),
		__mul = function=(a: T, b: any)>(any),
		__div = function=(a: T, b: any)>(any),
		__idiv = function=(a: T, b: any)>(any),
		__mod = function=(a: T, b: any)>(any),
		__pow = function=(a: T, b: any)>(any),
		__band = function=(a: T, b: any)>(any),
		__bor = function=(a: T, b: any)>(any),
		__bxor = function=(a: T, b: any)>(any),
		__shl = function=(a: T, b: any)>(any),
		__shr = function=(a: T, b: any)>(any),
		__concat = function=(a: T, b: any)>(any),
		__eq = function=(a: T, b: any)>(boolean),
		__lt = function=(a: T, b: any)>(boolean),
		__le = function=(a: T, b: any)>(boolean),
	}
end]]

--[[#analyzer function setmetatable(tbl: Table, meta: Table | nil)
	if not meta then
		tbl:SetMetaTable()
		return
	end

	if meta.Type == "table" then
		if meta.Self then
			analyzer:Assert(tbl:GetNode(), tbl:FollowsContract(meta.Self))
			tbl:CopyLiteralness(meta.Self)
			tbl:SetContract(meta.Self)
			-- clear mutations so that when looking up values in the table they won't return their initial value
			tbl.mutations = nil
		else
			meta.potential_self = meta.potential_self or types.Union({})
			meta.potential_self:AddType(tbl)
		end

		tbl:SetMetaTable(meta)
		local metatable_functions = analyzer:CallTypesystemUpvalue(types.LString("MetaTableFunctions"), tbl)

		for _, kv in ipairs(metatable_functions:GetData()) do
			local a = kv.val
			local b = meta:Get(kv.key)

			if b and b.Type == "function" then
				local ok = analyzer:Assert(b:GetNode(), a:IsSubsetOf(b))

				if ok then

				--TODO: enrich callback types
				--b:SetReturnTypes(a:GetReturnTypes())
				--b:SetArguments(a:GetArguments())
				--b.arguments_inferred = true
				end
			end
		end
	end

	return tbl
end]]

--[[#analyzer function getmetatable(tbl: Table)
	if tbl.Type == "table" then return tbl:GetMetaTable() end
end]]

--[[#analyzer function tostring(val: any)
	if not val:IsLiteral() then return types.String() end

	if val.Type == "string" then return val end

	if val.Type == "table" then
		if val:GetMetaTable() then
			local func = val:GetMetaTable():Get(types.LString("__tostring"))

			if func then
				if func.Type == "function" then
					return analyzer:Assert(analyzer.current_expression, analyzer:Call(func, types.Tuple({val})))
				else
					return func
				end
			end
		end

		return tostring(val:GetData())
	end

	return tostring(val:GetData())
end]]

--[[#analyzer function tonumber(val: string | number, base: number | nil)
	if not val:IsLiteral() or base and not base:IsLiteral() then
		return types.Union({types.Nil(), types.Number()})
	end

	if val:IsLiteral() then
		base = base and base:IsLiteral() and base:GetData()
		return tonumber(val:GetData(), base)
	end

	return val
end]]

function _G.LSX(
	tag,
	constructor,
	props,
	children
)
	local e = constructor and
		constructor(props, children) or
		{
			props = props,
			children = children,
		}
	e.tag = tag
	return e
end end
IMPORTS['nattlua/definitions/lua/io.nlua'] = function(...) --[[#type io = {
	write = function=(...)>(nil),
	flush = function=()>(boolean | nil, string | nil),
	read = function=(...)>(...),
	lines = function=(...)>(empty_function),
	setvbuf = function=(mode: string, size: number)>(boolean | nil, string | nil) | function=(mode: string)>(boolean | nil, string | nil),
	seek = function=(whence: string, offset: number)>(number | nil, string | nil) | function=(whence: string)>(number | nil, string | nil) | function=()>(number | nil, string | nil),
}]]
--[[#type File = {
	close = function=(self)>(boolean | nil, string, number | nil),
	write = function=(self, ...)>(self | nil, string | nil),
	flush = function=(self)>(boolean | nil, string | nil),
	read = function=(self, ...)>(...),
	lines = function=(self, ...)>(empty_function),
	setvbuf = function=(self, string, number)>(boolean | nil, string | nil) | function=(file: self, mode: string)>(boolean | nil, string | nil),
	seek = function=(self, string, number)>(number | nil, string | nil) | function=(file: self, whence: string)>(number | nil, string | nil) | function=(file: self)>(number | nil, string | nil),
}]]
--[[#type io.open = function=(string, string | nil)>(File)]]
--[[#type io.popen = function=(string, string | nil)>(File)]]
--[[#type io.output = function=()>(File)]]
--[[#type io.stdout = File]]
--[[#type io.stdin = File]]
--[[#type io.stderr = File]]

--[[#analyzer function io.type(obj: any)
	local flags = types.Union()
	flags:AddType(types.LString("file"))
	flags:AddType(types.LString("closed file"))
	print(("%p"):format(obj), ("%p"):format(env.typesystem.File))

	if false and obj:IsSubsetOf(env.typesystem.File) then return flags end

	flags:AddType(types.Nil())
	return flags
end]] end
IMPORTS['nattlua/definitions/lua/luajit.nlua'] = function(...) --[[#type ffi = {
	errno = function=(nil | number)>(number),
	os = "Windows" | "Linux" | "OSX" | "BSD" | "POSIX" | "Other",
	arch = "x86" | "x64" | "arm" | "ppc" | "ppcspe" | "mips",
	C = {},
	cdef = function=(string)>(nil),
	abi = function=(string)>(boolean),
	metatype = function=(ctype, Table)>(cdata),
	new = function=(string | ctype, number | nil, ...any)>(cdata),
	copy = function=(any, any, number | nil)>(nil),
	alignof = function=(ctype)>(number),
	cast = function=(ctype | string, cdata | string | number)>(cdata),
	typeof = function=(ctype, ...any)>(ctype),
	load = function=(string, boolean)>(userdata) | function=(string)>(userdata),
	sizeof = function=(ctype, number)>(number) | function=(ctype)>(number),
	string = function=(cdata, number | nil)>(string),
	gc = function=(ctype, empty_function)>(cdata),
	istype = function=(ctype, any)>(boolean),
	fill = function=(cdata, number, any)>(nil) | function=(cdata, len: number)>(nil),
	offsetof = function=(cdata, number)>(number),
}]]
--[[#type ffi.C.@Name = "FFI_C"]]
--[[#type jit = {
	os = ffi.os,
	arch = ffi.arch,
	attach = function=(empty_function, string)>(nil),
	flush = function=()>(nil),
	opt = {start = function=(...)>(nil)},
	tracebarrier = function=()>(nil),
	version_num = number,
	version = string,
	on = function=(empty_function | true, boolean | nil)>(nil),
	off = function=(empty_function | true, boolean | nil)>(nil),
	flush = function=(empty_function | true, boolean | nil)>(nil),
	status = function=()>(boolean, ...string),
	opt = {
		start = function=(...string)>(nil),
		stop = function=()>(nil),
	},
	util = {
		funcinfo = function=(empty_function, position: number | nil)>(
			{
				linedefined = number, -- as for debug.getinfo
				lastlinedefined = number, -- as for debug.getinfo
				params = number, -- the number of parameters the function takes
				stackslots = number, -- the number of stack slots the function's local variable use
				upvalues = number, -- the number of upvalues the function uses
				bytecodes = number, -- the number of bytecodes it the compiled function
				gcconsts = number, -- the number of garbage collectable constants
				nconsts = number, -- the number of lua_Number (double) constants
				children = boolean, -- Boolean representing whether the function creates closures
				currentline = number, -- as for debug.getinfo
				isvararg = boolean, -- if the function is a vararg function
				source = string, -- as for debug.getinfo
				loc = string, -- a string describing the source and currentline, like "<source>:<line>"
				ffid = number, -- the fast function id of the function (if it is one). In this case only upvalues above and addr below are valid
				addr = any, -- the address of the function (if it is not a Lua function). If it's a C function rather than a fast function, only upvalues above is valid*
			}
		),
	},
}]] end
IMPORTS['nattlua/definitions/lua/debug.nlua'] = function(...) --[[#type debug_getinfo = {
	name = string,
	namewhat = string,
	source = string,
	short_src = string,
	linedefined = number,
	lastlinedefined = number,
	what = string,
	currentline = number,
	istailcall = boolean,
	nups = number,
	nparams = number,
	isvararg = boolean,
	func = any,
	activelines = {[number] = boolean},
}]]
--[[#type debug = {
	sethook = function=(thread: thread, hook: empty_function, mask: string, count: number)>(nil) | function=(thread: thread, hook: empty_function, mask: string)>(nil) | function=(hook: empty_function, mask: string)>(nil),
	getregistry = function=()>(nil),
	traceback = function=(thread: thread, message: any, level: number)>(string) | function=(thread: thread, message: any)>(string) | function=(thread: thread)>(string) | function=()>(string),
	setlocal = function=(thread: thread, level: number, local_: number, value: any)>(string | nil) | function=(level: number, local_: number, value: any)>(string | nil),
	getinfo = function=(thread: thread, f: empty_function | number, what: string)>(debug_getinfo | nil) | function=(thread: thread, f: empty_function | number)>(debug_getinfo | nil) | function=(f: empty_function | number)>(debug_getinfo | nil),
	upvalueid = function=(f: empty_function, n: number)>(userdata),
	setupvalue = function=(f: empty_function, up: number, value: any)>(string | nil),
	getlocal = function=(thread: thread, f: number | empty_function, local_: number)>(string | nil, any) | function=(f: number | empty_function, local_: number)>(string | nil, any),
	upvaluejoin = function=(f1: empty_function, n1: number, f2: empty_function, n2: number)>(nil),
	getupvalue = function=(f: empty_function, up: number)>(string | nil, any),
	getmetatable = function=(value: any)>(Table | nil),
	setmetatable = function=(value: any, Table: Table | nil)>(any),
	gethook = function=(thread: thread)>(empty_function, string, number) | function=()>(empty_function, string, number),
	getuservalue = function=(u: userdata)>(Table | nil),
	debug = function=()>(nil),
	getfenv = function=(o: any)>(Table),
	setfenv = function=(object: any, Table: Table)>(any),
	setuservalue = function=(udata: userdata, value: Table | nil)>(userdata),
}]]

--[[#analyzer function debug.setfenv(val: Function, table: Table)
	if val and (val:IsLiteral() or val.Type == "function") then
		if val.Type == "number" then
			analyzer:SetEnvironmentOverride(analyzer.environment_nodes[val:GetData()], table, "runtime")
		elseif val:GetNode() then
			analyzer:SetEnvironmentOverride(val:GetNode(), table, "runtime")
		end
	end
end]]

--[[#analyzer function debug.getfenv(func: Function)
	return analyzer:GetGlobalEnvironmentOverride(func.function_body_node or func, "runtime")
end]]

--[[#type getfenv = debug.getfenv]]
--[[#type setfenv = debug.setfenv]] end
IMPORTS['nattlua/definitions/lua/package.nlua'] = function(...) --[[#type package = {
	searchpath = function=(name: string, path: string, sep: string, rep: string)>(string | nil, string | nil) | function=(name: string, path: string, sep: string)>(string | nil, string | nil) | function=(name: string, path: string)>(string | nil, string | nil),
	seeall = function=(module: Table)>(nil),
	loadlib = function=(libname: string, funcname: string)>(empty_function | nil),
	config = "/\n;\n?\n!\n-\n",
}]] end
IMPORTS['nattlua/definitions/lua/bit.nlua'] = function(...) --[[#type bit32 = {
	lrotate = function=(x: number, disp: number)>(number),
	bor = function=(...)>(number),
	rshift = function=(x: number, disp: number)>(number),
	band = function=(...)>(number),
	lshift = function=(x: number, disp: number)>(number),
	rrotate = function=(x: number, disp: number)>(number),
	replace = function=(n: number, v: number, field: number, width: number)>(number) | function=(n: number, v: number, field: number)>(number),
	bxor = function=(...)>(number),
	arshift = function=(x: number, disp: number)>(number),
	extract = function=(n: number, field: number, width: number)>(number) | function=(n: number, field: number)>(number),
	bnot = function=(x: number)>(number),
	btest = function=(...)>(boolean),
	tobit = function=(...)>(number),
}]]
--[[#type bit = bit32]]

do
	--[[#analyzer function bit.bor(...)
		local out = {}

		for i, num in ipairs({...}) do
			if not num:IsLiteral() then return types.Number() end

			out[i] = num:GetData()
		end

		return bit.bor(table.unpack(out))
	end]]

	--[[#analyzer function bit.band(...)
		local out = {}

		for i, num in ipairs({...}) do
			if not num:IsLiteral() then return types.Number() end

			out[i] = num:GetData()
		end

		return bit.band(table.unpack(out))
	end]]

	--[[#analyzer function bit.bxor(...)
		local out = {}

		for i, num in ipairs({...}) do
			if not num:IsLiteral() then return types.Number() end

			out[i] = num:GetData()
		end

		return bit.bxor(table.unpack(out))
	end]]

	--[[#analyzer function bit.tobit(n: number)
		if n:IsLiteral() then return bit.tobit(n:GetData()) end

		return types.Number()
	end]]

	--[[#analyzer function bit.bnot(n: number)
		if n:IsLiteral() then return bit.bnot(n:GetData()) end

		return types.Number()
	end]]

	--[[#analyzer function bit.bswap(n: number)
		if n:IsLiteral() then return bit.bswap(n:GetData()) end

		return types.Number()
	end]]

	--[[#analyzer function bit.tohex(x: number, n: number)
		if x:IsLiteral() and n:IsLiteral() then
			return bit.tohex(x:GetData(), n:GetData())
		end

		return types.String()
	end]]

	--[[#analyzer function bit.lshift(x: number, n: number)
		if x:IsLiteral() and n:IsLiteral() then
			return bit.lshift(x:GetData(), n:GetData())
		end

		return types.Number()
	end]]

	--[[#analyzer function bit.rshift(x: number, n: number)
		if x:IsLiteral() and n:IsLiteral() then
			return bit.rshift(x:GetData(), n:GetData())
		end

		return types.Number()
	end]]

	--[[#analyzer function bit.arshift(x: number, n: number)
		if x:IsLiteral() and n:IsLiteral() then
			return bit.arshift(x:GetData(), n:GetData())
		end

		return types.Number()
	end]]

	--[[#analyzer function bit.rol(x: number, n: number)
		if x:IsLiteral() and n:IsLiteral() then
			return bit.rol(x:GetData(), n:GetData())
		end

		return types.Number()
	end]]

	--[[#analyzer function bit.ror(x: number, n: number)
		if x:IsLiteral() and n:IsLiteral() then
			return bit.ror(x:GetData(), n:GetData())
		end

		return types.Number()
	end]]
end end
IMPORTS['nattlua/definitions/lua/table.nlua'] = function(...) --[[#type table = {
	maxn = function=(table: Table)>(number),
	move = function=(a1: Table, f: any, e: any, t: any, a2: Table)>(nil) | function=(a1: Table, f: any, e: any, t: any)>(nil),
	remove = function=(list: Table, pos: number)>(any) | function=(list: Table)>(any),
	sort = function=(list: Table, comp: empty_function)>(nil) | function=(list: Table)>(nil),
	unpack = function=(list: Table, i: number, j: number)>(...) | function=(list: Table, i: number)>(...) | function=(list: Table)>(...),
	insert = function=(list: Table, pos: number, value: any)>(nil) | function=(list: Table, value: any)>(nil),
	concat = function=(list: Table, sep: string, i: number, j: number)>(string) | function=(list: Table, sep: string, i: number)>(string) | function=(list: Table, sep: string)>(string) | function=(list: Table)>(string),
	pack = function=(...)>(Table),
	new = function=(number, number)>({[number] = any}),
}]]

--[[#analyzer function table.concat(tbl: List<|string|>, separator: string | nil)
	if not tbl:IsLiteral() then return types.String() end

	if separator and (separator.Type ~= "string" or not separator:IsLiteral()) then
		return types.String()
	end

	local out = {}

	for i, keyval in ipairs(tbl:GetData()) do
		if not keyval.val:IsLiteral() or keyval.val.Type == "union" then
			return types.String()
		end

		out[i] = keyval.val:GetData()
	end

	return table.concat(out, separator and separator:GetData() or nil)
end]]

--[[#analyzer function table.insert(tbl: List<|any|>, ...)
	if not tbl:HasLiteralKeys() then return end

	local pos, val = ...

	if not val then
		val = pos
		pos = tbl:GetLength(analyzer)

		if pos:IsLiteral() then
			pos:SetData(pos:GetData() + 1)
			local max = pos:GetMax()

			if max then max:SetData(max:GetData() + 1) end
		end
	else
		pos = tbl:GetLength(analyzer)
	end

	if analyzer:IsInUncertainLoop() then pos:Widen() end

	assert(type(pos) ~= "number")
	analyzer:NewIndexOperator(analyzer.current_expression, tbl, pos, val)
end]]

--[[#analyzer function table.remove(tbl: List<|any|>, index: number | nil)
	if not tbl:IsLiteral() then return end

	if index and not index:IsLiteral() then return end

	index = index or 1
	table.remove(pos:GetData(), index:GetData())
end]]

--[[#analyzer function table.sort(tbl: List<|any|>, func: function=(a: any, b: any)>(boolean))
	local union = types.Union()

	if tbl.Type == "tuple" then
		for i, v in ipairs(tbl:GetData()) do
			union:AddType(v)
		end
	elseif tbl.Type == "table" then
		for i, v in ipairs(tbl:GetData()) do
			union:AddType(v.val)
		end
	end

	func:GetArguments():GetData()[1] = union
	func:GetArguments():GetData()[2] = union
	func.arguments_inferred = true
end]]

--[[#analyzer function table.getn(tbl: List<|any|>)
	return tbl:GetLength()
end]]

--[[#analyzer function table.unpack(tbl: List<|any|>)
	local t = {}

	for i = 1, 32 do
		local v = tbl:Get(types.LNumber(i))

		if not v then break end

		t[i] = v
	end

	return table.unpack(t)
end]]

--[[#type unpack = table.unpack]]

function table.destructure(tbl, fields, with_default)
	local out = {}

	for i, key in ipairs(fields) do
		out[i] = tbl[key]
	end

	if with_default then table.insert(out, 1, tbl) end

	return table.unpack(out)
end

function table.mergetables(tables)
	local out = {}

	for i, tbl in ipairs(tables) do
		for k, v in pairs(tbl) do
			out[k] = v
		end
	end

	return out
end

function table.spread(tbl)
	if not tbl then return nil end

	return table.unpack(tbl)
end end
IMPORTS['nattlua/definitions/lua/string.nlua'] = function(...) --[[#type string = {
	find = function=(s: string, pattern: string, init: number | nil, plain: boolean | nil)>(number | nil, number | nil, ...string),
	len = function=(s: string)>(number),
	packsize = function=(fmt: string)>(number),
	match = function=(s: string, pattern: string, init: number | nil)>(...string),
	upper = function=(s: string)>(string),
	sub = function=(s: string, i: number, j: number)>(string) | function=(s: string, i: number)>(string),
	char = function=(...)>(string),
	rep = function=(s: string, n: number, sep: string)>(string) | function=(s: string, n: number)>(string),
	lower = function=(s: string)>(string),
	dump = function=(empty_function: empty_function)>(string),
	gmatch = function=(s: string, pattern: string)>(empty_function),
	reverse = function=(s: string)>(string),
	byte = function=(s: string, i: number | nil, j: number | nil)>(...number),
	unpack = function=(fmt: string, s: string, pos: number | nil)>(...any),
	gsub = function=(s: string, pattern: string, repl: string | Table | empty_function, n: number | nil)>(string, number),
	format = function=(string, ...any)>(string),
	pack = function=(fmt: string, ...any)>(string),
}]]

--[[#analyzer function ^string.rep(str: string, n: number)
	if str:IsLiteral() and n:IsLiteral() then
		return types.LString(string.rep(str:GetData(), n:GetData()))
	end

	return types.String()
end]]

--[[#analyzer function ^string.char(...)
	local out = {}

	for i, num in ipairs({...}) do
		if not num:IsLiteral() then return types.String() end

		out[i] = num:GetData()
	end

	return string.char(table.unpack(out))
end]]

--[[#analyzer function ^string.format(s: string, ...)
	if not s:IsLiteral() then return types.String() end

	local ret = {...}

	for i, v in ipairs(ret) do
		if v:IsLiteral() and (v.Type == "string" or v.Type == "number") then
			ret[i] = v:GetData()
		else
			return types.String()
		end
	end

	return string.format(s:GetData(), table.unpack(ret))
end]]

--[[#analyzer function ^string.gmatch(s: string, pattern: string)
	if s:IsLiteral() and pattern:IsLiteral() then
		local f = s:GetData():gmatch(pattern:GetData())
		local i = 1
		return function()
			local strings = {f()}

			if strings[1] then
				for i, v in ipairs(strings) do
					strings[i] = types.LString(v)
				end

				return types.Tuple(strings)
			end
		end
	end

	if pattern:IsLiteral() then
		local _, count = pattern:GetData():gsub("%b()", "")
		local done = false
		return function()
			if done then return end

			done = true
			return types.Tuple({types.String()}):SetRepeat(count)
		end
	end

	local done = false
	return function()
		if done then return end

		done = true
		return types.String()
	end
end]]

--[[#analyzer function ^string.lower(str: string)
	if str:IsLiteral() then return str:GetData():lower() end

	return types.String()
end]]

--[[#analyzer function ^string.upper(str: string)
	if str:IsLiteral() then return str:GetData():upper() end

	return types.String()
end]]

--[[#analyzer function ^string.sub(str: string, a: number, b: number | nil)
	if str:IsLiteral() and a:IsLiteral() then
		if b and b:IsLiteral() then
			return str:GetData():sub(a:GetData(), b:GetData())
		end

		return str:GetData():sub(a:GetData())
	end

	return types.String()
end]]

--[[#analyzer function ^string.byte(str: string, from: number | nil, to: number | nil)
	if str:IsLiteral() and not from and not to then
		return string.byte(str:GetData())
	end

	if str:IsLiteral() and from and from:IsLiteral() and not to then
		return string.byte(str:GetData(), from:GetData())
	end

	if str:IsLiteral() and from and from:IsLiteral() and to and to:IsLiteral() then
		return string.byte(str:GetData(), from:GetData(), to:GetData())
	end

	if from and from:IsLiteral() and to and to:IsLiteral() then
		return types.Tuple({}):AddRemainder(types.Tuple({types.Number()}):SetRepeat(to:GetData() - from:GetData() + 1))
	end

	return types.Tuple({}):AddRemainder(types.Tuple({types.Number()}):SetRepeat(math.huge))
end]]

--[[#analyzer function ^string.match(str: string, pattern: string, start_position: number | nil)
	str = str:IsLiteral() and str:GetData()
	pattern = pattern:IsLiteral() and pattern:GetData()
	start_position = start_position and
		start_position:IsLiteral() and
		start_position:GetData() or
		1

	if not str or not pattern then
		return types.Tuple({types.Union({types.String(), types.Nil()})}):SetRepeat(math.huge)
	end

	local res = {str:match(pattern, start_position)}

	for i, v in ipairs(res) do
		if type(v) == "string" then
			res[i] = types.LString(v)
		else
			res[i] = types.LNumber(v)
		end
	end

	return table.unpack(res)
end]]

--[[#analyzer function ^string.find(str: string, pattern: string, start_position: number | nil, no_pattern: boolean | nil)
	str = str:IsLiteral() and str:GetData()
	pattern = pattern:IsLiteral() and pattern:GetData()
	start_position = start_position and
		start_position:IsLiteral() and
		start_position:GetData() or
		1
	no_pattern = no_pattern and no_pattern:IsLiteral() and no_pattern:GetData() or false

	if not str or not pattern then
		return types.Tuple(
			{
				types.Union({types.Number(), types.Nil()}),
				types.Union({types.Number(), types.Nil()}),
				types.Union({types.String(), types.Nil()}),
			}
		)
	end

	local start, stop, found = str:find(pattern, start_position, no_pattern)

	if found then types.LString(found) end

	return start, stop, found
end]]

--[[#analyzer function ^string.len(str: string)
	if str:IsLiteral() then return types.LNumber(#str:GetData()) end

	return types.Number()
end]]

--[[#analyzer function ^string.gsub(
	str: string,
	pattern: string,
	replacement: function=(...string)>((...string)) | string | {[string] = string},
	max_replacements: number | nil
)
	str = str:IsLiteral() and str:GetData()
	pattern = pattern:IsLiteral() and pattern:GetData()

	if replacement.Type == "string" then
		if replacement:IsLiteral() then replacement = replacement:GetData() end
	elseif replacement.Type == "table" then
		local out = {}

		for _, kv in ipairs(replacement:GetData()) do
			if kv.key:IsLiteral() and kv.val:IsLiteral() then
				out[kv.key:GetData()] = kv.val:GetData()
			end
		end

		replacement = out
	end

	max_replacements = max_replacements and max_replacements:GetData()

	if str and pattern and replacement then
		--replacement:SetArguments(types.Tuple({types.String()}):SetRepeat(math.huge))
		if type(replacement) == "string" or type(replacement) == "table" then
			return string.gsub(str, pattern, replacement, max_replacements)
		else
			return string.gsub(
				str,
				pattern,
				function(...)
					analyzer:Assert(
						replacement:GetNode(),
						analyzer:Call(replacement, analyzer:LuaTypesToTuple(replacement:GetNode(), {...}))
					)
				end,
				max_replacements
			)
		end
	end

	return types.String(), types.Number()
end]] end
IMPORTS['nattlua/definitions/lua/math.nlua'] = function(...) --[[#type math = {
	ceil = function=(x: number)>(number),
	tan = function=(x: number)>(number),
	log10 = function=(x: number)>(number),
	sinh = function=(x: number)>(number),
	ldexp = function=(m: number, e: number)>(number),
	tointeger = function=(x: number)>(number),
	cosh = function=(x: number)>(number),
	min = function=(x: number, ...)>(number),
	fmod = function=(x: number, y: number)>(number),
	exp = function=(x: number)>(number),
	random = function=(m: number, n: number)>(number) | function=(m: number)>(number) | function=()>(number),
	rad = function=(x: number)>(number),
	log = function=(x: number, base: number)>(number) | function=(x: number)>(number),
	cos = function=(x: number)>(number),
	randomseed = function=(x: number)>(nil),
	floor = function=(x: number)>(number),
	tanh = function=(x: number)>(number),
	max = function=(x: number, ...)>(number),
	pow = function=(x: number, y: number)>(number),
	ult = function=(m: number, n: number)>(boolean),
	acos = function=(x: number)>(number),
	type = function=(x: number)>(string),
	abs = function=(x: number)>(number),
	frexp = function=(x: number)>(number, number),
	deg = function=(x: number)>(number),
	modf = function=(x: number)>(number, number),
	atan2 = function=(y: number, x: number)>(number),
	asin = function=(x: number)>(number),
	atan = function=(x: number)>(number),
	sqrt = function=(x: number)>(number),
	sin = function=(x: number)>(number),
}]]
--[[#type math.huge = inf]]
--[[#type math.pi = 3.14159265358979323864338327950288]]

--[[#analyzer function math.sin(n: number)
	return n:IsLiteral() and math.sin(n:GetData()) or types.Number()
end]]

--[[#analyzer function math.cos(n: number)
	return n:IsLiteral() and math.cos(n:GetData()) or types.Number()
end]]

--[[#analyzer function math.ceil(n: number)
	return n:IsLiteral() and math.ceil(n:GetData()) or types.Number()
end]]

--[[#analyzer function math.floor(n: number)
	return n:IsLiteral() and math.floor(n:GetData()) or types.Number()
end]]

--[[#analyzer function math.min(...)
	local numbers = {}

	for i = 1, select("#", ...) do
		local obj = select(i, ...)

		if not obj:IsLiteral() then
			return types.Number()
		else
			numbers[i] = obj:GetData()
		end
	end

	return math.min(table.unpack(numbers))
end]]

--[[#analyzer function math.max(...)
	local numbers = {}

	for i = 1, select("#", ...) do
		local obj = select(i, ...)

		if not obj:IsLiteral() then
			return types.Number()
		else
			numbers[i] = obj:GetData()
		end
	end

	return math.max(table.unpack(numbers))
end]] end
IMPORTS['nattlua/definitions/lua/os.nlua'] = function(...) --[[#type os = {
	execute = function=(command: string)>(boolean | nil, string, number | nil) | function=()>(boolean | nil, string, number | nil),
	rename = function=(oldname: string, newname: string)>(boolean | nil, string, number | nil),
	getenv = function=(varname: string)>(string | nil),
	difftime = function=(t2: number, t1: number)>(number),
	exit = function=(code: boolean | number, close: boolean)>(nil) | function=(code: boolean | number)>(nil) | function=()>(nil),
	remove = function=(filename: string)>(boolean | nil, string, number | nil),
	setlocale = function=(local_e: string, category: string)>(string | nil) | function=(local_e: string)>(string | nil),
	date = function=(format: string, time: number)>(string | Table) | function=(format: string)>(string | Table) | function=()>(string | Table),
	time = function=(table: Table)>(number) | function=()>(number),
	clock = function=()>(number),
	tmpname = function=()>(string),
}]] end
IMPORTS['nattlua/definitions/lua/coroutine.nlua'] = function(...) --[[#type coroutine = {
	create = function=(empty_function)>(thread),
	close = function=(thread)>(boolean, string),
	isyieldable = function=()>(boolean),
	resume = function=(thread, ...)>(boolean, ...),
	running = function=()>(thread, boolean),
	status = function=(thread)>(string),
	wrap = function=(empty_function)>(empty_function),
	yield = function=(...)>(...),
}]]

--[[#analyzer function coroutine.yield(...)
	analyzer.yielded_results = {...}
end]]

--[[#analyzer function coroutine.resume(thread: any, ...)
	if thread.Type == "any" then
		-- TODO: thread is untyped, when inferred
		return types.Boolean()
	end

	if not thread.co_func then
		error(tostring(thread) .. " is not a thread!", 2)
	end

	analyzer:Call(thread.co_func, types.Tuple({...}))
	return types.Boolean()
end]]

--[[#analyzer function coroutine.create(func: Function, ...)
	local t = types.Table()
	t.co_func = func
	return t
end]]

--[[#analyzer function coroutine.wrap(cb: Function)
	return function(...)
		analyzer:Call(cb, types.Tuple({...}))
		local res = analyzer.yielded_results

		if res then
			analyzer.yielded_results = nil
			return table.unpack(res)
		end
	end
end]] end
IMPORTS['nattlua/definitions/typed_ffi.nlua'] = function(...) --[[#local analyzer function (node: any, args: any)
	local table_print = require("nattlua.other.table_print")
	local cast = env.typesystem.cast

	local function cdata_metatable(from, const)
		local meta = types.Table()
		meta:Set(
			types.LString("__index"),
			types.LuaTypeFunction(
				function(self, key)
					-- i'm not really sure about this
					-- boxed luajit ctypes seem to just get the metatable from the ctype
					return analyzer:Assert(key:GetNode(), from:Get(key, from.Type == "union"))
				end,
				{types.Any(), types.Any()},
				{}
			)
		)

		if const then
			meta:Set(
				types.LString("__newindex"),
				types.LuaTypeFunction(
					function(self, key, value)
						error("attempt to write to constant location")
					end,
					{types.Any(), types.Any(), types.Any()},
					{}
				)
			)
		end

		meta:Set(
			types.LString("__add"),
			types.LuaTypeFunction(function(self, key)
				return self
			end, {types.Any(), types.Any()}, {})
		)
		meta:Set(
			types.LString("__sub"),
			types.LuaTypeFunction(function(self, key)
				return self
			end, {types.Any(), types.Any()}, {})
		)
		return meta
	end

	if node.tag == "Struct" or node.tag == "Union" then
		local tbl = types.Table()

		if node.n then
			tbl.ffi_name = "struct " .. node.n
			analyzer.current_tables = analyzer.current_tables or {}
			table.insert(analyzer.current_tables, tbl)
		end

		for _, node in ipairs(node) do
			if node.tag == "Pair" then
				local key = types.LString(node[2])
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
				table.insert(
					arguments,
					types.Tuple({}):AddRemainder(types.Tuple({types.Any()}):SetRepeat(math.huge))
				)
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
			local ptr = types.Table()
			ptr:Set(types.Number(), types.Number())
			return_type = types.Union({ptr, types.Nil()})
		else
			return_type = cast(node.t, args)
		end

		local obj = types.Function({
			ret = types.Tuple({return_type}),
			arg = types.Tuple(arguments),
		})
		obj:SetNode(analyzer.current_expression)
		return obj
	elseif node.tag == "Array" then
		local tbl = types.Table()
		-- todo node.size: array length
		_G.FUNCTION_ARGUMENT = true
		local t = cast(node.t, args)
		_G.FUNCTION_ARGUMENT = nil
		tbl:Set(types.Number(), t)
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
			node.n == "size_t"
		then
			return types.Number()
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
			return types.Number()
		elseif node.n == "bool" or node.n == "_Bool" then
			return types.Boolean()
		elseif node.n == "void" then
			return types.Nil()
		elseif node.n == "va_list" then
			return types.Tuple({}):AddRemainder(types.Tuple({types.Any()}):SetRepeat(math.huge))
		elseif node.n:find("%$%d+%$") then
			local val = table.remove(args, 1)

			if not val then error("unable to lookup type $ #" .. (#args + 1), 2) end

			return val
		elseif node.parent and node.parent.tag == "TypeDef" then
			if node.n:sub(1, 6) == "struct" then
				local name = node.n:sub(7)
				local tbl = types.Table()
				tbl:SetName(types.LString(name))
				return tbl
			end
		else
			local val = analyzer:IndexOperator(
				analyzer.current_expression,
				env.typesystem.ffi:Get(types.LString("C")),
				types.LString(node.n)
			)

			if not val or val.Type == "symbol" and val:GetData() == nil then
				if analyzer.current_tables then
					local current_tbl = analyzer.current_tables[#analyzer.current_tables]

					if current_tbl and current_tbl.ffi_name == node.n then return current_tbl end
				end

				analyzer:Error(analyzer.current_expression, "cannot find value " .. node.n)
				return types.Any()
			end

			return val
		end
	elseif node.tag == "Qualified" then
		return cast(node.t, args)
	elseif node.tag == "Pointer" then
		if node.t.tag == "Type" and node.t.n == "void" then return types.Any() end

		local ptr = types.Table()
		local ctype = cast(node.t, args)
		ptr:Set(types.Number(), ctype)
		local meta = cdata_metatable(ctype, node.t.const)
		ptr:SetMetaTable(meta)

		if node.t.tag == "Qualified" and node.t.t.n == "char" then
			ptr:Set(types.Number(), ctype)
			ptr:SetName(types.LString("const char*"))

			if _G.FUNCTION_ARGUMENT then
				return types.Union({ptr, types.String(), types.Nil()})
			end

			return ptr
		end

		if node.t.tag == "Type" and node.t.n:sub(1, 1) ~= "$" then
			ptr:SetName(types.LString(node.t.n .. "*"))
		end

		return types.Union({ptr, types.Nil()})
	else
		table_print(node)
		error("NYI: " .. node.tag)
	end
end]]

--[[#analyzer function ffi.cdef(cdecl: string, ...)
	assert(cdecl:IsLiteral(), "cdecl must be a string literal")

	for _, ctype in ipairs(assert(require("nattlua.other.cparser").parseString(cdecl:GetData(), {}, {...}))) do
		ctype.type.parent = ctype
		analyzer:NewIndexOperator(
			cdecl:GetNode(),
			env.typesystem.ffi:Get(types.LString("C")),
			types.LString(ctype.name),
			env.typesystem.cast(ctype.type, {...})
		)
	end
end]]

--[[#§env.typesystem.ffi:Get(types.LString("cdef")).no_expansion = true]]

--[[#analyzer function ffi.cast(cdecl: string, src: any)
	assert(cdecl:IsLiteral(), "cdecl must be a string literal")
	local declarations = assert(require("nattlua.other.cparser").parseString(cdecl:GetData(), {typeof = true}))
	local ctype = env.typesystem.cast(declarations[#declarations].type)

	-- TODO, this tries to extract cdata from cdata | nil, since if we cast a valid pointer it cannot be invalid when returned
	if ctype.Type == "union" then
		for _, v in ipairs(ctype:GetData()) do
			if v.Type == "table" then
				ctype = v

				break
			end
		end
	end

	ctype:SetNode(cdecl:GetNode())

	if ctype.Type == "any" then return ctype end

	local nilable_ctype = ctype:Copy()

	for _, keyval in ipairs(nilable_ctype:GetData()) do
		keyval.val = types.Nilable(keyval.val)
	end

	ctype:SetMetaTable(ctype)
	return ctype
end]]

--[[#analyzer function ffi.typeof(cdecl: string, ...)
	assert(cdecl:IsLiteral(), "c_declaration must be a string literal")
	local declarations = assert(require("nattlua.other.cparser").parseString(cdecl:GetData(), {typeof = true}, {...}))
	local ctype = env.typesystem.cast(declarations[#declarations].type, {...})

	-- TODO, this tries to extract cdata from cdata | nil, since if we cast a valid pointer it cannot be invalid when returned
	if ctype.Type == "union" then
		for _, v in ipairs(ctype:GetData()) do
			if v.Type == "table" then
				ctype = v

				break
			end
		end
	end

	ctype:SetNode(cdecl:GetNode())

	if ctype.Type == "any" then return ctype end

	local nilable_ctype = ctype:Copy()

	for _, keyval in ipairs(nilable_ctype:GetData()) do
		keyval.val = types.Nilable(keyval.val)
	end

	local old = ctype:GetContract()
	ctype:SetContract()
	ctype:Set(
		types.LString("__call"),
		types.LuaTypeFunction(
			function(self, init)
				if init then
					analyzer:Assert(init:GetNode(), init:IsSubsetOf(nilable_ctype))
				end

				return self:Copy()
			end,
			{ctype, types.Nilable(nilable_ctype)},
			{ctype}
		)
	)
	ctype:SetMetaTable(ctype)
	ctype:SetContract(old)
	return ctype
end]]

--[[#§env.typesystem.ffi:Get(types.LString("typeof")).no_expansion = true]]

--[[#analyzer function ffi.get_type(cdecl: string, ...)
	assert(cdecl:IsLiteral(), "c_declaration must be a string literal")
	local declarations = assert(require("nattlua.other.cparser").parseString(cdecl:GetData(), {typeof = true}, {...}))
	local ctype = env.typesystem.cast(declarations[#declarations].type, {...})
	ctype:SetNode(cdecl:GetNode())
	return ctype
end]]

--[[#analyzer function ffi.new(cdecl: any, ...)
	local declarations = assert(require("nattlua.other.cparser").parseString(cdecl:GetData(), {ffinew = true}, {...}))
	local ctype = env.typesystem.cast(declarations[#declarations].type, {...})
	return ctype
end]]

--[[#analyzer function ffi.metatype(ctype: any, meta: any)
	local new = meta:Get(types.LString("__new"))

	if new then
		meta:Set(
			types.LString("__call"),
			types.LuaTypeFunction(
				function(self, ...)
					local val = analyzer:Assert(analyzer.current_expression, analyzer:Call(new, types.Tuple({ctype, ...}))):Unpack()

					if val.Type == "union" then
						for i, v in ipairs(val:GetData()) do
							if v.Type == "table" then v:SetMetaTable(meta) end
						end
					else
						val:SetMetaTable(meta)
					end

					return val
				end,
				new:GetArguments():GetData(),
				new:GetReturnTypes():GetData()
			)
		)
	end

	ctype:SetMetaTable(meta)
end]]

--[[#analyzer function ffi.load(lib: string)
	return env.typesystem.ffi:Get(types.LString("C"))
end]]

--[[#analyzer function ffi.gc(ctype: any, callback: Function)
	return ctype
end]] end
IMPORTS['nattlua/definitions/index.nlua'] = function(...) do
	local nl = {}
	nl.imports = nl.imports or {}

	function _G.import(path)
		return nl.imports[path]
	end

	_G.nl = nl
end

IMPORTS['nattlua/definitions/utility.nlua']("./utility.nlua")
IMPORTS['nattlua/definitions/attest.nlua']("./attest.nlua")
IMPORTS['nattlua/definitions/lua/globals.nlua']("./lua/globals.nlua")
IMPORTS['nattlua/definitions/lua/io.nlua']("./lua/io.nlua")
IMPORTS['nattlua/definitions/lua/luajit.nlua']("./lua/luajit.nlua")
IMPORTS['nattlua/definitions/lua/debug.nlua']("./lua/debug.nlua")
IMPORTS['nattlua/definitions/lua/package.nlua']("./lua/package.nlua")
IMPORTS['nattlua/definitions/lua/bit.nlua']("./lua/bit.nlua")
IMPORTS['nattlua/definitions/lua/table.nlua']("./lua/table.nlua")
IMPORTS['nattlua/definitions/lua/string.nlua']("./lua/string.nlua")
IMPORTS['nattlua/definitions/lua/math.nlua']("./lua/math.nlua")
IMPORTS['nattlua/definitions/lua/os.nlua']("./lua/os.nlua")
IMPORTS['nattlua/definitions/lua/coroutine.nlua']("./lua/coroutine.nlua")
IMPORTS['nattlua/definitions/typed_ffi.nlua']("./typed_ffi.nlua") end
IMPORTS['examples/projects/luajit/src/platforms/filesystem.nlua'] = function(...) --[[#local type FileStat = {
	last_accessed = number,
	last_changed = number,
	last_modified = number,
	size = number,
	type = "directory" | "file",
}]]
--[[#local type fs_contract = {
	get_attributes = function=(string, false | nil | true)>(ErrorReturn<|FileStat|>),
	get_files = function=(string)>(ErrorReturn<|List<|string|>|>),
	set_current_directory = function=(string)>(ErrorReturn<|true|>),
	get_current_directory = function=()>(ErrorReturn<|string|>),
}]]
return fs_contract end
IMPORTS['examples/projects/luajit/src/platforms/windows/filesystem.nlua'] = function(...) --[[#local type contract = IMPORTS['examples/projects/luajit/src/platforms/filesystem.nlua']("~/platforms/filesystem.nlua")]]
local ffi = require("ffi")
local OSX = ffi.os == "OSX"
local X64 = ffi.arch == "x64"
local fs = {}
ffi.cdef([[
	uint32_t GetLastError();
    uint32_t FormatMessageA(
		uint32_t dwFlags,
		const void* lpSource,
		uint32_t dwMessageId,
		uint32_t dwLanguageId,
		char* lpBuffer,
		uint32_t nSize,
		...
	);
]])

local function last_error()
	local error_str = ffi.new("uint8_t[?]", 1024)
	local FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000
	local FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200
	local error_flags = bit.bor(FORMAT_MESSAGE_FROM_SYSTEM, FORMAT_MESSAGE_IGNORE_INSERTS)
	local code = ffi.C.GetLastError()
	local numout = ffi.C.FormatMessageA(error_flags, nil, code, 0, error_str, 1023, nil)

	if numout ~= 0 then
		local err = ffi.string(error_str, numout)

		if err:sub(-2) == "\r\n" then return err:sub(0, -3) end
	end

	return "no error"
end

do
	local struct = ffi.typeof([[
        struct {
            unsigned long dwFileAttributes;
            uint64_t ftCreationTime;
            uint64_t ftLastAccessTime;
            uint64_t ftLastWriteTime;
            uint64_t nFileSize;
        }
    ]])
	ffi.cdef(
		[[
        int GetFileAttributesExA(const char *lpFileName, int fInfoLevelId, $ *lpFileInformation);
    ]],
		struct
	)

	local function POSIX_TIME(time)
		return tonumber(time / 10000000 - 11644473600)
	end

	local flags = {
		archive = 0x20, -- A file or directory that is an archive file or directory. Applications typically use this attribute to mark files for backup or removal .
		compressed = 0x800, -- A file or directory that is compressed. For a file, all of the data in the file is compressed. For a directory, compression is the default for newly created files and subdirectories.
		device = 0x40, -- This value is reserved for system use.
		directory = 0x10, -- The handle that identifies a directory.
		encrypted = 0x4000, -- A file or directory that is encrypted. For a file, all data streams in the file are encrypted. For a directory, encryption is the default for newly created files and subdirectories.
		hidden = 0x2, -- The file or directory is hidden. It is not included in an ordinary directory listing.
		integrity_stream = 0x8000, -- The directory or user data stream is configured with integrity (only supported on ReFS volumes). It is not included in an ordinary directory listing. The integrity setting persists with the file if it's renamed. If a file is copied the destination file will have integrity set if either the source file or destination directory have integrity set.
		normal = 0x80, -- A file that does not have other attributes set. This attribute is valid only when used alone.
		not_content_indexed = 0x2000, -- The file or directory is not to be indexed by the content indexing service.
		no_scrub_data = 0x20000, -- The user data stream not to be read by the background data integrity scanner (AKA scrubber). When set on a directory it only provides inheritance. This flag is only supported on Storage Spaces and ReFS volumes. It is not included in an ordinary directory listing.
		offline = 0x1000, -- The data of a file is not available immediately. This attribute indicates that the file data is physically moved to offline storage. This attribute is used by Remote Storage, which is the hierarchical storage management software. Applications should not arbitrarily change this attribute.
		readonly = 0x1, -- A file that is read-only. Applications can read the file, but cannot write to it or delete it. This attribute is not honored on directories. For more information, see You cannot view or change the Read-only or the System attributes of folders in Windows Server 2003, in Windows XP, in Windows Vista or in Windows 7.
		reparse_point = 0x400, -- A file or directory that has an associated reparse point, or a file that is a symbolic link.
		sparse_file = 0x200, -- A file that is a sparse file.
		system = 0x4, -- A file or directory that the operating system uses a part of, or uses exclusively.
		temporary = 0x100, -- A file that is being used for temporary storage. File systems avoid writing data back to mass storage if sufficient cache memory is available, because typically, an application deletes a temporary file after the handle is closed. In that scenario, the system can entirely avoid writing the data. Otherwise, the data is written after the handle is closed.
		virtual = 0x10000, -- This value is reserved for system use.
	}

	function fs.get_attributes(path, follow_link)
		local info = ffi.new("$[1]", struct)

		if ffi.C.GetFileAttributesExA(path, 0, info) ~= 0 then
			return {
				creation_time = POSIX_TIME(info[0].ftCreationTime),
				last_accessed = POSIX_TIME(info[0].ftLastAccessTime),
				last_modified = POSIX_TIME(info[0].ftLastWriteTime),
				last_changed = -1, -- last permission changes
				size = tonumber(info[0].nFileSize),
				type = bit.band(info[0].dwFileAttributes, flags.directory) == flags.directory and
					"directory" or
					"file",
			}
		end

		return nil, last_error()
	end
end

do
	local struct = ffi.typeof([[
        struct {
            uint32_t dwFileAttributes;

            uint64_t ftCreationTime;
            uint64_t ftLastAccessTime;
            uint64_t ftLastWriteTime;

            uint64_t nFileSize;
            
            uint64_t dwReserved;
        
            char cFileName[260];
            char cAlternateFileName[14];
        }
    ]])
	ffi.cdef(
		[[
        void *FindFirstFileA(const char *lpFileName, $ *find_data);
        int FindNextFileA(void *handle, $ *find_data);
        int FindClose(void *);
	]],
		struct,
		struct
	)
	local dot = string.byte(".")

	local function is_dots(ptr)
		if ptr[0] == dot then
			if ptr[1] == dot and ptr[2] == 0 then return true end

			if ptr[1] == 0 then return true end
		end

		return false
	end

	local INVALID_FILE = ffi.cast("void *", 0xFFFFFFFFFFFFFFFFULL)

	function fs.get_files(path)
		if path == "" then path = "." end

		if path:sub(-1) ~= "/" then path = path .. "/" end

		local data = ffi.new("$[1]", struct)
		local handle = ffi.C.FindFirstFileA(path .. "*", data)

		if handle == nil then return nil, last_error() end

		local out = {}

		if handle == INVALID_FILE then return out end

		local i = 1

		repeat
			if not is_dots(data[0].cFileName) then
				out[i] = ffi.string(data[0].cFileName)
				i = i + 1
			end		until ffi.C.FindNextFileA(handle, data) == 0

		if ffi.C.FindClose(handle) == 0 then return nil, last_error() end

		return out
	end
end

do
	ffi.cdef([[
        unsigned long GetCurrentDirectoryA(unsigned long length, char *buffer);
        int SetCurrentDirectoryA(const char *path);
	]])

	function fs.set_current_directory(path)
		if ffi.C.chdir(path) == 0 then return true end

		return nil, last_error()
	end

	function fs.get_current_directory()
		local buffer = ffi.new("char[260]")
		local length = ffi.C.GetCurrentDirectoryA(260, buffer)
		local str = ffi.string(buffer, length)
		return (str:gsub("\\", "/"))
	end
end

return fs end
IMPORTS['examples/projects/luajit/src/platforms/unix/filesystem.nlua'] = function(...) --[[#local type contract = IMPORTS['examples/projects/luajit/src/platforms/filesystem.nlua']("~/platforms/filesystem.nlua")]]
local ffi = require("ffi")
local OSX = ffi.os == "OSX"
local X64 = ffi.arch == "x64"
local fs = {}
ffi.cdef([[
	const char *strerror(int);
	unsigned long syscall(int number, ...);
]])

local function last_error(num)
	num = num or ffi.errno()
	local ptr = ffi.C.strerror(num)

	if not ptr then return "strerror returns null" end

	local err = ffi.string(ptr)
	return err == "" and tostring(num) or err
end

do
	local stat_struct

	if OSX then
		stat_struct = ffi.typeof([[
			struct {
				uint32_t st_dev;
				uint16_t st_mode;
				uint16_t st_nlink;
				uint64_t st_ino;
				uint32_t st_uid;
				uint32_t st_gid;
				uint32_t st_rdev;
				size_t   st_atime;
				long     st_atime_nsec;
				size_t   st_mtime;
				long     st_mtime_nsec;
				size_t   st_ctime;
				long     st_ctime_nsec;
				size_t   st_btime;
				long     st_btime_nsec;
				int64_t  st_size;
				int64_t  st_blocks;
				int32_t  st_blksize;
				uint32_t st_flags;
				uint32_t st_gen;
				int32_t  st_lspare;
				int64_t  st_qspare[2];
			}
		]])
		--[[#type stat_struct.@Name = "OSXStat"]]
	else
		if X64 then
			stat_struct = ffi.typeof([[
				struct {
					uint64_t st_dev;
					uint64_t st_ino;
					uint64_t st_nlink;
					uint32_t st_mode;
					uint32_t st_uid;
					uint32_t st_gid;
					uint32_t __pad0;
					uint64_t st_rdev;
					int64_t  st_size;
					int64_t  st_blksize;
					int64_t  st_blocks;
					uint64_t st_atime;
					uint64_t st_atime_nsec;
					uint64_t st_mtime;
					uint64_t st_mtime_nsec;
					uint64_t st_ctime;
					uint64_t st_ctime_nsec;
					int64_t  __unused[3];
				}
			]])
			--[[#type stat_struct.@Name = "UnixX64Stat"]]
		else
			stat_struct = ffi.typeof([[
				struct {
					uint64_t st_dev;
					uint8_t  __pad0[4];
					uint32_t __st_ino;
					uint32_t st_mode;
					uint32_t st_nlink;
					uint32_t st_uid;
					uint32_t st_gid;
					uint64_t st_rdev;
					uint8_t  __pad3[4];
					int64_t  st_size;
					uint32_t st_blksize;
					uint64_t st_blocks;
					uint32_t st_atime;
					uint32_t st_atime_nsec;
					uint32_t st_mtime;
					uint32_t st_mtime_nsec;
					uint32_t st_ctime;
					uint32_t st_ctime_nsec;
					uint64_t st_ino;
				}
			]])
			--[[#type stat_struct.@Name = "UnixX32Stat"]]
		end
	end

	local statbox = ffi.typeof("$[1]", stat_struct)
	local stat
	local stat_link

	if OSX then
		ffi.cdef([[
			int stat64(const char *path, void *buf);
			int lstat64(const char *path, void *buf);
		]])
		stat = ffi.C.stat64
		stat_link = ffi.C.lstat64
	else
		local STAT_SYSCALL = 195
		local STAT_LINK_SYSCALL = 196

		if X64 then
			STAT_SYSCALL = 4
			STAT_LINK_SYSCALL = 6
		end

		stat = function(path, buff)
			return ffi.C.syscall(STAT_SYSCALL, path, buff)
		end
		stat_link = function(path, buff)
			return ffi.C.syscall(STAT_LINK_SYSCALL, path, buff)
		end
	end

	local DIRECTORY = 0x4000

	function fs.get_attributes(path, follow_link)
		local buff = statbox()
		local ret = follow_link and stat_link(path, buff) or stat(path, buff)

		if ret == 0 then
			return {
				last_accessed = tonumber(buff[0].st_atime),
				last_changed = tonumber(buff[0].st_ctime),
				last_modified = tonumber(buff[0].st_mtime),
				size = tonumber(buff[0].st_size),
				type = bit.band(buff[0].st_mode, DIRECTORY) ~= 0 and "directory" or "file",
			}
		end

		return nil, last_error()
	end
end

do
	ffi.cdef[[
		void *opendir(const char *name);
		int closedir(void *dirp);
	]]

	if OSX then
		ffi.cdef([[
			struct dirent {
				uint64_t d_ino;
				uint64_t d_seekoff;
				uint16_t d_reclen;
				uint16_t d_namlen;
				uint8_t  d_type;
				char d_name[1024];
			};
			struct dirent *readdir(void *dirp) asm("readdir$INODE64");
		]])
	else
		ffi.cdef([[
			struct dirent {
				uint64_t        d_ino;
				int64_t         d_off;
				unsigned short  d_reclen;
				unsigned char   d_type;
				char            d_name[256];
			};
			struct dirent *readdir(void *dirp) asm("readdir64");
		]])
	end

	local dot = string.byte(".")

	local function is_dots(ptr)
		if ptr[0] == dot then
			if ptr[1] == dot and ptr[2] == 0 then return true end

			if ptr[1] == 0 then return true end
		end

		return false
	end

	function fs.get_files(path)
		local out = {} -- [1] TODO
		local ptr = ffi.C.opendir(path or "")

		if ptr == nil then return nil, last_error() end

		local i = 1

		while true do
			local dir_info = ffi.C.readdir(ptr)
			dir_info = dir_info -- TODO
			if dir_info == nil then break end

			if not is_dots(dir_info.d_name) then
				out[i] = ffi.string(dir_info.d_name)
				i = i + 1
			end
		end

		ffi.C.closedir(ptr)
		return out
	end
end

do
	ffi.cdef([[
		const char *getcwd(const char *buf, size_t size);
		int chdir(const char *filename);
	]])

	function fs.set_current_directory(path)
		if ffi.C.chdir(path) == 0 then return true end

		return nil, last_error()
	end

	function fs.get_current_directory()
		local temp = ffi.new("char[1024]")
		local ret = ffi.C.getcwd(temp, ffi.sizeof(temp))

		if ret then return ffi.string(ret, ffi.sizeof(temp)) end

		return nil, last_error()
	end
end

return fs end
IMPORTS['examples/projects/luajit/src/filesystem.nlua'] = function(...) if jit.os == "Windows" then
	return IMPORTS['examples/projects/luajit/src/platforms/windows/filesystem.nlua']("./platforms/windows/filesystem.nlua")
else
	return IMPORTS['examples/projects/luajit/src/platforms/unix/filesystem.nlua']("./platforms/unix/filesystem.nlua")
end

error("unknown platform") end
IMPORTS['nattlua/definitions/index.nlua']("nattlua/definitions/index.nlua")
local fs = IMPORTS['examples/projects/luajit/src/filesystem.nlua']("./filesystem.nlua")
print("get files: ", assert(fs.get_files(".")))

for k, v in ipairs(assert(fs.get_files("."))) do
	print(k, v)
end

print(assert(fs.get_current_directory()))

for k, v in pairs(assert(fs.get_attributes("README.md"))) do
	print(k, v)
end