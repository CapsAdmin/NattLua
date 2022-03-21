local tonumber = tonumber
local ipairs = ipairs
local os = os
local print = print
local pairs = pairs
local setmetatable = setmetatable
local pcall = pcall
local tostring = tostring
local debug = debug
local io = io
local load = loadstring or load
local LString = require("nattlua.types.string").LString
local Tuple = require("nattlua.types.tuple").Tuple
local Nil = require("nattlua.types.symbol").Nil
local Any = require("nattlua.types.any").Any
local context = require("nattlua.analyzer.context")
local table = _G.table
local math = _G.math
return function(META)
	require("nattlua.analyzer.base.scopes")(META)
	require("nattlua.analyzer.base.error_handling")(META)

	function META:AnalyzeRootStatement(statement, ...)
		context:PushCurrentAnalyzer(self)
		local argument_tuple = ... and
			Tuple({...}) or
			Tuple({...}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
		self:CreateAndPushModuleScope()
		self:PushGlobalEnvironment(statement, self:GetDefaultEnvironment("runtime"), "runtime")
		self:PushGlobalEnvironment(statement, self:GetDefaultEnvironment("typesystem"), "typesystem")
		local g = self:GetGlobalEnvironment("typesystem")
		g:Set(LString("_G"), g)
		self:PushAnalyzerEnvironment("runtime")
		self:CreateLocalValue("...", argument_tuple)
		local analyzed_return = self:AnalyzeStatementsAndCollectReturnTypes(statement)
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
			local self = tup:Get(1)

			if self and self.Type == "union" then self = self:GetType("table") end

			if self and self.Self then
				local self = self.Self
				local new_tup = Tuple({})

				for i, obj in ipairs(tup:GetData()) do
					if i == 1 then
						new_tup:Set(i, self)
					else
						new_tup:Set(i, obj)
					end
				end

				return new_tup
			elseif self and self.potential_self then
				local meta = self
				local self = self.potential_self:Copy()

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

		local function call(self, obj, arguments, node)
			-- disregard arguments and use function's arguments in case they have been maniupulated (ie string.gsub)
			arguments = obj:GetArguments():Copy()
			arguments = add_potential_self(arguments)

			for _, obj in ipairs(arguments:GetData()) do
				obj.mutations = nil
			end

			self:CreateAndPushFunctionScope(obj:GetData().scope, obj:GetData().upvalue_position)
			self:Assert(node, self:Call(obj, arguments, node))
			self:PopScope()
		end

		function META:CallMeLater(obj, arguments, node)
			self.deferred_calls = self.deferred_calls or {}
			table.insert(self.deferred_calls, 1, {obj, arguments, node})
		end

		local function is_ref_function(func)
			for i, v in ipairs(func:GetArguments():GetData()) do
				if v.ref_argument then return true end
			end

			for i, v in ipairs(func:GetReturnTypes():GetData()) do
				if v.ref_argument then return true end
			end

			return false
		end

		function META:AnalyzeUnreachableCode()
			if not self.deferred_calls then return end

			context:PushCurrentAnalyzer(self)
			local total = #self.deferred_calls
			self.processing_deferred_calls = true
			local called_count = 0

			for _, v in ipairs(self.deferred_calls) do
				local func = v[1]

				if
					not func.called and
					not func.done and
					func.explicit_arguments and
					not is_ref_function(func)
				then
					local time = os.clock()
					call(self, table.unpack(v))
					called_count = called_count + 1
					func.done = true
					func.called = nil
				end
			end

			for _, v in ipairs(self.deferred_calls) do
				local func = v[1]

				if
					not func.called and
					not func.done and
					not func.explicit_arguments and
					not is_ref_function(func)
				then
					local time = os.clock()
					call(self, table.unpack(v))
					called_count = called_count + 1
					func.done = true
					func.called = nil
				end
			end

			self.processing_deferred_calls = false
			self.deferred_calls = nil
			context:PopCurrentAnalyzer()
		end
	end

	do
		local helpers = require("nattlua.other.helpers")
		local loadstring = require("nattlua.other.loadstring")
		local locals = ""
		locals = locals .. "local bit=bit32 or _G.bit;"

		if BUNDLE then
			locals = locals .. "local nl=IMPORTS[\"nattlua\"]();"
			locals = locals .. "local types=IMPORTS[\"nattlua.types.types\"]();"
			locals = locals .. "local context=IMPORTS[\"nattlua.analyzer.context\"]();"
		else
			locals = locals .. "local nl=require(\"nattlua\");"
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
			local analyzer = context:GetCurrentAnalyzer()
			local env = analyzer:GetScopeHelper(analyzer.function_scope)
		]]
		runtime_injection = runtime_injection:gsub("\n", ";")

		function META:CompileLuaAnalyzerDebugCode(code, node)
			local start, stop = code:find("^.-function%b()")

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

			if lua_code then
				local start, stop = node:GetStartStop()
				local line = helpers.SubPositionToLinePosition(lua_code, start, stop).line_start
				code = ("\n"):rep(line - 1) .. code
			end

			local func, err = loadstring(code, node.name)

			if not func then
				print("========================")
				print(func, err, code.name, code)
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
			end

			return func
		end

		function META:CallLuaTypeFunction(node, func, scope, ...)
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
							local start = helpers.LinePositionToSubPosition(code, tonumber(line), 0)
							local stop = start + #(code:sub(start):match("(.-)\n") or "") - 1
							msg = code:BuildSourceCodePointMessage(rest, start, stop)
						end
					end
				end

				local trace = self:TypeTraceback(1)

				if trace and trace ~= "" then msg = msg .. "\ntraceback:\n" .. trace end

				self:Error(node, msg)
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
				self.analyzer:SetLocalOrGlobalValue(LString(key), LString(val), self.scope)
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

			function META:CallTypesystemUpvalue(name, ...)
				-- this is very internal-ish code
				-- not sure what a nice interface for this really should be yet
				self:PushAnalyzerEnvironment("typesystem")
				local generics_func = self:GetLocalOrGlobalValue(name)
				assert(generics_func.Type == "function", "cannot find typesystem function " .. name:GetData())
				local argument_tuple = Tuple({...})
				local returned_tuple = assert(self:Call(generics_func, argument_tuple))
				self:PopAnalyzerEnvironment()
				return returned_tuple:Unpack()
			end
		end

		function META:TypeTraceback(from)
			if not self.call_stack then return "" end

			local str = ""

			for i, v in ipairs(self.call_stack) do
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
			local ok, err
			ok, err = pcall(function()
				s = s .. node:Render()
			end)

			if not ok then
				print("DebugStateString: failed to render node: " .. tostring(err))
				ok, err = pcall(function()
					s = s .. tostring(node)
				end)

				if not ok then
					print("DebugStateString: failed to tostring node: " .. tostring(err))
					s = s .. "* error in rendering statement * "
				end
			end

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
			function META:PushContextValue(key, value)
				self.context_values[key] = self.context_values[key] or {}
				table.insert(self.context_values[key], 1, value)
			end

			function META:GetContextValue(key, level)
				return self.context_values[key] and self.context_values[key][level or 1]
			end

			function META:PopContextValue(key)
				return table.remove(self.context_values[key], 1)
			end
		end

		do
			function META:PushContextRef(key)
				self.context_ref[key] = (self.context_ref[key] or 0) + 1
			end

			function META:GetContextRef(key)
				return self.context_ref[key] and self.context_ref[key] > 0
			end

			function META:PopContextRef(key)
				self.context_ref[key] = (self.context_ref[key] or 0) - 1
			end
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
				scope = scope or self:GetScope():GetNearestFunctionScope()
				return self:GetContextValue("uncertain_loop") == scope:GetNearestFunctionScope()
			end

			function META:PushUncertainLoop(b)
				return self:PushContextValue("uncertain_loop", b and self:GetScope():GetNearestFunctionScope())
			end

			function META:PopUncertainLoop()
				return self:PopContextValue("uncertain_loop")
			end
		end

		do
			function META:GetActiveNode()
				return self:GetContextValue("active_node")
			end

			function META:PushActiveNode(node)
				self:PushContextValue("active_node", node)
			end

			function META:PopActiveNode()
				self:PopContextValue("active_node")
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
	end
end
