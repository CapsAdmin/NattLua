--[[#local type { Token } = import_type("nattlua/lexer/token.nlua")]]

local quote = require("nattlua.other.quote")
local helpers = {}

function helpers.LinePositionToSubPosition(code--[[#: string]], line--[[#: number]], character--[[#: number]])--[[#: number]]
	local line_pos = 1

	for i = 1, #code do
		local c = code:sub(i, i)

		if line_pos == line then
			local char_pos = 1

			for i = i, i + character do
				local c = code:sub(i, i)
				if char_pos == character then return i end
				char_pos = char_pos + 1
			end

			return i
		end

		if c == "\n" then
			line_pos = line_pos + 1
		end
	end

	return #code
end

function helpers.SubPositionToLinePosition(code--[[#: string]], start--[[#: number]], stop--[[#: number]])
	assert(type(code) == "string")
	assert(type(start) == "number")
	assert(type(stop) == "number")
	local line = 1
	local line_start
	local line_stop
	local within_start
	local within_stop
	local character_start
	local character_stop
	local line_pos = 0
	local char_pos = 0

	for i = 1, #code do
		local char = code:sub(i, i)

		if i == stop then
			line_stop = line
			character_stop = char_pos
		end

		if i == start then
			line_start = line
			within_start = line_pos
			character_start = char_pos
		end

		if char == "\n" then
			if line_stop then
				within_stop = i

				break
			end

			line = line + 1
			line_pos = i
			char_pos = 0
		else
			char_pos = char_pos + 1
		end
	end

	if not within_stop then
		within_stop = #code + 1
	end

	if not within_start then return end
	return
		{
			character_start = character_start or
			0,
			character_stop = character_stop or
			0,
			sub_line_before = {within_start + 1, start - 1},
			sub_line_after = {stop + 1, within_stop - 1},
			line_start = line_start or
			0,
			line_stop = line_stop or
			0,
		}
end

do
	local function get_lines_before(code--[[#: string]], pos--[[#: number]], lines--[[#: number]])--[[#: number,number,number]]
		local line = 1
		local first_line_pos = 1

		for i = pos, 1, -1 do
			local char = code:sub(i, i)

			if char == "\n" then
				if line == 1 then
					first_line_pos = i + 1
				end

				if line == lines + 1 then return i - 1, first_line_pos - 1, line end
				line = line + 1
			end
		end

		return 1, first_line_pos, line
	end

	local function get_lines_after(code--[[#: string]], pos--[[#: number]], lines--[[#: number]])--[[#: number,number,number]]
		local line = 1
		local first_line_pos = 1

		for i = pos, #code do
			local char = code:sub(i, i)

			if char == "\n" then
				if line == 1 then
					first_line_pos = i
				end

				if line == lines + 1 then return first_line_pos + 1, i - 1, line end
				line = line + 1
			end
		end

		return first_line_pos + 1, #code, line - 1
	end

	do
		-- TODO: wtf am i doing here?
		local args
		local fmt = function(num--[[#: string]])
			num = tonumber(num)
			if type(args[num]) == "table" then return quote.QuoteTokens(args[num]) end
			return quote.QuoteToken(args[num] or "?")
		end

		function helpers.FormatMessage(msg--[[#: string]], ...)
			args = {...}
			msg = msg:gsub("$(%d)", fmt)
			return msg
		end
	end

	local function clamp(num--[[#: number]], min--[[#: number]], max--[[#: number]])
		return math.min(math.max(num, min), max)
	end

	function helpers.FormatError(code--[[#: string]], path--[[#: string]], msg--[[#: string]], start--[[#: number]], stop--[[#: number]], size--[[#: number]], ...)
		size = size or 2
		msg = helpers.FormatMessage(msg, ...)
		start = clamp(start, 1, #code)
		stop = clamp(stop, 1, #code)
		local data = helpers.SubPositionToLinePosition(code, start, stop)

		if not data then
			local str = ""

			if path then
				str = str .. path .. ":INVALID: "
			end

			if msg then
				str = str .. msg
			end

			return str
		end

		local line_start, line_stop = data.line_start, data.line_stop
		local pre_start_pos, pre_stop_pos, lines_before = get_lines_before(code, start, size)
		local post_start_pos, post_stop_pos, lines_after = get_lines_after(code, stop, size)
		local spacing = #tostring(data.line_stop + lines_after)
		local lines = {}

		do
			if lines_before >= 0 then
				local line = math.max(line_start - lines_before - 1, 1)

				for str in (code:sub(pre_start_pos, pre_stop_pos)):gmatch("(.-)\n") do
					local prefix = (" "):rep(spacing - #tostring(line)) .. line .. " | "
					table.insert(lines, prefix .. str)
					line = line + 1
				end
			end

			do
				local line = line_start

				for str in (code:sub(start, stop) .. "\n"):gmatch("(.-)\n") do
					local prefix = (" "):rep(spacing - #tostring(line)) .. line .. " | "

					if line == line_start then
						prefix = prefix .. code:sub(table.unpack(data.sub_line_before))
					end

					local test = str

					if line == line_stop then
						str = str .. code:sub(table.unpack(data.sub_line_after))
					end

					str = str .. "\n" .. (" "):rep(#prefix) .. ("^"):rep(math.max(#test, 1))
					table.insert(lines, prefix .. str)
					line = line + 1
				end
			end

			if lines_after > 0 then
				local line = line_stop + 1

				for str in (code:sub(post_start_pos, post_stop_pos) .. "\n"):gmatch("(.-)\n") do
					local prefix = (" "):rep(spacing - #tostring(line)) .. line .. " | "
					table.insert(lines, prefix .. str)
					line = line + 1
				end
			end
		end

		local str = table.concat(lines, "\n")
		local path = path and
			(path:gsub("@", "") .. ":" .. line_start .. ":" .. data.character_start) or
			""
		local msg = path .. (msg and ": " .. msg or "")
		local post = (" "):rep(spacing - 2) .. "-> | " .. msg
		local pre = ("-"):rep(100)
		str = "\n" .. pre .. "\n" .. str .. "\n" .. pre .. "\n" .. post .. "\n"
		str = str:gsub("\t", " ")
		return str
	end
end

do
	local blacklist = {
			parent = true,
			inferred_type = true,
			scope = true,
			parser = true,
			children = true,
			mutations = true,
			code = true,
		}

	local function traverse(tbl--[[#: any]], done--[[#: any]], out--[[#: any]])
		for k, v in pairs(tbl) do
			if not blacklist[k] then
				if type(v) == "table" and not done[v] then
					done[v] = true
					traverse(v, done, out)
				end

				if type(v) == "number" then
					if tbl.type ~= "space" then
						if k == "start" then
							out.max = math.min(out.max, v)
						elseif k == "stop" then
							out.min = math.max(out.min, v)
						end
					end
				end
			end
		end
	end

	function helpers.LazyFindStartStop(tbl--[[#: any]], skip_function_body--[[#: boolean | nil]])--[[#: number,number]]
		if tbl.start and tbl.stop then return tbl.start, tbl.stop end

		if tbl.type == "statement" then
			if tbl.kind == "call_expression" then return helpers.LazyFindStartStop(tbl.value, skip_function_body) end
		elseif tbl.type == "expression" then
			if tbl.kind == "value" then return helpers.LazyFindStartStop(tbl.value, skip_function_body) end

			if tbl.kind == "binary_operator" then
				local l = helpers.LazyFindStartStop(tbl.left, skip_function_body)
				local _, r = helpers.LazyFindStartStop(tbl.right, skip_function_body)
				return l, r
			end

			if tbl.kind == "postfix_call" then
				if tbl.tokens["call("] then
					if skip_function_body and tbl.left then return helpers.LazyFindStartStop(tbl.left, skip_function_body) end
					local l = helpers.LazyFindStartStop(tbl.tokens["call("], skip_function_body)
					local _, r = helpers.LazyFindStartStop(tbl.tokens["call)"], skip_function_body)
					return l, r
				else
					return helpers.LazyFindStartStop(tbl.expressions[1], skip_function_body)
				end
			end
		end

		local out = {min = -math.huge, max = math.huge}

		if not tbl.tokens or not next(tbl.tokens) then
			error("NO TOKENS!!! " .. tostring(tbl))
		end

		if skip_function_body and tbl.type == "expression" and tbl.kind == "function" then
			out.min = math.min(out.min, tbl.tokens["function"].start)
			out.max = math.min(out.max, tbl.tokens["arguments)"].stop)
		else
			traverse(tbl.tokens, {}, out)
		end

		return out.max, out.min
	end
end

function helpers.GetDataFromLineCharPosition(tokens--[[#: {[number] = Token}]], code--[[#: string]], line--[[#: number]], char--[[#: number]])
	local sub_pos = helpers.LinePositionToSubPosition(code, line, char)

	for _, token in ipairs(tokens) do
		local found = token.stop >= sub_pos-- and token.stop <= sub_pos

        if not found then
			if token.whitespace then
				for _, token in ipairs(token.whitespace) do
					if token.stop >= sub_pos then
						found = true

						break
					end
				end
			end
		end

		if found then return token, helpers.SubPositionToLinePosition(code, token.start, token.stop) end
	end
end

function helpers.JITOptimize()
	if not _G.jit then return end
	require("jit.opt")
	jit.opt.start(
		"maxtrace=65535", -- 1000 1-65535: maximum number of traces in the cache
        "maxrecord=8000", -- 4000: maximum number of recorded IR instructions
        "maxirconst=8000", -- 500: maximum number of IR constants of a trace
        "maxside=5000", -- 100: maximum number of side traces of a root trace
        "maxsnap=5000", -- 500: maximum number of snapshots for a trace
        "hotloop=56", -- 56: number of iterations to detect a hot loop or hot call
        "hotexit=10", -- 10: number of taken exits to start a side trace
        "tryside=4", -- 4: number of attempts to compile a side trace
        "instunroll=1000", -- 4: maximum unroll factor for instable loops
        "loopunroll=1000", -- 15: maximum unroll factor for loop ops in side traces
        "callunroll=1000", -- 3: maximum unroll factor for pseudo-recursive calls
        "recunroll=0", -- 2: minimum unroll factor for true recursion
        "maxmcode=16384", -- 512: maximum total size of all machine code areas in KBytes
        --jit.os == "x64" and "sizemcode=64" or "sizemcode=32", -- Size of each machine code area in KBytes (Windows: 64K)
        "+fold", -- Constant Folding, Simplifications and Reassociation
        "+cse", -- Common-Subexpression Elimination
        "+dce", -- Dead-Code Elimination
        "+narrow", -- Narrowing of numbers to integers
        "+loop", -- Loop Optimizations (code hoisting)
        "+fwd", -- Load Forwarding (L2L) and Store Forwarding (S2L)
        "+dse", -- Dead-Store Elimination
        "+abc", -- Array Bounds Check Elimination
        "+sink", -- Allocation/Store Sinking
        "+fuse" -- Fusion of operands into instructions
    )

	if jit.version_num >= 20100 then
		jit.opt.start("minstitch=0") -- 0: minimum number of IR ins for a stitched trace.
    end
end

local function inject_full_path()
	local ok, lib = pcall(require, "jit.util")

	if ok then
		if lib then
			if lib.funcinfo then
				lib._old_funcinfo = lib._old_funcinfo or lib.funcinfo

				function lib.funcinfo(...)
					local ret = {lib._old_funcinfo(...)}
					local info = ret[1]

					if
						info and
						type(info) == "table" and
						type(info.loc) == "string" and
						type(info.source) == "string" and
						type(info.currentline) == "number" and
						info.source:sub(1, 1) == "@"
					then
						info.loc = info.source:sub(2) .. ":" .. info.currentline
					end

					return unpack(ret)
				end
			end
		end
	end
end

function helpers.EnableJITDumper()
	if not _G.jit then return end
	if jit.version_num ~= 20100 then return end
	inject_full_path()
	local jit = require("jit")
	local jutil = require("jit.util")
	local vmdef = require("jit.vmdef")
	local funcinfo, traceinfo = jutil.funcinfo, jutil.traceinfo
	local type, format = type, string.format
	local stdout, stderr = io.stdout, io.stderr
	local out = stdout

    ------------------------------------------------------------------------------

    local startloc, startex

	local function fmtfunc(func--[[#: any]], pc--[[#: any]])
		local fi = funcinfo(func, pc)

		if fi.loc then
			return fi.loc
		elseif fi.ffid then
			return vmdef.ffnames[fi.ffid]
		elseif fi.addr then
			return format("C:%x", fi.addr)
		else
			return "(?)"
		end
	end

    -- Format trace error message.
    local function fmterr(err--[[#: any]], info--[[#: any]])
		if type(err) == "number" then
			if type(info) == "function" then
				info = fmtfunc(info)
			end

			err = format(vmdef.traceerr[err], info)
		end

		return err
	end

    -- Dump trace states.
    local function dump_trace(what--[[#: any]], tr--[[#: any]], func--[[#: any]], pc--[[#: any]], otr--[[#: any]], oex--[[#: any]])
		if what == "start" then
			startloc = fmtfunc(func, pc)
			startex = otr and "(" .. otr .. "/" .. (oex == -1 and "stitch" or oex) .. ") " or ""
		else
			if what == "abort" then
				local loc = fmtfunc(func, pc)

				if loc ~= startloc then
					out:write(format("[TRACE --- %s%s -- %s at %s]\n", startex, startloc, fmterr(otr, oex), loc))
				else
					out:write(format("[TRACE --- %s%s -- %s]\n", startex, startloc, fmterr(otr, oex)))
				end
			elseif what == "stop" then
				local info = traceinfo(tr)
				local link, ltype = info.link, info.linktype

				if ltype == "interpreter" then
					out:write(format("[TRACE %3s %s%s -- fallback to interpreter]\n", tr, startex, startloc))
				elseif ltype == "stitch" then
					out:write(format(
						"[TRACE %3s %s%s %s %s]\n",
						tr,
						startex,
						startloc,
						ltype,
						fmtfunc(func, pc)
					))
				elseif link == tr or link == 0 then
					out:write(format("[TRACE %3s %s%s %s]\n", tr, startex, startloc, ltype))
				elseif ltype == "root" then
					out:write(format("[TRACE %3s %s%s -> %d]\n", tr, startex, startloc, link))
				else
					out:write(format(
						"[TRACE %3s %s%s -> %d %s]\n",
						tr,
						startex,
						startloc,
						link,
						ltype
					))
				end
			else
				out:write(format("[TRACE %s]\n", what))
			end

			out:flush()
		end
	end

	jit.attach(dump_trace, "trace")
end

function helpers.GlobalLookup()
	local _G = _G
	local tostring = tostring
	local print = print
	local rawset = rawset
	local rawget = rawget
	setmetatable(_G, {
		__index = function(_, key)
			print("_G." .. key)
			print(debug.traceback():match(".-\n.-\n(.-)\n"))
			return rawget(_G, key)
		end,
		__newindex = function(_, key, val)
			print("_G." .. key .. " = " .. tostring(val))
			print(debug.traceback():match(".-\n.-\n(.-)\n"))
			rawset(_G, key, val)
		end,
	})
end

return helpers
