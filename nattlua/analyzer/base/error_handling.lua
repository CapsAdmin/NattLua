local table = require("table")
local type = type
local ipairs = ipairs
local tostring = tostring
local io = io
local debug = debug
local error = error
local helpers = require("nattlua.other.helpers")
local Any = require("nattlua.types.any").Any
return function(META)
--[[#	type META.diagnostics = {
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

	function META:Assert(node, ok, err)
		if ok == false then
			err = err or "unknown error"
			self:Error(node, err)
			return Any():SetNode(node)
		end

		return ok
	end

	function META:ErrorAssert(ok, err)
		if not ok then
			error(self:ErrorMessageToString(err))
		end
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

		return table.concat(out)
	end

	function META:ReportDiagnostic(node, msg--[[#: {reasons = {[number] = string}} | {[number] = string}]], severity--[[#: "warning" | "error"]])
		if self.SuppressDiagnostics then return end

		if not node then
			io.write(
				"reporting diagnostic without node, defaulting to current expression or statement\n"
			)
			io.write(debug.traceback(), "\n")
			node = self.current_expression or self.current_statement
		end

		if not msg or not severity then
			io.write("msg = ", tostring(msg), "\n")
			io.write("severity = ", tostring(severity), "\n")
			io.write(debug.traceback(), "\n")
			error("bad call to ReportDiagnostic")
		end

		local msg_str = self:ErrorMessageToString(msg)
		local key = msg_str .. "-" .. tostring(node) .. "-" .. "severity"
		self.diagnostics_map = self.diagnostics_map or {}
		if self.diagnostics_map[key] then return end
		self.diagnostics_map[key] = true
		severity = severity or "warning"
		local start, stop = helpers.LazyFindStartStop(node)

		if self.OnDiagnostic then
			self:OnDiagnostic(
				node.Code,
				msg_str,
				severity,
				start,
				stop
			)
		end

		table.insert(
			self.diagnostics,
			{
				node = node,
				start = start,
				stop = stop,
				msg = msg_str,
				severity = severity,
				traceback = debug.traceback(),
			}
		)
	end

	function META:Error(node, msg)
		return self:ReportDiagnostic(node, msg, "error")
	end

	function META:Warning(node, msg)
		return self:ReportDiagnostic(node, msg, "warning")
	end

	function META:FatalError(msg, node)
		node = node or self.current_expression or self.current_statement
		if node then
			self:ReportDiagnostic(node, msg, "fatal")
		end
		error(msg, 2)
	end

	function META:GetDiagnostics()
		return self.diagnostics
	end
end
