local tonumber = tonumber
local ipairs = ipairs
local os = os
local print = print
local pairs = pairs
local setmetatable = setmetatable
local pcall = pcall
local tostring = tostring
local debug = debug
local type = _G.type
local io = io
local xpcall = _G.xpcall
local load = loadstring or load
local LString = require("nattlua.types.string").LString
local ConstString = require("nattlua.types.string").ConstString
local Tuple = require("nattlua.types.tuple").Tuple
local Nil = require("nattlua.types.symbol").Nil
local Any = require("nattlua.types.any").Any
local context = require("nattlua.analyzer.context")
local table = _G.table
local math = _G.math
return function(META)
	require("nattlua.analyzer.base.scopes")(META)
	require("nattlua.analyzer.base.error_handling")(META)

	function META:AnalyzeRootStatement(statement, a, b, c, d, e, f)
		context:PushCurrentAnalyzer(self)
		local argument_tuple = a and
			Tuple({a, b, c, d, e, f}) or
			Tuple({a, b, c, d, e, f}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
		self:CreateAndPushModuleScope()
		self:PushGlobalEnvironment(statement, self:GetDefaultEnvironment("runtime"), "runtime")
		self:PushGlobalEnvironment(statement, self:GetDefaultEnvironment("typesystem"), "typesystem")
		local g = self:GetGlobalEnvironment("typesystem")
		g:Set(ConstString("_G"), g)
		self:PushAnalyzerEnvironment("runtime")
		self:CreateLocalValue("...", argument_tuple)
		local analyzed_return = self:AnalyzeStatementsAndCollectOutputSignatures(statement)
		self:PopAnalyzerEnvironment()
		self:PopGlobalEnvironment("runtime")
		self:PopGlobalEnvironment("typesystem")
		self:PopScope()
		context:PopCurrentAnalyzer()
		return analyzed_return
	end

	function META:AnalyzeExpressions(expressions)
		if not expressions then return end

		local out = {}

		for _, expression in ipairs(expressions) do
			local obj = self:AnalyzeExpression(expression)

			if obj and obj.Type == "tuple" and obj:GetLength() == 1 then
				obj = obj:Get(1)
			end

			table.insert(out, obj)
		end

		return out
	end

	do
		local function add_potential_self(tup)
			local tbl = tup:Get(1)

			if tbl and tbl.Type == "union" then tbl = tbl:GetType("table") end

			if not tbl then return tup end

			if tbl.Self then
				local self = tbl.Self
				local new_tup = Tuple({})

				for i, obj in ipairs(tup:GetData()) do
					if i == 1 then
						new_tup:Set(i, self)
					else
						new_tup:Set(i, obj)
					end
				end

				return new_tup
			elseif tbl.potential_self then
				local meta = tbl
				local self = tbl.potential_self:Copy()

				if self.Type == "union" then
					for _, obj in ipairs(self:GetData()) do
						obj:SetMetaTable(meta)
					end
				else
					self:SetMetaTable(meta)
				end

				local new_tup = Tuple({})

				for i, obj in ipairs(tup:GetData()) do
					if i == 1 then
						new_tup:Set(i, self)
					else
						new_tup:Set(i, obj)
					end
				end

				return new_tup
			end

			return tup
		end

		local function call(self, obj)
			-- use function's arguments in case they have been maniupulated (ie string.gsub)
			local arguments = obj:GetInputSignature():Copy()
			arguments = add_potential_self(arguments)

			for _, obj in ipairs(arguments:GetData()) do
				if obj.Type == "upvalue" or obj.Type == "table" then
					obj:ClearMutations()
				end
			end

			self:CreateAndPushFunctionScope(obj)
			self:Assert(obj:Call(self, arguments, obj:GetFunctionBodyNode()))
			self:PopScope()
		end

		function META:AddToUnreachableCodeAnalysis(obj)
			self.deferred_calls = self.deferred_calls or {}
			table.insert(self.deferred_calls, 1, obj)
		end

		function META:AnalyzeUnreachableCode()
			if not self.deferred_calls then return end

			context:PushCurrentAnalyzer(self)
			local total = #self.deferred_calls
			self.processing_deferred_calls = true
			local called_count = 0
			local done = {}

			for _, func in ipairs(self.deferred_calls) do
				if
					func:IsExplicitInputSignature() and
					not func:IsCalled()
					and
					not done[func]
				then
					call(self, func)
					called_count = called_count + 1
					done[func] = true
					func:SetCalled()
				end
			end

			for _, func in ipairs(self.deferred_calls) do
				if
					not func:IsExplicitInputSignature() and
					not func:IsCalled()
					and
					not done[func]
				then
					call(self, func)
					called_count = called_count + 1
					done[func] = true
					func:SetCalled()
				end
			end

			self.processing_deferred_calls = false
			self.deferred_calls = nil
			context:PopCurrentAnalyzer()
		end
	end

	function META:ReadFile(path)
		if self.config.on_read_file then
			local ok, code = pcall(self.config.on_read_file, self, path)

			if not ok then return nil, code end

			return code
		end

		local f, err = io.open(path, "rb")

		if not f then return nil, err end

		local code = f:read("*a")
		f:close()

		if not code then return nil, "file is empty" end

		return code
	end

	do
		local formating = require("nattlua.other.formating")
		local loadstring = require("nattlua.other.loadstring")
		local locals = ""
		locals = locals .. "local bit=bit32 or _G.bit;"

		if _G.BUNDLE then
			locals = locals .. "local nl=IMPORTS[\"nattlua.init\"]();"
			locals = locals .. "local types=IMPORTS[\"nattlua.types.types\"]();"
			locals = locals .. "local context=IMPORTS[\"nattlua.analyzer.context\"]();"
		else
			locals = locals .. "local nl=require(\"nattlua.init\");"
			locals = locals .. "local types=require(\"nattlua.types.types\");"
			locals = locals .. "local context=require(\"nattlua.analyzer.context\");"
		end

		local globals = {
			"loadstring",
			"dofile",
			"gcinfo",
			"collectgarbage",
			"newproxy",
			"print",
			"_VERSION",
			"coroutine",
			"debug",
			"package",
			"os",
			"bit",
			"_G",
			"module",
			"require",
			"assert",
			"string",
			"arg",
			"jit",
			"math",
			"table",
			"io",
			"type",
			"next",
			"pairs",
			"ipairs",
			"getmetatable",
			"setmetatable",
			"getfenv",
			"setfenv",
			"rawget",
			"rawset",
			"rawequal",
			"unpack",
			"select",
			"tonumber",
			"tostring",
			"error",
			"pcall",
			"xpcall",
			"loadfile",
			"load",
		}

		for _, key in ipairs(globals) do
			locals = locals .. "local " .. tostring(key) .. "=_G." .. key .. ";"
		end

		local runtime_injection = [[
			local analyzer = assert(context:GetCurrentAnalyzer(), "no analyzer in context")
			local env = analyzer:GetScopeHelper(analyzer.function_scope)
		]]
		runtime_injection = runtime_injection:gsub("\n", ";")

		function META:CompileLuaAnalyzerDebugCode(code, node)
			local start, stop = code:find("^.-function %b()")

			if start and stop then
				local before_function = code:sub(1, stop)
				local after_function = code:sub(stop + 1, #code)
				code = before_function .. runtime_injection .. after_function
			else
				code = runtime_injection .. code
			end

			code = locals .. code
			-- append newlines so that potential line errors are correct
			local lua_code = node.Code:GetString()
			local line

			if lua_code then
				local start, stop = node:GetStartStop()
				line = formating.SubPositionToLinePosition(lua_code, start, stop).line_start
				code = ("\n"):rep(line - 1) .. code
			end

			local func, err = loadstring(code, node.Code:GetName() .. ":" .. line)

			if not func then
				print("========================")
				print(func, err, node.Code:GetName(), code)
				print(node)
				print("=============NODE===========")

				for k, v in pairs(node) do
					print(k, v)
				end

				print("============TOKENS===========")

				for k, v in pairs(node.tokens) do
					print(k, v, v.value)
				end

				print("===============>=================")
				self:FatalError(err)
				return false, err
			end

			return func
		end

		function META:CallLuaTypeFunction(func, scope, ...)
			self.function_scope = scope
			local res = {pcall(func, ...)}
			local ok = table.remove(res, 1)

			if not ok then
				local msg = tostring(res[1])
				local name = debug.getinfo(func).source

				if name:sub(1, 1) == "@" then -- is this a name that is a location?
					local line, rest = msg:sub(#name):match("^:(%d+):(.+)") -- remove the file name and grab the line number
					if line then
						local f, err = io.open(name:sub(2), "r")

						if f then
							local code = f:read("*all")
							f:close()
							local start = formating.LinePositionToSubPosition(code, tonumber(line), 0)
							local stop = start + #(code:sub(start):match("(.-)\n") or "") - 1
							msg = self.current_expression.Code:BuildSourceCodePointMessage(rest, start, stop)
						end
					end
				end

				local frame = self:GetCallStack()[1]

				if frame then
					self.current_expression = self:GetCallStack()[1].call_node
				end

				self:Error(msg)
			end

			if res[1] == nil then res[1] = Nil() end

			return table.unpack(res)
		end

		do
			local scope_meta = {}

			function scope_meta:__index(key)
				self.analyzer:PushAnalyzerEnvironment(self.env)
				local val = self.analyzer:GetLocalOrGlobalValue(LString(key), self.scope)
				self.analyzer:PopAnalyzerEnvironment()
				return val
			end

			function scope_meta:__newindex(key, val)
				self.analyzer:PushAnalyzerEnvironment(self.env)
				self.analyzer:SetLocalOrGlobalValue(LString(key), val, self.scope)
				self.analyzer:PopAnalyzerEnvironment()
			end

			function META:GetScopeHelper(scope)
				scope.scope_helper = scope.scope_helper or
					{
						typesystem = setmetatable(
							{
								analyzer = self,
								scope = scope,
								env = "typesystem",
							},
							scope_meta
						),
						runtime = setmetatable({analyzer = self, scope = scope, env = "runtime"}, scope_meta),
					}
				return scope.scope_helper
			end

			function META:CallTypesystemUpvalue(name, a, b, c, d, e, f)
				-- this is very internal-ish code
				-- not sure what a nice interface for this really should be yet
				self:PushAnalyzerEnvironment("typesystem")
				local generics_func = self:GetLocalOrGlobalValue(name)
				assert(generics_func.Type == "function", "cannot find typesystem function " .. name:GetData())
				local argument_tuple = Tuple({a, b, c, d, e, f})
				local returned_tuple = assert(generics_func:Call(self, argument_tuple))
				self:PopAnalyzerEnvironment()
				return returned_tuple:Unpack()
			end
		end

		function META:TypeTraceback(from)
			local str = ""

			for i, v in ipairs(self:GetCallStack()) do
				if v.call_node and (not from or i > from) then
					local start, stop = v.call_node:GetStartStop()

					if start and stop then
						local part = self.compiler:GetCode():BuildSourceCodePointMessage("", start, stop, 1)
						str = str .. part .. "#" .. tostring(i) .. ": " .. self.compiler:GetCode():GetName()
					end
				end
			end

			return str
		end

		local function attempt_render(node)
			local s = ""
			local ok, err = xpcall(function()
				s = s .. node:Render()
			end, function(err)
				print(debug.traceback(err))
			end)

			if not ok then s = "* error in rendering statement * " end

			return s
		end

		function META:DebugStateToString()
			local s = ""

			if self.current_statement and self.current_statement.Render then
				s = s .. "======== statement =======\n"
				s = s .. attempt_render(self.current_statement)
				s = s .. "==========================\n"
			end

			if self.current_expression and self.current_expression.Render then
				s = s .. "======== expression =======\n"
				s = s .. attempt_render(self.current_expression)
				s = s .. "===========================\n"
			end

			pcall(function()
				s = s .. self:TypeTraceback()
			end)

			return s
		end

		function META:ResolvePath(path)
			return path
		end

		do
			function META:GetCurrentAnalyzerEnvironment()
				return self:GetContextValue("analyzer_environment") or "runtime"
			end

			function META:PushAnalyzerEnvironment(env--[[#: "typesystem" | "runtime"]])
				self:PushContextValue("analyzer_environment", env)
			end

			function META:PopAnalyzerEnvironment()
				self:PopContextValue("analyzer_environment")
			end

			function META:IsTypesystem()
				return self:GetCurrentAnalyzerEnvironment() == "typesystem"
			end

			function META:IsRuntime()
				return self:GetCurrentAnalyzerEnvironment() == "runtime"
			end
		end

		do
			function META:IsInUncertainLoop(scope)
				scope = scope or self:GetScope():GetNearestLoopScope()
				return self:GetContextValue("uncertain_loop") == scope:GetNearestLoopScope()
			end

			function META:PushUncertainLoop(b)
				return self:PushContextValue("uncertain_loop", b and self:GetScope():GetNearestLoopScope())
			end

			function META:PopUncertainLoop()
				return self:PopContextValue("uncertain_loop")
			end
		end

		do
			function META:PushCurrentType(obj, type)
				self:PushContextValue("current_type_" .. type, obj)
			end

			function META:PopCurrentType(type)
				self:PopContextValue("current_type_" .. type)
			end

			function META:GetCurrentType(type, offset)
				return self:GetContextValue("current_type_" .. type, offset)
			end
		end

		do
			local Function = require("nattlua.types.function").Function
			local LNumber = require("nattlua.types.number").LNumber
			local Table = require("nattlua.types.table").Table
			local Symbol = require("nattlua.types.symbol").Symbol
			local ffi = jit and require("ffi") or nil

			function META:LuaTypesToTuple(tps)
				local tbl = {}

				for i, v in ipairs(tps) do
					if type(v) == "table" and v.Type ~= nil then
						tbl[i] = v
					else
						if type(v) == "function" then
							local func = Function()
							func:SetAnalyzerFunction(v)
							func:SetInputSignature(Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge)))
							func:SetOutputSignature(Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge)))
							func:SetLiteral(true)
							tbl[i] = func
						else
							local t = type(v)

							if t == "number" then
								tbl[i] = LNumber(v)
							elseif t == "string" then
								tbl[i] = LString(v)
							elseif t == "boolean" then
								tbl[i] = Symbol(v)
							elseif t == "table" then
								local tbl = Table()

								for _, val in ipairs(v) do
									tbl:Insert(val)
								end

								tbl:SetContract(tbl)
								return tbl
							elseif
								ffi and
								t == "cdata" and
								tostring(ffi.typeof(v)):sub(1, 10) == "ctype<uint" or
								tostring(ffi.typeof(v)):sub(1, 9) == "ctype<int"
							then
								tbl[i] = LNumber(v)
							else
								self:Print(t)
								error(debug.traceback("NYI " .. t))
							end
						end
					end
				end

				if tbl[1] and tbl[1].Type == "tuple" and #tbl == 1 then return tbl[1] end

				return Tuple(tbl)
			end
		end
	end
end