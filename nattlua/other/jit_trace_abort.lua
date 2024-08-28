local jit = require("jit")
local jutil = require("jit.util")
local vmdef = require("jit.vmdef")
local funcinfo, traceinfo = jutil.funcinfo, jutil.traceinfo
local type, format = type, string.format
local out = io.stdout

local function fmtfunc(func, pc)
	local fi = funcinfo(func, pc)

	if fi.loc then
		local source = fi.source

		if source:sub(1, 1) == "@" then source = source:sub(2) end

		return source .. ":" .. fi.currentline
	elseif fi.ffid then
		return vmdef.ffnames[fi.ffid]
	elseif fi.addr then
		return format("C:%x", fi.addr)
	else
		return "(?)"
	end
end

local function fmterr(err, info)
	if type(err) == "number" then
		if type(info) == "function" then info = fmtfunc(info) end

		err = format(vmdef.traceerr[err], info)
	end

	return err
end

local startloc
local startex

local function dump_trace(what, tr, func, pc, otr, oex)
	if what == "start" then
		startloc = fmtfunc(func, pc)
		startex = otr and "(" .. otr .. "/" .. oex .. ") " or ""
	else
		if what == "abort" then
			local loc = fmtfunc(func, pc)

			if loc ~= startloc then
				out:write(
					format("[TRACE --- %s%s -- %s at %s]\n", startex, startloc, fmterr(otr, oex), loc)
				)
			else
				out:write(format("[TRACE --- %s%s -- %s]\n", startex, startloc, fmterr(otr, oex)))
			end
		elseif what == "stop" then
			local info = traceinfo(tr)
			local link, ltype = info.link, info.linktype

			if ltype == "interpreter" then
				out:write(format("[TRACE %3s %s%s -- fallback to interpreter]\n", tr, startex, startloc))
			elseif link == tr or link == 0 then
				out:write(format("[TRACE %3s %s%s %s]\n", tr, startex, startloc, ltype))
			elseif ltype == "root" then
				out:write(format("[TRACE %3s %s%s -> %d]\n", tr, startex, startloc, link))
			else
				out:write(format("[TRACE %3s %s%s -> %d %s]\n", tr, startex, startloc, link, ltype))
			end
		else
			out:write(format("[TRACE %s]\n", what))
		end

		out:flush()
	end
end

local trace_abort = {}
local active = false

function trace_abort.Stop()
	if active then
		active = false
		jit.attach(dump_trace)
		out = nil
	end
end

function trace_abort.Start()
	if active then trace_abort.Stop() end

	jit.attach(dump_trace, "trace")
	active = true
end

do
	return trace_abort
end

local jit = require("jit")
local jit_profiler = require("jit.profile")
local jit_vmdef = require("jit.vmdef")
local jit_util = require("jit.util")
local raw_samples
local raw_samples_i
local trace_abort = {}
local funcinfo = jit_util.funcinfo
local traceinfo = jit_util.traceinfo
local start_location

local function fmtfunc(func, pc)
	local fi = funcinfo(func, pc)
	return {path = fi.source, line = fi.currentline}
end

local function dump_trace(what, trace_id, func, pc, trace_error_id, trace_error_arg)
	if what == "start" then
		start_location = fmtfunc(func, pc)
	elseif what == "abort" then
		local stop_location = fmtfunc(func, pc)
		raw_samples[raw_samples_i] = {
			start_location = start_location,
			stop_location = stop_location,
			trace_error_id = trace_error_id,
			trace_error_arg = trace_error_arg,
		}
		raw_samples_i = raw_samples_i + 1
	elseif what == "stop" then
		local stop_location = fmtfunc(func, pc)

		if traceinfo(trace_id).linktype == "interpreter" then
			raw_samples[raw_samples_i] = {
				start_location = start_location,
				stop_location = stop_location,
				interpreter_fallback = true,
			}
			raw_samples_i = raw_samples_i + 1
		end
	end
end

function trace_abort.Start()
	raw_samples = {}
	raw_samples_i = 1
	jit.attach(dump_trace, "trace")
end

function trace_abort.Stop()
	jit.attach(dump_trace)
	local data = {}

	for _, args in ipairs(raw_samples) do
		local info = args.stop_location
		local reason

		if args.interpreter_fallback then
			reason = "fallback to interpreter"
		else
			reason = jit_vmdef.traceerr[args.trace_error_id] or args.trace_error_id
			local trace_error_arg = args.trace_error_arg

			if trace_error_arg then
				if type(trace_error_arg) == "number" and reason:find("bytecode") then
					trace_error_arg = string.sub(jit_vmdef.bcnames, trace_error_arg * 6 + 1, trace_error_arg * 6 + 6)
					reason = reason:gsub("(%%d)", "%%s")
				end

				reason = reason:format(trace_error_arg)
			end
		end

		local path = info.path
		local line = info.line

		if path:sub(1, 1) == "@" then path = path:sub(2) end

		data[path] = data[path] or {}
		data[path][line] = data[path][line] or {}
		data[path][line][reason] = (data[path][line][reason] or 0) + 1
	end

	local out = {}

	for path, lines in pairs(data) do
		local temp = {}

		for line, reasons in pairs(lines) do
			table.insert(temp, "\t" .. path .. ":" .. line)

			for reason, count in pairs(reasons) do
				table.insert(temp, "\tx" .. count .. "\t" .. reason)
			end
		end

		if #temp > 0 then
			table.insert(temp, 1, path .. ":")
			table.insert(out, table.concat(temp, "\n") .. "\n")
		end
	end

	return table.concat(out)
end

return trace_abort