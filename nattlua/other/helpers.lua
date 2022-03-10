--[[#local type { Token } = import("~/nattlua/lexer/token.nlua")]]

--[[#import("~/nattlua/code/code.lua")]]
local math = require("math")
local table = require("table")
local quote = require("nattlua.other.quote")
local type = _G.type
local pairs = _G.pairs
local assert = _G.assert
local tonumber = _G.tonumber
local tostring = _G.tostring
local next = _G.next
local error = _G.error
local ipairs = _G.ipairs
local jit = _G.jit--[[# as jit | nil]]
local pcall = _G.pcall
local unpack = _G.unpack
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

		if c == "\n" then line_pos = line_pos + 1 end
	end

	return #code
end

function helpers.SubPositionToLinePosition(code--[[#: string]], start--[[#: number]], stop--[[#: number]])
	local line = 1
	local line_start
	local line_stop
	local within_start = 1
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

	if not within_stop then within_stop = #code + 1 end

	return {
		character_start = character_start or 0,
		character_stop = character_stop or 0,
		sub_line_before = {within_start + 1, start - 1},
		sub_line_after = {stop + 1, within_stop - 1},
		line_start = line_start or 0,
		line_stop = line_stop or 0,
	}
end

do
	local function get_lines_before(code--[[#: string]], pos--[[#: number]], lines--[[#: number]])--[[#: number,number,number]]
		local line--[[#: number]] = 1
		local first_line_pos = 1

		for i = pos, 1, -1 do
			local char = code:sub(i, i)

			if char == "\n" then
				if line == 1 then first_line_pos = i + 1 end

				if line == lines + 1 then return i - 1, first_line_pos - 1, line end

				line = line + 1
			end
		end

		return 1, first_line_pos, line
	end

	local function get_lines_after(code--[[#: string]], pos--[[#: number]], lines--[[#: number]])--[[#: number,number,number]]
		local line--[[#: number]] = 1 -- to prevent warning about it always being true when comparing against 1
		local first_line_pos = 1

		for i = pos, #code do
			local char = code:sub(i, i)

			if char == "\n" then
				if line == 1 then first_line_pos = i end

				if line == lines + 1 then return first_line_pos + 1, i - 1, line end

				line = line + 1
			end
		end

		return first_line_pos + 1, #code, line - 1
	end

	do
		-- TODO: wtf am i doing here?
		local args--[[#: List<|string | List<|string|>|>]]
		local fmt = function(str--[[#: string]])
			local num = tonumber(str)

			if not num then error("invalid format argument " .. str) end

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

	function helpers.FormatError(
		code--[[#: Code]],
		msg--[[#: string]],
		start--[[#: number]],
		stop--[[#: number]],
		size--[[#: number]],
		...
	)
		local lua_code = code:GetString()
		local path = code:GetName()
		size = size or 2
		msg = helpers.FormatMessage(msg, ...)
		start = clamp(start, 1, #lua_code)
		stop = clamp(stop, 1, #lua_code)
		local data = helpers.SubPositionToLinePosition(lua_code, start, stop)

		if not data then return end

		local line_start, line_stop = data.line_start, data.line_stop
		local pre_start_pos, pre_stop_pos, lines_before = get_lines_before(lua_code, start, size)
		local post_start_pos, post_stop_pos, lines_after = get_lines_after(lua_code, stop, size)
		local spacing = #tostring(data.line_stop + lines_after)
		local lines = {}

		do
			if lines_before >= 0 then
				local line = math.max(line_start - lines_before - 1, 1)

				for str in (lua_code:sub(pre_start_pos, pre_stop_pos)):gmatch("(.-)\n") do
					local prefix = (" "):rep(spacing - #tostring(line)) .. line .. " | "
					table.insert(lines, prefix .. str)
					line = line + 1
				end
			end

			do
				local line = line_start

				for str in (lua_code:sub(start, stop) .. "\n"):gmatch("(.-)\n") do
					local prefix = (" "):rep(spacing - #tostring(line)) .. line .. " | "

					if line == line_start then
						prefix = prefix .. lua_code:sub(table.unpack(data.sub_line_before))
					end

					local test = str

					if line == line_stop then
						str = str .. lua_code:sub(table.unpack(data.sub_line_after))
					end

					str = str .. "\n" .. (" "):rep(#prefix) .. ("^"):rep(math.max(#test, 1))
					table.insert(lines, prefix .. str)
					line = line + 1
				end
			end

			if lines_after > 0 then
				local line = line_stop + 1

				for str in (lua_code:sub(post_start_pos, post_stop_pos) .. "\n"):gmatch("(.-)\n") do
					local prefix = (" "):rep(spacing - #tostring(line)) .. line .. " | "
					table.insert(lines, prefix .. str)
					line = line + 1
				end
			end
		end

		local str = table.concat(lines, "\n")
		local path = path and
			(
				path:gsub("@", "") .. ":" .. line_start .. ":" .. data.character_start
			)
			or
			""
		local msg = path .. (msg and ": " .. msg or "")
		local post = (" "):rep(spacing - 2) .. "-> | " .. msg
		local pre = ("-"):rep(100)
		str = "\n" .. pre .. "\n" .. str .. "\n" .. pre .. "\n" .. post .. "\n"
		str = str:gsub("\t", " ")
		return str
	end
end

function helpers.GetDataFromLineCharPosition(
	tokens--[[#: {[number] = Token}]],
	code--[[#: string]],
	line--[[#: number]],
	char--[[#: number]]
)
	local sub_pos = helpers.LinePositionToSubPosition(code, line, char)

	for _, token in ipairs(tokens) do
		local found = token.stop >= sub_pos -- and token.stop <= sub_pos
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

		if found then
			return token, helpers.SubPositionToLinePosition(code, token.start, token.stop)
		end
	end
end

function helpers.JITOptimize()
	if not jit then return end

	pcall(require, "jit.opt")
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

return helpers
