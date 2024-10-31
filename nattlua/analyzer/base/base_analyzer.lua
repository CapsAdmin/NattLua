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
local Table = require("nattlua.types.table").Table
local Any = require("nattlua.types.any").Any
local context = require("nattlua.analyzer.context")
local path_util = require("nattlua.other.path")
local table = _G.table
local table_insert = table.insert
local table_remove = table.remove
local math = _G.math
return function(META)
	require("nattlua.analyzer.base.scopes")(META)
	require("nattlua.analyzer.base.error_handling")(META)

	function META:AnalyzeRootStatement(statement, a, b, c, d, e, f)
		--if not a and self.analyzed_root_statements[statement] then
		--return self.analyzed_root_statements[statement]:Copy({}, true)
		--end
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
		self.analyzed_root_statements[statement] = analyzed_return
		return analyzed_return
	end

	function META:AnalyzeExpressions(expressions, out)
		if not expressions then return end

		out = out or {}

		for _, expression in ipairs(expressions) do
			local obj = self:AnalyzeExpression(expression)

			if obj and obj.Type == "tuple" and obj:HasOneValue() then
				obj = obj:GetWithNumber(1)
			end

			table_insert(out, obj)
		end

		return out
	end

	do
		local function add_potential_self(tup)
			local tbl = tup:GetWithNumber(1)

			if tbl and tbl.Type == "union" then tbl = tbl:GetType("table") end

			if not tbl or tbl.Type ~= "table" then return tup end

			if tbl.Self then
				local self = tbl.Self:Copy()
				local new_tup = Tuple()

				for i, obj in ipairs(tup:GetData()) do
					if i == 1 then
						new_tup:Set(i, self)
					else
						new_tup:Set(i, obj)
					end
				end

				return new_tup
			elseif tbl.Self2 then
				local self = tbl.Self2
				local new_tup = Tuple()

				for i, obj in ipairs(tup:GetData()) do
					if i == 1 then
						new_tup:Set(i, self)
					else
						new_tup:Set(i, obj)
					end
				end

				return new_tup
			elseif tbl.PotentialSelf then
				local meta = tbl
				local self = tbl.PotentialSelf

				if self.Type == "union" then
					for _, obj in ipairs(self:GetData()) do
						obj:SetMetaTable(meta)
					end
				else
					self:SetMetaTable(meta)
				end

				local new_tup = Tuple()

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

		function META:CrawlFunctionWithoutOrigin(obj)
			-- use function's arguments in case they have been maniupulated (ie string.gsub)
			local arguments = obj:GetInputSignature():Copy()
			arguments = add_potential_self(arguments)

			for _, obj in ipairs(arguments:GetData()) do
				if obj.Type == "upvalue" or obj.Type == "table" then
					obj:ClearMutations()
				end
			end

			self:CreateAndPushFunctionScope(obj)
			self:Assert(self:Call(obj, arguments, obj:GetFunctionBodyNode()))
			self:PopScope()
		end

		function META:AddToUnreachableCodeAnalysis(obj)
			self.deferred_calls = self.deferred_calls or {}
			table_insert(self.deferred_calls, obj)
		end

		function META:AnalyzeUnreachableCode()
			if not self.deferred_calls then return end

			context:PushCurrentAnalyzer(self)
			local total = #self.deferred_calls
			self.processing_deferred_calls = true
			local called_count = 0
			local done = {}

			for i = total, 1, -1 do
				local func = self.deferred_calls[i]

				if
					func:IsExplicitInputSignature() and
					not func:IsCalled()
					and
					not done[func]
				then
					self:CrawlFunctionWithoutOrigin(func)
					called_count = called_count + 1
					done[func] = true
					func:SetCalled(false)
				end
			end

			for i = total, 1, -1 do
				local func = self.deferred_calls[i]

				if
					not func:IsExplicitInputSignature() and
					not func:IsCalled()
					and
					not done[func]
				then
					self:CrawlFunctionWithoutOrigin(func)
					called_count = called_count + 1
					done[func] = true
					func:SetCalled(false)
				end
			end

			self.processing_deferred_calls = false
			self.deferred_calls = false
			context:PopCurrentAnalyzer()
		end
	end

	local function read_file(self, path)
		path = path_util.Resolve(
			path,
			self.config.root_directory,
			self.config.working_directory,
			self.config.file_path
		)

		if self.config.pre_read_file then
			local code = self.config.pre_read_file(self, path)

			if code then return code end
		end

		local f = assert(io.open(path, "rb"))
		local code = f:read("*a")
		f:close()

		if not code then
			debug.trace()
			error(path .. " is empty", 2)
		end

		if self.config.on_read_file then self.config.on_read_file(self, path, code) end

		return code
	end

	function META:ReadFile(path)
		local ok, code = pcall(read_file, self, path)

		if ok then return code end

		return nil, code
	end

	function META:ParseFile(path)
		local imported = self.compiler and self.compiler.SyntaxTree and self.compiler.SyntaxTree.imported

		if not path then debug.trace() end

		if imported then
			local path = path

			if path:sub(1, 2) == "./" then path = path:sub(3) end

			if imported[path] then return imported[path] end
		end

		local code = assert(self:ReadFile(path))
		local compiler = require("nattlua.compiler").New(
			code,
			"@" .. path,
			{
				root_statement_override = self.compiler and self.compiler.SyntaxTree,
				file_path = path,
				file_name = "@" .. path,
			}
		)
		assert(compiler:Lex())
		assert(compiler:Parse())
		return compiler.SyntaxTree
	end

	do
		function META:CallLuaTypeFunction(func, scope, ...)
			self.function_scope = scope
			local res = {pcall(func, ...)}
			local ok = table_remove(res, 1)

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
							local start = formating.LineCharToSubPos(code, tonumber(line), 0)
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
				local returned_tuple = assert(self:Call(generics_func, argument_tuple))
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
				local b = self:GetContextValue("uncertain_loop")

				if b == false or b == nil then return false end

				return b == scope:GetNearestLoopScope()
			end

			function META:PushUncertainLoop(scope)
				self:PushContextValue("uncertain_loop", scope or false)
			end

			function META:PopUncertainLoop()
				self:PopContextValue("uncertain_loop")
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
			local cast_lua_types_to_types = require("nattlua.analyzer.cast")

			function META:LuaTypesToTuple(tps)
				local tbl = cast_lua_types_to_types(tps)

				if tbl[1] and tbl[1].Type == "tuple" and #tbl == 1 then return tbl[1] end

				return Tuple(tbl)
			end
		end
	end
end
