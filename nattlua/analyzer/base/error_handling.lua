local table = _G.table
local type = type
local ipairs = ipairs
local tostring = tostring
local io = io
local debug = debug
local error = error
local Any = require("nattlua.types.any").Any
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

	table.insert(META.OnInitialize, function(self)
		self.diagnostics = {}
	end)

	function META:Assert(ok, err, ...)
		if ok == nil or ok == false then
			err = err or "assertion failed!"
			self:Error(err)
			return Any()
		end

		return ok, err, ...
	end

	function META:ErrorAssert(ok, err)
		if not ok then error(self:ErrorMessageToString(err or "assertion failed!")) end
	end

	function META:ErrorMessageToString(tbl)
		if type(tbl) == "string" then return tbl end

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

		local msg_str = self:ErrorMessageToString(msg)

		if self.processing_deferred_calls then
			msg_str = "DEFERRED CALL: " .. msg_str
		end

		if
			self.expect_diagnostic and
			self.expect_diagnostic[1] and
			self.expect_diagnostic[1].severity == severity and
			msg_str:find(self.expect_diagnostic[1].msg)
		then
			table.remove(self.expect_diagnostic, 1)
			return
		end

		do
			local key = msg_str .. "-" .. "severity"
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

	function META:Error(msg)
		local node = self.current_expression or self.current_statement
		self:ReportDiagnostic(msg, "error", node, node.Code, node:GetStartStop())
	end

	function META:Warning(msg)
		local node = self.current_expression or self.current_statement
		self:ReportDiagnostic(msg, "warning", node, node.Code, node:GetStartStop())
	end

	function META:FatalError(msg)
		error(msg, 2)
	end

	function META:GetDiagnostics()
		return self.diagnostics
	end
end