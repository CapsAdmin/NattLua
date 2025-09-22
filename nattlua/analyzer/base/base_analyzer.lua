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
local Union = require("nattlua.types.union").Union
local Any = require("nattlua.types.any").Any
local context = require("nattlua.analyzer.context")
local path_util = require("nattlua.other.path")
local error_messages = require("nattlua.error_messages")
local formating = require("nattlua.other.formating")
local callstack = require("nattlua.other.callstack")
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
		local ret = self:AnalyzeStatementsAndCollectOutputSignatures(statement)
		local union = Union()

		for _, ret in ipairs(ret) do
			if #ret.types == 1 then
				union:AddType(ret.types[1])
			elseif #ret.types == 0 then
				local tup = Tuple({Nil()})
				union:AddType(tup)
			else
				local tup = Tuple(ret.types)
				union:AddType(tup)
			end
		end

		local analyzed_return = union:Simplify()
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
		local i = #out + 1

		for _, expression in ipairs(expressions) do
			local obj, err = self:AnalyzeExpression(expression)

			if not obj then
				self:Error(err)
				obj = Any()
			end

			if obj and obj.Type == "tuple" and obj:HasOneValue() then
				obj = obj:GetWithNumber(1)
			end

			out[i] = obj
			i = i + 1
		end

		return out
	end

	do
		local function add_potential_self(tup)
			local tbl = tup:GetWithNumber(1)

			if tbl and tbl.Type == "union" then tbl = tbl:GetType("table") end

			if not tbl or tbl.Type ~= "table" then return end

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
		end

		function META:CrawlFunctionWithoutOrigin(obj)
			-- use function's arguments in case they have been maniupulated (ie string.gsub)
			local arguments = obj:GetInputSignature():Copy()

			if obj:IsExplicitInputSignature() then
				local new_arguments = add_potential_self(arguments)
				arguments = new_arguments or arguments

				for i = 1, arguments:GetSafeLength() do
					if new_arguments then i = i + 1 end

					arguments:Set(i, Any())
				end
			else
				arguments = add_potential_self(arguments) or arguments

				for _, obj in ipairs(arguments:GetData()) do
					if obj.Type == "upvalue" or obj.Type == "table" then
						obj:ClearMutations()
					end
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
			if not self.deferred_calls then
				self:ReportConstantIfExpressions()
				return
			end

			context:PushCurrentAnalyzer(self)
			self.processing_deferred_calls = true
			local called_count = 0
			local done = {}

			while true do
				local total = #self.deferred_calls

				if total == 0 then break end

				for i = total, 1, -1 do
					local func = self.deferred_calls[i]

					if func then
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
				end

				for i = total, 1, -1 do
					local func = self.deferred_calls[i]

					if func then
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
				end

				for i = total, 1, -1 do
					self.deferred_calls[i] = nil
				end
			end

			self.processing_deferred_calls = false
			self.deferred_calls = false
			self:ReportConstantIfExpressions()
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
		local current_func
		local analyzer_context = require("nattlua.analyzer.context")

		local function on_error(msg)
			local path, line = callstack.get_path_line(3)

			if path == "./nattlua/analyzer/base/base_analyzer.lua" and current_func then
				path, line = callstack.get_func_path_line(current_func)

				-- the name of the function might be path:line
				if path then
					local line = tostring(line)

					if path:sub(-#line) == line then path = path:sub(1, -(#line + 2)) end
				end
			end

			if path then
				if path:sub(1, 1) == "@" then path = path:sub(2) end

				local f, err = io.open(path, "r")

				if f then
					local code = f:read("*all")
					f:close()
					local start = formating.LineCharToSubPos(code, line, 0)
					local stop = start + #(code:sub(start):match("(.-)\n") or "") - 1

					if msg:sub(1, #path) == path then
						msg = msg:sub(#path)
						msg = msg:match("^:%d+:%d+:%s*(.+)") or msg:match("^:%d+%s*(.+)") or msg
					elseif msg:sub(1, #"[string \"") == "[string \"" then
						msg = msg:match("^%b[].-: (.+)")
					end

					local analyzer = analyzer_context:GetCurrentAnalyzer()
					local node = analyzer:GetCurrentExpression() or analyzer:GetCurrentStatement()
					return formating.BuildSourceCodePointMessage(code, path, msg, start, stop)
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
				ret = "error in nattlua error handling"
			end

			return ret, debug.traceback()
		end

		function META:CallLuaTypeFunction(func, scope, args)
			self.function_scope = scope
			current_func = func
			local ok, a, b, c, d, e, f, g = xpcall(func, on_error_safe, table.unpack(args))
			current_func = nil

			if not ok then
				local err = a
				local trace = b
				local stack = self:GetCallStack()

				if stack[1] then self:PushCurrentExpression(stack[#stack].call_node) end

				self:Error(error_messages.analyzer_error(err, trace))

				if stack[1] then self:PopCurrentExpression() end

				return Nil()
			end

			if a == nil then a = Nil() end

			return a, b, c, d, e, f, g
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

		function META:GetCallInfo(level)
			level = level or 1
			local stack = self:GetCallStack()

			if not stack[level] then return end

			local call_info = stack[level]
			local node = call_info.call_node

			if not node then return end

			local start, stop = node:GetStartStop()
			local info = self.compiler:GetCode():SubPosToLineChar(start, stop)
			return {
				source = self.compiler:GetCode():GetName(),
				line = info.line_start,
				col = info.character_start,
				start = start,
				stop = stop,
				obj = call_info.obj,
				scope = call_info.scope,
			}
		end

		function META:TypeTraceback(from)
			from = from or 1
			local out = {}

			for i, v in ipairs(self:GetCallStack()) do
				if v.call_node and i >= from then
					local start, stop = v.call_node:GetStartStop()

					if start and stop then
						local part = self.compiler:GetCode():BuildSourceCodePointMessage("", start, stop, 1)
						table.insert(out, part .. "#" .. tostring(i) .. ": " .. self.compiler:GetCode():GetName())
					end
				end
			end

			return out
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
				s = s .. table.concat(self:TypeTraceback(), "\n")
			end)

			return s
		end

		do
			local push, get, get_offset, pop = META:SetupContextValue("analyzer_environment")

			function META:GetCurrentAnalyzerEnvironment()
				return get(self) or "runtime"
			end

			function META:PushAnalyzerEnvironment(env--[[#: "typesystem" | "runtime"]])
				push(self, env)
			end

			function META:PopAnalyzerEnvironment()
				pop(self)
			end

			function META:IsTypesystem()
				return self:GetCurrentAnalyzerEnvironment() == "typesystem"
			end

			function META:IsRuntime()
				return self:GetCurrentAnalyzerEnvironment() == "runtime"
			end
		end

		do
			local push, get, pop = META:SetupContextRef("global_access_allowed")

			function META:PushNilAccessAllowed()
				push(self)
			end

			function META:PopNilAccessAllowed()
				pop(self)
			end

			function META:IsNilAccessAllowed()
				return get(self)
			end
		end

		do
			local push, get, get_offset, pop = META:SetupContextValue("in_loop")

			function META:IsInUncertainLoop(scope)
				local b = get(self)

				if b == false or b == nil then return false end

				return b == scope:GetNearestLoopScope()
			end

			function META:PushUncertainLoop(scope)
				push(self, scope or false)
			end

			function META:PopUncertainLoop()
				pop(self)
			end
		end

		do
			for _, type in ipairs({"Function", "Table", "Tuple", "Union"}) do
				local push, get, get_offset, pop = META:SetupContextValue("current_type_" .. type)
				META["PushCurrentType" .. type] = function(self, obj)
					push(self, obj)
				end
				META["PopCurrentType" .. type] = function(self)
					pop(self)
				end
				META["GetCurrentType" .. type] = function(self, offset)
					return get_offset(self, offset or 1)
				end
				META["GetCurrentType_" .. type:lower()] = META["GetCurrentType" .. type]
			end
		end

		do
			local push, get, get_offset, pop = META:SetupContextValue("current_statement")

			function META:PushCurrentStatement(node)
				push(self, node)
			end

			function META:PopCurrentStatement()
				pop(self)
			end

			function META:GetCurrentStatement()
				return get(self)
			end
		end

		do
			local push, get, get_offset, pop = META:SetupContextValue("current_expression")

			function META:PushCurrentExpression(node)
				push(self, node)
			end

			function META:PopCurrentExpression()
				pop(self)
			end

			function META:GetCurrentExpression()
				return get(self)
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
