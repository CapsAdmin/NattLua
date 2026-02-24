local table = _G.table
local table_insert = table.insert
local type = type
local ipairs = ipairs
local tostring = tostring
local io = io
local debug = debug
local error = error
local Any = require("nattlua.types.any").Any
local error_messages = require("nattlua.error_messages")
local callstack = require("nattlua.other.callstack")
local math_abs = math.abs
local assert = _G.assert
return function(META--[[#: any]])
	--[[#type META.diagnostics = {
		[1 .. inf] = {
			node = any,
			start = number,
			stop = number,
			msg = string,
			severity = "warning" | "error",
			traceback = string,
		},
	}]]

	META:AddInitializer(function(self)
		self.diagnostics = {}
		self.constant_expression_warnings = {}
		self.constant_expression_warnings_ordered = {}
	end)

	function META:Assert(ok, err, ...)
		return self:AssertFallback(Any(), ok, err, ...)
	end

	function META:GetFirstValue(obj, err)
		if not obj then
			self:Error(err)
			return nil
		end

		local val, err = obj:GetFirstValue()

		if not val then
			self:Error(err)
			return obj
		end

		return val
	end

	function META:ErrorIfFalse(ok, err, ...)
		if not ok then self:Error(err) end

		return ok, err, ...
	end

	function META:AssertFallback(obj, ok, err, ...)
		if not ok then
			self:Error(err)
			return obj
		end

		return ok, err, ...
	end

	function META:AssertWarning(ok, err, ...)
		if not ok then
			self:Warning(err)
			return Any()
		end

		return ok, err, ...
	end

	function META:AssertWithNode(node, ok, err, ...)
		if not ok then
			self:Error(err, node)
			return Any()
		end

		return ok, err, ...
	end

	function META:AssertFatal(ok, err)
		if not ok then
			error(error_messages.ErrorMessageToString(err or "assertion failed!"), 2)
		end
	end

	function META:ReportDiagnostic(
		msg--[[#: {reasons = {[number] = string}} | {[number] = string}]],
		severity--[[#: "warning" | "error" | "fatal"]],
		level--[[#: number | nil]],
		node--[[#: any]],
		code--[[#: any]],
		start--[[#: number]],
		stop--[[#: number]]
	)
		if self.SuppressDiagnostics then return end

		if math_abs(start - stop) > 10000 then
			start = 0
			stop = 0
			print("WARNING: Diagnostic start/stop is too large, resetting to 0")
			print("EXPRESSION: ", self:GetCurrentExpression())
			print("STATEMENT: ", self:GetCurrentStatement())
			print("NODE: ", node)
			print(callstack.traceback())
		end

		local msg_str = error_messages.ErrorMessageToString(msg)

		if
			not _G.TEST and
			severity == "error" and
			(
				msg_str:find("does not exist", nil, true) or
				msg_str:find("has no key", nil, true)
			)
		then
			severity = "warning"
			level = 1
		end

		if self.processing_deferred_calls then
			msg_str = "DEFERRED CALL: " .. msg_str
		end

		if
			self.expect_diagnostic and
			self.expect_diagnostic[1] and
			self.expect_diagnostic[1].severity == severity
		then
			if not msg_str:find(self.expect_diagnostic[1].msg) then
				error(
					"expected to find diagnostic: " .. self.expect_diagnostic[1].msg .. "\ngot: \n" .. msg_str
				)
			end

			table.remove(self.expect_diagnostic, 1)
			return
		end

		do
			local key = msg_str .. "-" .. (
					severity or
					"error"
				) .. "-" .. (
					start or
					0
				) .. "-" .. (
					stop or
					0
				)
			self.diagnostics_map = self.diagnostics_map or {}

			if self.diagnostics_map[key] then return end

			self.diagnostics_map[key] = true
		end

		if self.OnDiagnostic and not self:IsTypeProtectedCall() then
			self:OnDiagnostic(code, msg_str, severity, start, stop, node, level)
		end

		table_insert(
			self.diagnostics,
			{
				node = node,
				code = code,
				start = start,
				stop = stop,
				msg = msg_str,
				severity = severity,
				level = level,
				traceback = callstack.traceback(),
				protected_call = self:IsTypeProtectedCall(),
			}
		)
	end

	do
		local push, get, pop = META:SetupContextRef("type_protected_call")

		function META:PushProtectedCall()
			push(self)
		end

		function META:PopProtectedCall()
			pop(self)
		end

		function META:IsTypeProtectedCall()
			return get(self)
		end
	end

	function META:Error(msg, level_or_node, node)
		local level

		if type(level_or_node) == "number" then
			level = level_or_node
		else
			node = level_or_node
		end

		node = node or self:GetCurrentExpression() or self:GetCurrentStatement()
		local start, stop = 0, 0

		if node then start, stop = node:GetStartStop() end

		self:ReportDiagnostic(msg, "error", level, node, node and node.Code, start, stop)
	end

	function META:Warning(msg, level_or_node, node)
		local level

		if type(level_or_node) == "number" then
			level = level_or_node
		else
			node = level_or_node
		end

		node = node or self:GetCurrentExpression() or self:GetCurrentStatement()
		local start, stop = 0, 0

		if node then start, stop = node:GetStartStop() end

		self:ReportDiagnostic(msg, "warning", level, node, node and node.Code, start, stop)
	end

	function META:FatalError(msg, level_or_node, node)
		local level

		if type(level_or_node) == "number" then
			level = level_or_node
		else
			node = level_or_node
		end

		local node = node or self:GetCurrentExpression() or self:GetCurrentStatement()
		local start, stop = 0, 0

		if node then start, stop = node:GetStartStop() end

		self:ReportDiagnostic(msg, "fatal", level, node, node and node.Code, start, stop)
		error(msg, 2)
	end

	function META:GetDiagnostics()
		return self.diagnostics
	end

	function META:ConstantIfExpressionWarning(msg, extra_key)
		local node = self:GetCurrentExpression() or self:GetCurrentStatement()
		assert(node)
		local key = extra_key or node

		if self.constant_expression_warnings[key] then
			self.constant_expression_warnings[key] = false

			for i = #self.constant_expression_warnings_ordered, 1, -1 do
				if self.constant_expression_warnings_ordered[i].key == key then
					table.remove(self.constant_expression_warnings_ordered, i)

					break
				end
			end
		end

		if self.constant_expression_warnings[key] == false then return end

		self.constant_expression_warnings[key] = {msg = msg, node = node, key = key}
		table.insert(self.constant_expression_warnings_ordered, self.constant_expression_warnings[key])
	end

	function META:ReportConstantIfExpressions()
		for _, info in ipairs(self.constant_expression_warnings_ordered) do
			if info ~= false and info.msg then self:Warning(info.msg, info.node) end
		end
	end
end
