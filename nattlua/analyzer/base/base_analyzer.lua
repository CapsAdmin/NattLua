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
local type_errors = require("nattlua.types.error_messages")
local formating = require("nattlua.other.formating")
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
		self:PushCurrentStatement(statement)
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
		self:PopCurrentStatement()
		return analyzed_return
	end

	function META:AnalyzeExpressions(expressions, out)
		if not expressions then return end

		out = out or {}

		for _, expression in ipairs(expressions) do
			local obj, err = self:AnalyzeExpression(expression)
			if not obj then self:Error(err) obj = Any() end


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
			self:PushCurrentStatement(obj:GetFunctionBodyNode())
			self:ErrorIfFalse(self:Call(obj, arguments, obj:GetFunctionBodyNode()))
			self:PopCurrentStatement()
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

	function META:ParseFile(path)
		self.parsed_paths[path] = true
		local imported = self.compiler and self.compiler.SyntaxTree and self.compiler.SyntaxTree.imported

		if imported then
			local path = path

			if path:sub(1, 2) == "./" then path = path:sub(3) end

			if imported[path] then return imported[path] end
		end

		local code = read_file(self, path)
		local compiler = require("nattlua.compiler").New(
			code,
			"@" .. path,
			{
				parser = {root_statement_override = self.compiler and self.compiler.SyntaxTree},
				file_path = path,
				file_name = "@" .. path,
			}
		)
		assert(compiler:Lex())
		assert(compiler:Parse())
		return compiler.SyntaxTree
	end

	do
		local analyzer_context = require("nattlua.analyzer.context")

		local function on_error(msg)
			local info = debug.getinfo(3)
			local source = info.source

			if source:sub(1, 1) == "@" then
				local test = source:match("^(.+):%d+$")

				if test then source = test end

				local f, err = io.open(source:sub(2), "r")

				if f then
					local code = f:read("*all")
					f:close()
					local start = formating.LineCharToSubPos(code, tonumber(info.currentline), 0)
					local stop = start + #(code:sub(start):match("(.-)\n") or "") - 1
					
					if msg:sub(1, #source) == source then
						msg = msg:sub(#source)
						msg = msg:match("^:%d+:%d+:%s*(.+)") or msg:match("^:%d+%s*(.+)") or msg
					end
					local analyzer = analyzer_context:GetCurrentAnalyzer()
					local node = analyzer:GetCurrentExpression() or analyzer:GetCurrentStatement() 
					return node.Code:BuildSourceCodePointMessage(msg, start, stop)
				end
			end

			return tostring(msg)
		end

		local function on_error_safe(msg)
			local ok, ret = pcall(on_error, msg)
			
			if not ok then 
				print("fatal error in error handling:")
				print("=============================")
				print(ret)
				print("=============================")
				return "error in nattlua error handling"
			end

			return ret
		end

		function META:CallLuaTypeFunction(func, scope, ...)
			self.function_scope = scope
			local res = {xpcall(func, on_error_safe, ...)}

			if not table_remove(res, 1) then
				local stack = self:GetCallStack()

				if stack[1] then self:PushCurrentExpression(stack[#stack].call_node) end

				self:Error(type_errors.plain_error(res[1]))

				if stack[1] then self:PopCurrentExpression() end

				return Nil()
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
				-- TODO
				-- this is very internal-ish code
				-- not sure what a nice interface for this really should be yet
				self:PushAnalyzerEnvironment("typesystem")
				local generics_func = self:GetLocalOrGlobalValue(name)

				if generics_func.Type ~= "function" then
					self:PopAnalyzerEnvironment()
					error("cannot find typesystem function " .. name:GetData())
				end

				local argument_tuple = Tuple({a, b, c, d, e, f})
				local returned_tuple, err = self:Call(generics_func, argument_tuple)
				self:PopAnalyzerEnvironment()

				if not returned_tuple then error(err) end

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

			do
				local node = self:GetCurrentStatement()

				if node and node.Render then
					s = s .. "======== statement =======\n"
					s = s .. attempt_render(node)
					s = s .. "==========================\n"
				end
			end

			do
				local node = self:GetCurrentExpression()

				if node and node.Render then
					s = s .. "======== expression =======\n"
					s = s .. attempt_render(node)
					s = s .. "===========================\n"
				end
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
			function META:PushCurrentStatement(node)
				self:PushContextValue("current_statement", node)
			end

			function META:PopCurrentStatement()
				self:PopContextValue("current_statement")
			end

			function META:GetCurrentStatement(offset)
				return self:GetContextValue("current_statement", offset)
			end
		end

		do
			function META:PushCurrentExpression(node)
				self:PushContextValue("current_expression", node)
			end

			function META:PopCurrentExpression()
				self:PopContextValue("current_expression")
			end

			function META:GetCurrentExpression(offset)
				return self:GetContextValue("current_expression", offset)
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
