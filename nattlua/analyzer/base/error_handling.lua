local table = _G.table
local type = type
local ipairs = ipairs
local tostring = tostring
local io = io
local debug = debug
local error = error
local Any = require("nattlua.types.any").Any
local math_abs = math.abs
local assert = _G.assert
return function(META)
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

	function META:ErrorAssert(ok, err)
		if not ok then error(self:ErrorMessageToString(err or "assertion failed!"), 2) end
	end

	function META:ErrorMessageToString(tbl)
		local out = {}

		for i, v in ipairs(tbl) do
			if type(v) == "table" then
				if v.Type then
					table.insert(out, tostring(v))
				else
					table.insert(out, self:ErrorMessageToString(v))
				end
			else
				table.insert(out, tostring(v))
			end
		end

		return table.concat(out, " ")
	end

	function META:ReportDiagnostic(
		msg--[[#: {reasons = {[number] = string}} | {[number] = string}]],
		severity--[[#: "warning" | "error"]],
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
			print(debug.traceback())
		end

		local msg_str = self:ErrorMessageToString(msg)

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
			local key = msg_str .. "-" .. "severity" .. start .. "-" .. stop
			self.diagnostics_map = self.diagnostics_map or {}

			if self.diagnostics_map[key] then return end

			self.diagnostics_map[key] = true
		end

		if self.OnDiagnostic and not self:IsTypeProtectedCall() then
			self:OnDiagnostic(code, msg_str, severity, start, stop, node)
		end

		table.insert(
			self.diagnostics,
			{
				node = node,
				code = code,
				start = start,
				stop = stop,
				msg = msg_str,
				severity = severity,
				traceback = debug.traceback(),
				protected_call = self:IsTypeProtectedCall(),
			}
		)
	end

	function META:PushProtectedCall()
		self:PushContextRef("type_protected_call")
	end

	function META:PopProtectedCall()
		self:PopContextRef("type_protected_call")
	end

	function META:IsTypeProtectedCall()
		return self:GetContextRef("type_protected_call")
	end

	function META:Error(msg, node)
		node = node or self:GetCurrentExpression() or self:GetCurrentStatement()
		self:ReportDiagnostic(msg, "error", node, node.Code, node:GetStartStop())
	end

	function META:Warning(msg, node)
		node = node or self:GetCurrentExpression() or self:GetCurrentStatement()
		self:ReportDiagnostic(msg, "warning", node, node.Code, node:GetStartStop())
	end

	function META:FatalError(msg)
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
