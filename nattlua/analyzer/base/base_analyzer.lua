local load = loadstring or load
local types = require("nattlua.types.types")
local helpers = require("nattlua.other.helpers")
local LexicalScope = require("nattlua.other.lexical_scope")
return function(META)
	local table_insert = table.insert

	function META:StringToNumber(node, str)
		if str:sub(1, 2) == "0b" then
			return tonumber(str:sub(3))
		elseif str:lower():sub(-3) == "ull" then
			return tonumber(str:sub(1, -4))
		elseif str:lower():sub(-2) == "ll" then
			return tonumber(str:sub(1, -3))
		end

		local num = tonumber(str)

		if not num then
			self:Error(node, "unable to convert " .. str .. " to number")
		end

		return num
	end

	require("nattlua.analyzer.base.scopes")(META)
	require("nattlua.analyzer.base.events")(META)
	require("nattlua.analyzer.base.error_handling")(META)

	function META:AnalyzeExpressions(expressions, env)
		if not expressions then return end
		local out = {}

		for _, expression in ipairs(expressions) do
			local ret = {self:AnalyzeExpression(expression, env)}

			for _, v in ipairs(ret) do
				table.insert(out, v)
			end
		end

		return out
	end

	do
		local function add_potential_self(tup)
			local self = tup:Get(1)

			if self and self.Type == "union" then
				self = self:GetType("table")
			end

			if self and self.potential_self then
				local meta = self
				local self = self.potential_self:Copy()

				if self.Type == "union" then
					for _, obj in ipairs(self:GetData()) do
						obj:SetMetaTable(meta)
					end
				else
					self:SetMetaTable(meta)
				end

				local new_tup = types.Tuple({})

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
            -- diregard arguments and use function's arguments in case they have been maniupulated (ie string.gsub)
            arguments = obj:GetArguments():Copy()
            -- arguments should be a contract
            for i, v in ipairs(arguments:GetData()) do
				v:SetContract(v)
			end

			arguments = add_potential_self(arguments)
			self:Assert(node, self:Call(obj, arguments, node))
		end

		function META:CallMeLater(...)
			self.deferred_calls = self.deferred_calls or {}
			table.insert(self.deferred_calls, 1, {...})
		end

		function META:AnalyzeUnreachableCode()
			if not self.deferred_calls then return end
			local total = #self.deferred_calls
			self:FireEvent("analyze_unreachable_code_start", total)
			self.processing_deferred_calls = true
			local called_count = 0

			for _, v in ipairs(self.deferred_calls) do
				if not v[1].called and v[1].explicit_arguments then
					local time = os.clock()
					self:FireEvent("analyze_unreachable_function_start", v[1], called_count, total)
					call(self, table.unpack(v))
					called_count = called_count + 1
					self:FireEvent("analyze_unreachable_function_stop", v[1], called_count, total, os.clock() - time)
				end
			end

			for _, v in ipairs(self.deferred_calls) do
				if not v[1].called and not v[1].explicit_arguments then
					local time = os.clock()
					self:FireEvent("analyze_unreachable_function_start", v[1], called_count, total)
					call(self, table.unpack(v))
					called_count = called_count + 1
					self:FireEvent("analyze_unreachable_function_stop", v[1], called_count, total, os.clock() - time)
				end
			end

			self.processing_deferred_calls = false
			self.deferred_calls = nil
			self:FireEvent("analyze_unreachable_code_stop", called_count, total)
		end
	end

	do
		local helpers = require("nattlua.other.helpers")

		function META:CompileLuaTypeCode(code, node)
            
            -- append newlines so that potential line errors are correct
            if node.code then
				local start, stop = helpers.LazyFindStartStop(node)
				local line = helpers.SubPositionToLinePosition(node.code, start, stop).line_start
				code = ("\n"):rep(line - 1) .. code
			end

			local func, err = load(code, node.name)

			if not func then
                --[[
                    this happens rarely and randomly for some reason. 
                    when a function is rendered it's supposed to result in "return function(a,b,c) ..."
                    but instead what happens is something like "return ) ..." causing syntax error
                ]]
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

		local function genscopemeta(self, scope, env)
			return setmetatable(
				{},
				{
					__index = function(_, key)
						return self:GetLocalOrEnvironmentValue(key, env, scope)
					end,
					__newindex = function(_, key, val)
						return self:SetLocalOrEnvironmentValue(key, val, env, scope)
					end,
				}
			)
		end

		function META:GetScopeHelper(scope)
			self.scope_helper = {
					typesystem = genscopemeta(self, scope, "typesystem"),
					runtime = genscopemeta(self, scope, "runtime"),
				}
			self.scope_helper.scope = scope
			return self.scope_helper
		end

		function META:CallLuaTypeFunction(node, func, scope, ...)
			_G.nl = require("nattlua")
			_G.types = types
			_G.analyzer = self
			_G.env = self:GetScopeHelper(scope)
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
							msg = helpers.FormatError(code, name, rest, start, stop)
						end
					end
				end

				local trace = self:TypeTraceBack()

				if trace then
					msg = msg .. "\ntraceback:\n" .. trace
				end

				self:Error(node, msg)
			end

			if res[1] == nil then
				res[1] = types.Nil()
			end

			return table.unpack(res)
		end

		function META:TypeTraceBack()
			if not self.call_stack then return "" end
			local str = ""

			for i, v in ipairs(self.call_stack) do
				if v.call_node then
					local start, stop = helpers.LazyFindStartStop(v.call_node)

					if start and stop then
						local part = helpers.FormatError(
							self.compiler.code,
							self.compiler.name,
							"",
							start,
							stop,
							1
						)
						str = str .. part .. "#" .. tostring(i) .. ": " .. self.compiler.name
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
				s = s .. self:TypeTraceBack()
			end)

			return s
		end
	end
end
