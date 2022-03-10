package.loaded["nattlua.other.table_print"] = (function(...)
	local pairs = _G.pairs
	local tostring = _G.tostring
	local type = _G.type
	local debug = _G.debug
	local table = require("table")
	local tonumber = _G.tonumber
	local pcall = _G.pcall
	local assert = _G.assert
	local load = _G.load
	local setfenv = _G.setfenv
	local io = _G.io
	local luadata = {}
	local encode_table

	local function count(tbl--[[#: Table]])
		local i = 0

		for _ in pairs(tbl) do
			i = i + 1
		end

		return i
	end

	local tostringx

	do
		local pretty_prints = {}
		pretty_prints.table = function(t--[[#: Table]])
			local str = tostring(t)
			str = str .. " [" .. count(t) .. " subtables]"
			-- guessing the location of a library
			local sources = {}

			for _, v in pairs(t) do
				if type(v) == "function" then
					local info = debug.getinfo(v)

					if info then
						local src = info.source
						sources[src] = (sources[src] or 0) + 1
					end
				end
			end

			local tmp = {}

			for k, v in pairs(sources) do
				table.insert(tmp, {k = k, v = v})
			end

			table.sort(tmp, function(a, b)
				return a.v > b.v
			end)

			if #tmp > 0 and tmp[1] then
				str = str .. "[" .. tmp[1].k:gsub("!/%.%./", "") .. "]"
			end

			return str
		end
		pretty_prints["function"] = function(self--[[#: Function]])
			if debug.getprettysource then
				return (
					"function[%p][%s](%s)"
				):format(
					self,
					debug.getprettysource(self, true),
					table.concat(debug.getparams(self), ", ")
				)
			end

			return tostring(self)
		end

		function tostringx(val--[[#: any]])
			local t = type(val)
			local f = pretty_prints[t]

			if f then return f(val) end

			return tostring(val)
		end
	end

	local function getprettysource(level--[[#: number | Function]], append_line--[[#: boolean | nil]])
		local info = debug.getinfo(type(level) == "number" and (level + 1) or level)

		if info then
			if info.source == "=[C]" and type(level) == "number" then
				info = debug.getinfo(type(level) == "number" and (level + 2) or level)
			end
		end

		local pretty_source = "debug.getinfo = nil"

		if info then
			if info.source:sub(1, 1) == "@" then
				pretty_source = info.source:sub(2)

				if append_line then
					local line = info.currentline

					if line == -1 then line = info.linedefined end

					pretty_source = pretty_source .. ":" .. line
				end
			else
				pretty_source = info.source:sub(0, 25)

				if pretty_source ~= info.source then
					pretty_source = pretty_source .. "...(+" .. #info.source - #pretty_source .. " chars)"
				end

				if pretty_source == "=[C]" and jit.vmdef then
					local num = tonumber(tostring(info.func):match("#(%d+)") or "")

					if num then pretty_source = jit.vmdef.ffnames[num] end
				end
			end
		end

		return pretty_source
	end

	local function getparams(func--[[#: Function]])
		local params = {}

		for i = 1, math.huge do
			local key = debug.getlocal(func, i)

			if key then table.insert(params, key) else break end
		end

		return params
	end

	local function isarray(t--[[#: Table]])
		local i = 0

		for _ in pairs(t) do
			i = i + 1

			if t[i] == nil then return false end
		end

		return true
	end

	local env = {}
	luadata.Types = {}
	--[[#type luadata.Types = Map<|string, function=(any)>(string) | nil|>]]
	local idx = function(var--[[#: any]])
		return var.LuaDataType
	end

	function luadata.Type(var--[[#: any]])
		local t = type(var)

		if t == "table" then
			local ok, res = pcall(idx, var)

			if ok and res then return res end
		end

		return t
	end

	--[[#local type Context = {tab = number, tab_limit = number, done = Table}]]

	function luadata.ToString(var, context--[[#: nil | Context]])
		context = context or {tab = -1}
		local func = luadata.Types[luadata.Type(var)]

		if func then return func(var, context) end

		if luadata.Types.fallback then return luadata.Types.fallback(var, context) end
	end

	function luadata.FromString(str--[[#: string]])
		local func = assert(load("return " .. str), "luadata")
		setfenv(func, env)
		return func()
	end

	function luadata.Encode(tbl--[[#: Table]])
		return luadata.ToString(tbl)
	end

	function luadata.Decode(str--[[#: string]])
		local func, err = load("return {\n" .. str .. "\n}", "luadata")

		if not func then return func, err end

		setfenv(func, env)
		local ok, err = pcall(func)

		if not ok then return func, err end

		return err
	end

	function luadata.SetModifier(
		type--[[#: string]],
		callback--[[#: function=(any, Context)>(string)]],
		func--[[#: nil]],
		func_name--[[#: nil | string]]
	)
		luadata.Types[type] = callback

		if func_name then env[func_name] = func end
	end

	luadata.SetModifier("cdata", function(var--[[#: any]])
		return tostring(var)
	end)

	luadata.SetModifier("number", function(var--[[#: number]])
		return ("%s"):format(var)
	end)

	luadata.SetModifier("string", function(var--[[#: string]])
		return ("%q"):format(var)
	end)

	luadata.SetModifier("boolean", function(var--[[#: boolean]])
		return var and "true" or "false"
	end)

	luadata.SetModifier("function", function(var--[[#: Function]])
		return (
			"function(%s) --[==[ptr: %p    src: %s]==] end"
		):format(table.concat(getparams(var), ", "), var, getprettysource(var, true))
	end)

	luadata.SetModifier("fallback", function(var--[[#: any]])
		return "--[==[  " .. tostringx(var) .. "  ]==]"
	end)

	luadata.SetModifier("table", function(tbl, context)
		local str--[[#: List<|string|>]] = {}

		if context.tab_limit and context.tab >= context.tab_limit then
			return "{--[[ " .. tostringx(tbl) .. " (tab limit reached)]]}"
		end

		if context.done then
			if context.done[tbl] then
				return ("{--[=[%s already serialized]=]}"):format(tostring(tbl))
			end

			context.done[tbl] = true
		end

		context.tab = context.tab + 1

		if context.tab == 0 then str = {} else str = {"{\n"} end

		if isarray(tbl) then
			if #tbl == 0 then
				str = {"{"}
			else
				for i = 1, #tbl do
					str[#str + 1] = ("%s%s,\n"):format(("\t"):rep(context.tab), luadata.ToString(tbl[i], context))
				end
			end
		else
			for key, value in pairs(tbl) do
				value = luadata.ToString(value, context)

				if value then
					if type(key) == "string" and key:find("^[%w_]+$") and not tonumber(key) then
						str[#str + 1] = ("%s%s = %s,\n"):format(("\t"):rep(context.tab), key, value)
					else
						key = luadata.ToString(key, context)

						if key then
							str[#str + 1] = ("%s[%s] = %s,\n"):format(("\t"):rep(context.tab), key, value)
						end
					end
				end
			end
		end

		if context.tab == 0 then
			if str[1] == "{" then
				str[#str + 1] = "}" -- empty table
			else
				str[#str + 1] = "\n"
			end
		else
			if str[1] == "{" then
				str[#str + 1] = "}" -- empty table
			else
				str[#str + 1] = ("%s}"):format(("\t"):rep(context.tab - 1))
			end
		end

		context.tab = context.tab - 1
		return table.concat(str, "")
	end)

	return function(...)
		local tbl = {...}
		local max_level

		if
			type(tbl[1]) == "table" and
			type(tbl[2]) == "number" and
			type(tbl[3]) == "nil"
		then
			max_level = tbl[2]
			tbl[2] = nil
		end

		io.write(luadata.ToString(tbl, {tab = -1, tab_limit = max_level, done = {}}):sub(0, -2))
	end	
end)("./nattlua/other/table_print.lua");
package.loaded["nattlua.other.quote"] = (function(...)
	local helpers = {}

	function helpers.QuoteToken(str--[[#: string]])--[[#: string]]
		return "❲" .. str .. "❳"
	end

	function helpers.QuoteTokens(var--[[#: List<|string|>]])--[[#: string]]
		local str = ""

		for i, v in ipairs(var) do
			str = str .. helpers.QuoteToken(v)

			if i == #var - 1 then
				str = str .. " or "
			elseif i ~= #var then
				str = str .. ", "
			end
		end

		return str
	end

	return helpers	
end)("./nattlua/other/quote.lua");
package.loaded["nattlua.other.helpers"] = (function(...)
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
end)("./nattlua/other/helpers.lua");
package.loaded["nattlua.types.error_messages"] = (function(...)
	local table = require("table")
	local type = _G.type
	local ipairs = _G.ipairs
	local errors = {
		subset = function(a--[[#: any]], b--[[#: any]], reason--[[#: string | List<|string|> | nil]])--[[#: false,string | {[number] = any | string}]]
			local msg = {a, " is not a subset of ", b}

			if reason then
				table.insert(msg, " because ")

				if type(reason) == "table" then
					for i, v in ipairs(reason) do
						table.insert(msg, v)
					end
				else
					table.insert(msg, reason)
				end
			end

			return false, msg
		end,
		table_subset = function(
			a_key--[[#: any]],
			b_key--[[#: any]],
			a--[[#: any]],
			b--[[#: any]],
			reason--[[#: string | List<|string|> | nil]]
		)--[[#: false,string | {[number] = any | string}]]
			local msg = {"[", a_key, "]", a, " is not a subset of ", "[", b_key, "]", b}

			if reason then
				table.insert(msg, " because ")

				if type(reason) == "table" then
					for i, v in ipairs(reason) do
						table.insert(msg, v)
					end
				else
					table.insert(msg, reason)
				end
			end

			return false, msg
		end,
		missing = function(a--[[#: any]], b--[[#: any]], reason--[[#: string | nil]])--[[#: false,string | {[number] = any | string}]]
			local msg = {a, " has no field ", b, " because ", reason}
			return false, msg
		end,
		other = function(msg--[[#: {[number] = any | string} | string]])--[[#: false,string | {[number] = any | string}]]
			return false, msg
		end,
		type_mismatch = function(a--[[#: any]], b--[[#: any]])--[[#: false,string | {[number] = any | string}]]
			return false, {a, " is not the same type as ", b}
		end,
		value_mismatch = function(a--[[#: any]], b--[[#: any]])--[[#: false,string | {[number] = any | string}]]
			return false, {a, " is not the same value as ", b}
		end,
		operation = function(op--[[#: any]], obj--[[#: any]], subject--[[#: string]])--[[#: false,string | {[number] = any | string}]]
			return false, {"cannot ", op, " ", subject}
		end,
		numerically_indexed = function(obj--[[#: any]])--[[#: false,string | {[number] = any | string}]]
			return false, {obj, " is not numerically indexed"}
		end,
		empty = function(obj--[[#: any]])--[[#: false,string | {[number] = any | string}]]
			return false, {obj, " is empty"}
		end,
		binary = function(op--[[#: string]], l--[[#: any]], r--[[#: any]])--[[#: false,string | {[number] = any | string}]]
			return false,
			{
				l,
				" ",
				op,
				" ",
				r,
				" is not a valid binary operation",
			}
		end,
		prefix = function(op--[[#: string]], l--[[#: any]])--[[#: false,string | {[number] = any | string}]]
			return false, {op, " ", l, " is not a valid prefix operation"}
		end,
		postfix = function(op--[[#: string]], r--[[#: any]])--[[#: false,string | {[number] = any | string}]]
			return false, {op, " ", r, " is not a valid postfix operation"}
		end,
		literal = function(obj--[[#: any]], reason--[[#: string | nil]])--[[#: false,string | {[number] = any | string}]]
			local msg = {obj, " needs to be a literal"}

			if reason then
				table.insert(msg, " because ")
				table.insert(msg, reason)
			end

			return false, msg
		end,
		string_pattern = function(a--[[#: any]], b--[[#: any]])--[[#: false,string | {[number] = any | string}]]
			return false,
			{
				"cannot find ",
				a,
				" in pattern \"",
				b:GetPatternContract(),
				"\"",
			}
		end,
	}
	return errors	
end)("./nattlua/types/error_messages.lua");
package.loaded["nattlua.types.symbol"] = (function(...)
	local type = type
	local tostring = tostring
	local ipairs = ipairs
	local table = require("table")
	local setmetatable = _G.setmetatable
	local type_errors = require("nattlua.types.error_messages")
	local META = dofile("nattlua/types/base.lua")
	--[[#local type TBaseType = META.TBaseType]]
	--[[#type META.@Name = "TSymbol"]]
	--[[#type TSymbol = META.@Self]]
	META.Type = "symbol"
	META:GetSet("Data", nil--[[# as any]])

	function META.Equal(a--[[#: TSymbol]], b--[[#: TBaseType]])
		return a.Type == b.Type and a:GetData() == b:GetData()
	end

	function META:GetLuaType()
		return type(self:GetData())
	end

	function META:__tostring()
		return tostring(self:GetData())
	end

	function META:GetHash()
		return tostring(self.Data)
	end

	function META:Copy()
		local copy = self.New(self:GetData())
		copy:CopyInternalsFrom(self)
		return copy
	end

	function META:CanBeNil()
		return self:GetData() == nil
	end

	function META.IsSubsetOf(A--[[#: TSymbol]], B--[[#: TBaseType]])
		if B.Type == "tuple" then B = B:Get(1) end

		if B.Type == "any" then return true end

		if B.Type == "union" then return B:IsTargetSubsetOfChild(A) end

		if B.Type ~= "symbol" then return type_errors.type_mismatch(A, B) end

		if A:GetData() ~= B:GetData() then return type_errors.value_mismatch(A, B) end

		return true
	end

	function META:IsFalsy()
		return not self.Data
	end

	function META:IsTruthy()
		return not not self.Data
	end

	function META.New(data--[[#: any]])
		local self = setmetatable({Data = data}, META)
		self:SetLiteral(true)
		return self
	end

	local Symbol = META.New
	return {
		Symbol = Symbol,
		Nil = function()
			return Symbol(nil)
		end,
		True = function()
			return Symbol(true)
		end,
		False = function()
			return Symbol(false)
		end,
		Boolean = function()
			local Union = require("nattlua.types.union").Union
			return Union({Symbol(true), Symbol(false)})
		end,
	}	
end)("./nattlua/types/symbol.lua");
package.loaded["nattlua.types.number"] = (function(...)
	local math = math
	local assert = assert
	local error = _G.error
	local tostring = _G.tostring
	local tonumber = _G.tonumber
	local setmetatable = _G.setmetatable
	local type_errors = require("nattlua.types.error_messages")
	local bit = require("bit")
	local META = dofile("nattlua/types/base.lua")
	--[[#local type TBaseType = META.TBaseType]]
	--[[#type META.@Name = "TNumber"]]
	--[[#type TNumber = META.@Self]]
	META.Type = "number"
	META:GetSet("Data", nil--[[# as number | nil]])
	--[[#local type TUnion = {
		@Name = "TUnion",
		Type = "union",
		GetLargestNumber = function=(self)>(TNumber | nil, nil | any),
	}]]

	do -- TODO, operators is mutated below, need to use upvalue position when analyzing typed arguments
		local operators = {
			["-"] = function(l--[[#: number]])
				return -l
			end,
			["~"] = function(l--[[#: number]])
				return bit.bnot(l)
			end,
		}

		function META:PrefixOperator(op--[[#: keysof<|operators|>]])
			if self:IsLiteral() then
				local num = self.New(operators[op](self:GetData()--[[# as number]])):SetLiteral(true)
				local max = self:GetMax()

				if max then num:SetMax(max:PrefixOperator(op)) end

				return num
			end

			return self.New(nil--[[# as number]]) -- hmm
		end
	end

	function META:Widen()
		self:SetLiteral(false)
		return self
	end

	function META:GetHash()
		if self:IsLiteral() then return self.Data end

		return "__@type@__" .. self.Type
	end

	function META.Equal(a--[[#: TNumber]], b--[[#: TNumber]])
		if a.Type ~= b.Type then return false end

		if not a:IsLiteral() and not b:IsLiteral() then return true end

		if a:IsLiteral() and b:IsLiteral() then
			-- nan
			if a:GetData() ~= a:GetData() and b:GetData() ~= b:GetData() then return true end

			return a:GetData() == b:GetData()
		end

		local a_max = a.Max
		local b_max = b.Max

		if a_max then if b_max then if a_max:Equal(b_max) then return true end end end

		if a_max or b_max then return false end

		if not a:IsLiteral() and not b:IsLiteral() then return true end

		return false
	end

	function META:Copy()
		local copy = self.New(self:GetData()):SetLiteral(self:IsLiteral())
		local max = self.Max

		if max then copy.Max = max:Copy() end

		copy:CopyInternalsFrom(self)
		return copy--[[# as any]] -- TODO: figure out inheritance
	end

	function META.IsSubsetOf(A--[[#: TNumber]], B--[[#: TBaseType]])
		if B.Type == "tuple" then B = (B--[[# as any]]):Get(1) end

		if B.Type == "any" then return true end

		if B.Type == "union" then return (B--[[# as any]]):IsTargetSubsetOfChild(A) end

		if B.Type ~= "number" then return type_errors.type_mismatch(A, B) end

		if A:IsLiteral() and B:IsLiteral() then
			local a = A:GetData()--[[# as number]]
			local b = B:GetData()--[[# as number]]

			-- compare against literals
			-- nan
			if A.Type == "number" and B.Type == "number" then
				if a ~= a and b ~= b then return true end
			end

			if a == b then return true end

			local max = B:GetMaxLiteral()

			if max then if a >= b and a <= max then return true end end

			return type_errors.subset(A, B)
		elseif A:GetData() == nil and B:GetData() == nil then
			-- number contains number
			return true
		elseif A:IsLiteral() and not B:IsLiteral() then
			-- 42 subset of number?
			return true
		elseif not A:IsLiteral() and B:IsLiteral() then
			-- number subset of 42 ?
			return type_errors.subset(A, B)
		end

		-- number == number
		return true
	end

	function META:__tostring()
		local n = self:GetData()
		local s--[[#: string]]

		if n ~= n then s = "nan" end

		s = tostring(n)

		if self:GetMax() then s = s .. ".." .. tostring(self:GetMax()) end

		if self:IsLiteral() then return s end

		return "number"
	end

	META:GetSet("Max", nil--[[# as TNumber | nil]])

	function META:SetMax(val--[[#: TBaseType | TUnion]])
		local err

		if val.Type == "union" then
			val, err = (val--[[# as any]]):GetLargestNumber()

			if not val then return val, err end
		end

		if val.Type ~= "number" then
			return type_errors.other({"max must be a number, got ", val})
		end

		if val:IsLiteral() then
			self.Max = val
		else
			self:SetLiteral(false)
			self:SetData(nil)
			self.Max = nil
		end

		return self
	end

	function META:GetMaxLiteral()
		return self.Max and self.Max:GetData()
	end

	do
		local operators = {
			[">"] = function(a--[[#: number]], b--[[#: number]])
				return a > b
			end,
			["<"] = function(a--[[#: number]], b--[[#: number]])
				return a < b
			end,
			["<="] = function(a--[[#: number]], b--[[#: number]])
				return a <= b
			end,
			[">="] = function(a--[[#: number]], b--[[#: number]])
				return a >= b
			end,
		}

		local function compare(
			val--[[#: number]],
			min--[[#: number]],
			max--[[#: number]],
			operator--[[#: keysof<|operators|>]]
		)
			local func = operators[operator]

			if func(min, val) and func(max, val) then
				return true
			elseif not func(min, val) and not func(max, val) then
				return false
			end

			return nil
		end

		function META.LogicalComparison(a--[[#: TNumber]], b--[[#: TNumber]], operator--[[#: "=="]])--[[#: boolean | nil]]
			if not a:IsLiteral() or not b:IsLiteral() then return nil end

			if operator == "==" then
				local a_val = a:GetData()
				local b_val = b:GetData()

				if b_val then
					local max = a:GetMax()
					local max = max and max:GetData()

					if max and a_val then
						if b_val >= a_val and b_val <= max then return nil end

						return false
					end
				end

				if a_val then
					local max = b:GetMax()
					local max = max and max:GetData()

					if max and b_val then
						if a_val >= b_val and a_val <= max then return nil end

						return false
					end
				end

				if a_val and b_val then return a_val == b_val end

				return nil
			end

			local a_val = a:GetData()
			local b_val = b:GetData()

			if a_val and b_val then
				local a_max = a:GetMaxLiteral()
				local b_max = b:GetMaxLiteral()

				if a_max then
					if b_max then
						local res_a = compare(b_val, a_val, b_max, operator)
						local res_b = not compare(a_val, b_val, a_max, operator)

						if res_a ~= nil and res_a == res_b then return res_a end

						return nil
					end
				end

				if a_max then
					local res = compare(b_val, a_val, a_max, operator)

					if res == nil then return nil end

					return res
				end

				if operators[operator] then return operators[operator](a_val, b_val) end
			else
				return nil
			end

			if operators[operator] then return nil end

			return type_errors.binary(operator, a, b)
		end

		function META.LogicalComparison2(a--[[#: TNumber]], b--[[#: TNumber]], operator--[[#: keysof<|operators|>]])--[[#: TNumber | nil,TNumber | nil]]
			local a_min = a:GetData()
			local b_min = b:GetData()

			if not a_min then return nil end

			if not b_min then return nil end

			local a_max = a:GetMaxLiteral() or a_min
			local b_max = b:GetMaxLiteral() or b_min
			local a_min_res = nil--[[# as number]]
			local b_min_res = nil--[[# as number]]
			local a_max_res = nil--[[# as number]]
			local b_max_res = nil--[[# as number]]

			if operator == "<" then
				a_min_res = math.min(a_min, b_max)
				a_max_res = math.min(a_max, b_max - 1)
				b_min_res = math.max(a_min, b_max)
				b_max_res = math.max(a_max, b_max)
			end

			if operator == ">" then
				a_min_res = math.max(a_min, b_max + 1)
				a_max_res = math.max(a_max, b_max)
				b_min_res = math.min(a_min, b_max)
				b_max_res = math.min(a_max, b_max)
			end

			local a = META.New(a_min_res):SetLiteral(true):SetMax(META.New(a_max_res):SetLiteral(true))
			local b = META.New(b_min_res):SetLiteral(true):SetMax(META.New(b_max_res):SetLiteral(true))
			return a, b
		end
	end

	do
		local operators--[[#: {[string] = function=(number, number)>(number)}]] = {
			["+"] = function(l, r)
				return l + r
			end,
			["-"] = function(l, r)
				return l - r
			end,
			["*"] = function(l, r)
				return l * r
			end,
			["/"] = function(l, r)
				return l / r
			end,
			["/idiv/"] = function(l, r)
				return (math.modf(l / r))
			end,
			["%"] = function(l, r)
				return l % r
			end,
			["^"] = function(l, r)
				return l ^ r
			end,
			["&"] = function(l, r)
				return bit.band(l, r)
			end,
			["|"] = function(l, r)
				return bit.bor(l, r)
			end,
			["~"] = function(l, r)
				return bit.bxor(l, r)
			end,
			["<<"] = function(l, r)
				return bit.lshift(l, r)
			end,
			[">>"] = function(l, r)
				return bit.rshift(l, r)
			end,
		}

		function META.ArithmeticOperator(l--[[#: TNumber]], r--[[#: TNumber]], op--[[#: keysof<|operators|>]])--[[#: TNumber]]
			local func = operators[op]

			if l:IsLiteral() and r:IsLiteral() then
				local obj = META.New(func(l:GetData()--[[# as number]], r:GetData()--[[# as number]])):SetLiteral(true)

				if r:GetMax() then
					obj:SetMax(l.ArithmeticOperator(l:GetMax() or l, r:GetMax()--[[# as TNumber]], op))
				end

				if l:GetMax() then
					obj:SetMax(l.ArithmeticOperator(l:GetMax()--[[# as TNumber]], r:GetMax() or r, op))
				end

				return obj
			end

			return META.New()
		end
	end

	function META.New(data--[[#: number | nil]])
		return setmetatable(
			{
				Data = data--[[# as number]],
				Falsy = false,
				Truthy = true,
				Literal = false,
			},
			META
		)
	end

	return {
		Number = META.New,
		LNumber = function(num--[[#: number | nil]])
			return META.New(num):SetLiteral(true)
		end,
		LNumberFromString = function(str--[[#: string]])
			local num = tonumber(str)

			if not num then
				if str:sub(1, 2) == "0b" then
					num = tonumber(str:sub(3))
				elseif str:lower():sub(-3) == "ull" then
					num = tonumber(str:sub(1, -4))
				elseif str:lower():sub(-2) == "ll" then
					num = tonumber(str:sub(1, -3))
				end
			end

			if not num then return nil end

			return META.New(num):SetLiteral(true)
		end,
		TNumber = TNumber,
	}	
end)("./nattlua/types/number.lua");
package.loaded["nattlua.types.any"] = (function(...)
	local META = dofile("nattlua/types/base.lua")
	--[[#local type TBaseType = META.TBaseType]]
	--[[#type META.@Name = "TAny"]]
	--[[#type TAny = META.@Self]]
	META.Type = "any"

	function META:Get(key)
		return self
	end

	function META:Set(key--[[#: TBaseType]], val--[[#: TBaseType]])
		return true
	end

	function META:Copy()
		return self
	end

	function META.IsSubsetOf(A--[[#: TAny]], B--[[#: TBaseType]])
		return true
	end

	function META:__tostring()
		return "any"
	end

	function META:IsFalsy()
		return true
	end

	function META:IsTruthy()
		return true
	end

	function META:Call()
		local Tuple = require("nattlua.types.tuple").Tuple
		return Tuple({Tuple({}):AddRemainder(Tuple({META.New()}):SetRepeat(math.huge))})
	end

	function META.Equal(a--[[#: TAny]], b--[[#: TBaseType]])
		return a.Type == b.Type
	end

	return {
		Any = function()
			return META.New()
		end,
	}	
end)("./nattlua/types/any.lua");
package.loaded["nattlua.types.tuple"] = (function(...)
	local tostring = tostring
	local table = require("table")
	local math = math
	local assert = assert
	local print = print
	local debug = debug
	local error = error
	local setmetatable = _G.setmetatable
	local Union = require("nattlua.types.union").Union
	local Nil = require("nattlua.types.symbol").Nil
	local Any = require("nattlua.types.any").Any
	local type_errors = require("nattlua.types.error_messages")
	local ipairs = _G.ipairs
	local type = _G.type
	local META = dofile("nattlua/types/base.lua")
	--[[#local type TBaseType = META.TBaseType]]
	--[[#type META.@Name = "TTuple"]]
	--[[#type TTuple = META.@Self]]
	--[[#type TTuple.Remainder = nil | TTuple]]
	--[[#type TTuple.Repeat = nil | number]]
	--[[#type TTuple.suppress = nil | boolean]]
	--[[#type TTuple.Data = List<|TBaseType|>]]
	META.Type = "tuple"
	META:GetSet("Unpackable", false--[[# as boolean]])

	function META.Equal(a--[[#: TTuple]], b--[[#: TBaseType]])
		if a.Type ~= b.Type then return false end

		if a.suppress then return true end

		if #a.Data ~= #b.Data then return false end

		for i = 1, #a.Data do
			a.suppress = true
			local ok = a.Data[i]:Equal(b.Data[i])
			a.suppress = false

			if not ok then return false end
		end

		return true
	end

	function META:__tostring()
		if self.suppress then return "current_tuple" end

		self.suppress = true
		local strings = {}

		for i, v in ipairs(self:GetData()) do
			strings[i] = tostring(v)
		end

		if self.Remainder then table.insert(strings, tostring(self.Remainder)) end

		local s = "("

		if #strings == 1 then
			s = s .. strings[1] .. ","
		else
			s = s .. table.concat(strings, ", ")
		end

		s = s .. ")"

		if self.Repeat then s = s .. "*" .. tostring(self.Repeat) end

		self.suppress = false
		return s
	end

	function META:Merge(tup--[[#: TTuple]])
		if tup.Type == "union" then
			for _, obj in ipairs(tup:GetData()) do
				self:Merge(obj)
			end

			return self
		end

		local src = self:GetData()

		for i = 1, tup:GetMinimumLength() do
			local a = self:Get(i)
			local b = tup:Get(i)

			if a then src[i] = Union({a, b}) else src[i] = b:Copy() end
		end

		self.Remainder = tup.Remainder or self.Remainder
		self.Repeat = tup.Repeat or self.Repeat
		return self
	end

	function META:Copy(map--[[#: Map<|any, any|>]], ...--[[#: ...any]])
		map = map or {}
		local copy = self.New({})
		map[self] = map[self] or copy

		for i, v in ipairs(self:GetData()) do
			v = map[v] or v:Copy(map, ...)
			map[v] = map[v] or v
			copy:Set(i, v)
		end

		if self.Remainder then copy.Remainder = self.Remainder:Copy(nil, ...) end

		copy.Repeat = self.Repeat
		copy.Unpackable = self.Unpackable
		copy:CopyInternalsFrom(self)
		return copy
	end

	function META.IsSubsetOf(A--[[#: TTuple]], B--[[#: TBaseType]], max_length--[[#: nil | number]])
		if A == B then return true end

		if A.suppress then return true end

		if A.Remainder and A:Get(1).Type == "any" and #A:GetData() == 0 then
			return true
		end

		if B.Type == "union" then return B:IsTargetSubsetOfChild(A) end

		if
			A:Get(1) and
			A:Get(1).Type == "any" and
			B.Type == "tuple" and
			B:GetLength() == 0
		then
			return true
		end

		if B.Type == "any" then return true end

		if B.Type == "table" then
			if not B:IsNumericallyIndexed() then
				return type_errors.numerically_indexed(B)
			end
		end

		if B.Type ~= "tuple" then return type_errors.type_mismatch(A, B) end

		max_length = max_length or math.max(A:GetMinimumLength(), B:GetMinimumLength())

		for i = 1, max_length do
			local a, err = A:Get(i)

			if not a then return type_errors.subset(A, B, err) end

			local b, err = B:Get(i)

			if not b and a.Type == "any" then break end

			if not b then return type_errors.missing(B, i, err) end

			A.suppress = true
			local ok, reason = a:IsSubsetOf(b)
			A.suppress = false

			if not ok then return type_errors.subset(a, b, reason) end
		end

		return true
	end

	function META.IsSubsetOfTupleWithoutExpansion(A--[[#: TTuple]], B--[[#: TBaseType]])
		for i, a in ipairs(A:GetData()) do
			local b = B:GetWithoutExpansion(i)
			local ok, err = a:IsSubsetOf(b)

			if ok then return ok, err, a, b, i end
		end

		return true
	end

	function META.IsSubsetOfTuple(A--[[#: TTuple]], B--[[#: TBaseType]])
		if A:Equal(B) then return true end

		if A:GetLength() == math.huge and B:GetLength() == math.huge then
			for i = 1, math.max(A:GetMinimumLength(), B:GetMinimumLength()) do
				local a = A:Get(i)
				local b = B:Get(i)
				local ok, err = a:IsSubsetOf(b)

				if not ok then
					local ok, err = type_errors.subset(a, b, err)
					return ok, err, a, b, i
				end
			end

			return true
		end

		for i = 1, math.max(A:GetMinimumLength(), B:GetMinimumLength()) do
			local a, a_err = A:Get(i)
			local b, b_err = B:Get(i)

			if b and b.Type == "union" then b, b_err = b:GetAtIndex(i) end

			if not a then
				if b and b.Type == "any" then
					a = Any()
				else
					return a, a_err, a, b, i
				end
			end

			if not b then return b, b_err, a, b, i end

			if b.Type == "tuple" then
				b = b:Get(1)

				if not b then break end
			end

			a = a or Nil()
			b = b or Nil()
			local ok, reason = a:IsSubsetOf(b)

			if not ok then return ok, reason, a, b, i end
		end

		return true
	end

	function META:HasTuples()
		for _, v in ipairs(self.Data) do
			if v.Type == "tuple" then return true end
		end

		if self.Remainder and self.Remainder.Type == "tuple" then return true end

		return false
	end

	function META:Get(key--[[#: number | TBaseType]])
		local real_key = key

		if type(key) == "table" and key.Type == "number" and key:IsLiteral() then
			key = key:GetData()
		end

		if type(key) ~= "number" then
			print(real_key, "REAL_KEY")
			error("key must be a number, got " .. tostring(key) .. debug.traceback())
		end

		local val = self:GetData()[key]

		if not val and self.Repeat and key <= (#self:GetData() * self.Repeat) then
			return self:GetData()[((key - 1) % #self:GetData()) + 1]
		end

		if not val and self.Remainder then
			return self.Remainder:Get(key - #self:GetData())
		end

		if
			not val and
			self:GetData()[#self:GetData()] and
			(
				self:GetData()[#self:GetData()].Repeat or
				self:GetData()[#self:GetData()].Remainder
			)
		then
			return self:GetData()[#self:GetData()]:Get(key)
		end

		if not val then
			return type_errors.other({"index ", real_key, " does not exist"})
		end

		return val
	end

	function META:GetWithoutExpansion(key--[[#: string]])
		local val = self:GetData()[key]

		if not val then if self.Remainder then return self.Remainder end end

		if not val then return type_errors.other({"index ", key, " does not exist"}) end

		return val
	end

	function META:Set(i--[[#: number]], val--[[#: TBaseType]])
		if type(i) == "table" then
			i = i:GetData()
			return false, "expected number"
		end

		if val.Type == "tuple" and val:GetLength() == 1 then val = val:Get(1) end

		self.Data[i] = val

		if i > 32 then
			print(debug.traceback())
			error("tuple too long", 2)
		end

		return true
	end

	function META:IsConst()
		for _, obj in ipairs(self:GetData()) do
			if not obj:IsConst() then return false end
		end

		return true
	end

	function META:IsEmpty()
		return self:GetLength() == 0
	end

	function META:SetLength() end

	function META:IsTruthy()
		local obj = self:Get(1)

		if obj then return obj:IsTruthy() end

		return false
	end

	function META:IsFalsy()
		local obj = self:Get(1)

		if obj then return obj:IsFalsy() end

		return false
	end

	function META:GetLength()
		if self.Remainder then return #self:GetData() + self.Remainder:GetLength() end

		if self.Repeat then return #self:GetData() * self.Repeat end

		return #self:GetData()
	end

	function META:GetMinimumLength()
		if self.Repeat == math.huge or self.Repeat == 0 then return 0 end

		local len = #self:GetData()
		local found_nil = false

		for i = #self:GetData(), 1, -1 do
			local obj = self:GetData()[i]--[[# as TBaseType]]

			if
				(
					obj.Type == "union" and
					obj:CanBeNil()
				) or
				(
					obj.Type == "symbol" and
					obj:GetData() == nil
				)
			then
				found_nil = true
				len = i - 1
			elseif found_nil then
				len = i

				break
			end
		end

		return len
	end

	function META:GetSafeLength(arguments--[[#: TTuple]])
		local len = self:GetLength()

		if len == math.huge or arguments:GetLength() == math.huge then
			return math.max(self:GetMinimumLength(), arguments:GetMinimumLength())
		end

		return len
	end

	function META:AddRemainder(obj--[[#: TBaseType]])
		self.Remainder = obj
		return self
	end

	function META:SetRepeat(amt--[[#: number]])
		self.Repeat = amt
		return self
	end

	function META:Unpack(length--[[#: nil | number]])
		length = length or self:GetLength()
		length = math.min(length, self:GetLength())
		assert(length ~= math.huge, "length must be finite")
		local out = {}
		local i = 1

		for _ = 1, length do
			out[i] = self:Get(i)

			if out[i] and out[i].Type == "tuple" then
				if i == length then
					for _, v in ipairs({out[i]:Unpack(out[i]:GetMinimumLength())}) do
						out[i] = v
						i = i + 1
					end
				else
					out[i] = out[i]:Get(1)
				end
			end

			i = i + 1
		end

		return table.unpack(out)
	end

	function META:UnpackWithoutExpansion()
		local tbl = {table.unpack(self.Data)}

		if self.Remainder then table.insert(tbl, self.Remainder) end

		return table.unpack(tbl)
	end

	function META:Slice(start--[[#: number]], stop--[[#: number]])
		-- TODO: not accurate yet
		start = start or 1
		stop = stop or #self:GetData()
		local copy = self:Copy()
		local data = {}

		for i = start, stop do
			table.insert(data, self:GetData()[i])
		end

		copy:SetData(data)
		return copy
	end

	function META:GetFirstValue()
		if self.Remainder then return self.Remainder:GetFirstValue() end

		local first, err = self:Get(1)

		if not first then return first, err end

		if first.Type == "tuple" then return first:GetFirstValue() end

		return first
	end

	function META:Concat(tup--[[#: TTuple]])
		local start = self:GetLength()

		for i, v in ipairs(tup:GetData()) do
			self:Set(start + i, v)
		end

		return self
	end

	function META:SetTable(data)
		self.Data = {}

		for i, v in ipairs(data) do
			if
				i == #data and
				v.Type == "tuple" and
				not (
					v
				--[[# as TTuple]]).Remainder and
				v ~= self
			then
				self:AddRemainder(v)
			else
				table.insert(self.Data, v)
			end
		end
	end

	function META.New(data--[[#: nil | List<|TBaseType|>]])
		local self = setmetatable({Data = {}, Falsy = false, Truthy = false, Literal = false}, META)

		if data then self:SetTable(data) end

		return self
	end

	return {
		Tuple = META.New,
		VarArg = function(t)
			local self = META.New({t})
			self:SetRepeat(math.huge)
			return self
		end,
		NormalizeTuples = function(types--[[#: List<|TBaseType|>]])
			local arguments

			if #types == 1 and types[1].Type == "tuple" then
				arguments = types[1]
			else
				local temp = {}

				for i, v in ipairs(types) do
					if v.Type == "tuple" then
						if i == #types then
							table.insert(temp, v)
						else
							local obj = v:Get(1)

							if obj then table.insert(temp, obj) end
						end
					else
						table.insert(temp, v)
					end
				end

				arguments = META.New(temp)
			end

			return arguments
		end,
	}	
end)("./nattlua/types/tuple.lua");
package.loaded["nattlua.types.function"] = (function(...)
	local tostring = _G.tostring
	local ipairs = _G.ipairs
	local setmetatable = _G.setmetatable
	local table = require("table")
	local Tuple = require("nattlua.types.tuple").Tuple
	local VarArg = require("nattlua.types.tuple").VarArg
	local Any = require("nattlua.types.any").Any
	local Union = require("nattlua.types.union").Union
	local type_errors = require("nattlua.types.error_messages")
	local META = dofile("nattlua/types/base.lua")
	META.Type = "function"

	function META:__call(...)
		if self:GetData().lua_function then return self:GetData().lua_function(...) end
	end

	function META.Equal(a, b)
		return a.Type == b.Type and
			a:GetArguments():Equal(b:GetArguments()) and
			a:GetReturnTypes():Equal(b:GetReturnTypes())
	end

	function META:__tostring()
		return "function=" .. tostring(self:GetArguments()) .. ">" .. tostring(self:GetReturnTypes())
	end

	function META:GetArguments()
		return self:GetData().arg or Tuple({})
	end

	function META:GetReturnTypes()
		return self:GetData().ret or Tuple({})
	end

	function META:SetCalled(b)
		self.called = b
	end

	function META:IsCalled()
		return self.called
	end

	function META:HasExplicitArguments()
		return self.explicit_arguments
	end

	function META:HasExplicitReturnTypes()
		return self.explicit_return_set
	end

	function META:SetReturnTypes(tup)
		self:GetData().ret = tup
		self.explicit_return_set = tup
		self.called = nil
	end

	function META:SetArguments(tup)
		self:GetData().arg = tup
		self.called = nil
	end

	function META:Copy(map, ...)
		map = map or {}
		local copy = self.New({arg = Tuple({}), ret = Tuple({})})
		map[self] = map[self] or copy
		copy:GetData().ret = self:GetReturnTypes():Copy(map, ...)
		copy:GetData().arg = self:GetArguments():Copy(map, ...)
		copy:GetData().lua_function = self:GetData().lua_function
		copy:GetData().scope = self:GetData().scope
		copy:SetLiteral(self:IsLiteral())
		copy:CopyInternalsFrom(self)
		copy.function_body_node = self.function_body_node
		copy.called = self.called
		return copy
	end

	function META.IsSubsetOf(A, B)
		if B.Type == "tuple" then B = B:Get(1) end

		if B.Type == "union" then return B:IsTargetSubsetOfChild(A) end

		if B.Type == "any" then return true end

		if B.Type ~= "function" then return type_errors.type_mismatch(A, B) end

		local ok, reason = A:GetArguments():IsSubsetOf(B:GetArguments())

		if not ok then
			return type_errors.subset(A:GetArguments(), B:GetArguments(), reason)
		end

		local ok, reason = A:GetReturnTypes():IsSubsetOf(B:GetReturnTypes())

		if
			not ok and
			(
				(
					not B.called and
					not B.explicit_return
				)
				or
				(
					not A.called and
					not A.explicit_return
				)
			)
		then
			return true
		end

		if not ok then
			return type_errors.subset(A:GetReturnTypes(), B:GetReturnTypes(), reason)
		end

		return true
	end

	function META.IsCallbackSubsetOf(A, B)
		if B.Type == "tuple" then B = B:Get(1) end

		if B.Type == "union" then return B:IsTargetSubsetOfChild(A) end

		if B.Type == "any" then return true end

		if B.Type ~= "function" then return type_errors.type_mismatch(A, B) end

		local ok, reason = A:GetArguments():IsSubsetOf(B:GetArguments(), A:GetArguments():GetMinimumLength())

		if not ok then
			return type_errors.subset(A:GetArguments(), B:GetArguments(), reason)
		end

		local ok, reason = A:GetReturnTypes():IsSubsetOf(B:GetReturnTypes())

		if
			not ok and
			(
				(
					not B.called and
					not B.explicit_return
				)
				or
				(
					not A.called and
					not A.explicit_return
				)
			)
		then
			return true
		end

		if not ok then
			return type_errors.subset(A:GetReturnTypes(), B:GetReturnTypes(), reason)
		end

		return true
	end

	function META:IsFalsy()
		return false
	end

	function META:IsTruthy()
		return true
	end

	function META:AddScope(arguments, return_result, scope)
		self.scopes = self.scopes or {}
		table.insert(
			self.scopes,
			{
				arguments = arguments,
				return_result = return_result,
				scope = scope,
			}
		)
	end

	function META:GetSideEffects()
		local out = {}

		for _, call_info in ipairs(self.scopes) do
			for _, val in ipairs(call_info.scope:GetDependencies()) do
				if val.scope ~= call_info.scope then table.insert(out, val) end
			end
		end

		return out
	end

	function META:GetCallCount()
		return #self.scopes
	end

	function META:IsPure()
		return #self:GetSideEffects() == 0
	end

	function META.New(data)
		return setmetatable({Data = data or {}}, META)
	end

	return {
		Function = META.New,
		AnyFunction = function()
			return META.New({
				arg = Tuple({VarArg(Any())}),
				ret = Tuple({VarArg(Any())}),
			})
		end,
		LuaTypeFunction = function(lua_function, arg, ret)
			local self = META.New()
			self:SetData(
				{
					arg = Tuple(arg),
					ret = Tuple(ret),
					lua_function = lua_function,
				}
			)
			return self
		end,
	}	
end)("./nattlua/types/function.lua");
package.loaded["nattlua.types.union"] = (function(...)
	local tostring = tostring
	local math = math
	local setmetatable = _G.setmetatable
	local table = require("table")
	local ipairs = _G.ipairs
	local Nil = require("nattlua.types.symbol").Nil
	local type_errors = require("nattlua.types.error_messages")

	--[[#local type { TNumber } = require("nattlua.types.number")]]

	local META = dofile("nattlua/types/base.lua")
	--[[#local type TBaseType = META.TBaseType]]
	--[[#type META.@Name = "TUnion"]]
	--[[#type TUnion = META.@Self]]
	--[[#type TUnion.Data = List<|TBaseType|>]]
	--[[#type TUnion.suppress = boolean]]
	META.Type = "union"

	function META:GetHash()
		return tostring(self)
	end

	function META.Equal(a--[[#: TUnion]], b--[[#: TBaseType]])
		if a.suppress then return true end

		if b.Type ~= "union" and #a.Data == 1 then return a.Data[1]:Equal(b) end

		if a.Type ~= b.Type then return false end

		if #a.Data ~= #b.Data then return false end

		for i = 1, #a.Data do
			local ok = false
			local a = a.Data[i]

			for i = 1, #b.Data do
				local b = b.Data[i]
				a.suppress = true
				ok = a:Equal(b)
				a.suppress = false

				if ok then break end
			end

			if not ok then
				a.suppress = false
				return false
			end
		end

		return true
	end

	function META:ShrinkToFunctionSignature()
		local Tuple = require("nattlua.types.tuple").Tuple
		local arg = Tuple({})
		local ret = Tuple({})

		for _, func in ipairs(self.Data) do
			if func.Type ~= "function" then return false end

			arg:Merge(func:GetArguments())
			ret:Merge(func:GetReturnTypes())
		end

		local Function = require("nattlua.types.function").Function
		return Function({
			arg = arg,
			ret = ret,
		})
	end

	local sort = function(a, b)
		return a < b
	end

	function META:__tostring()
		if self.suppress then return "current_union" end

		local s = {}
		self.suppress = true

		for _, v in ipairs(self.Data) do
			table.insert(s, tostring(v))
		end

		if not s[1] then
			self.suppress = false
			return "|"
		end

		self.suppress = false
		table.sort(s, sort)
		return table.concat(s, " | ")
	end

	function META:AddType(e--[[#: TBaseType]])
		if e.Type == "union" then
			for _, v in ipairs(e.Data) do
				self:AddType(v)
			end

			return self
		end

		for _, v in ipairs(self.Data) do
			if v:Equal(e) then
				if
					e.Type ~= "function" or
					e:GetContract() or
					(
						e:GetNode() and
						(
							e:GetNode() == v:GetNode()
						)
					)
				then
					return self
				end
			end
		end

		if e.Type == "string" or e.Type == "number" then
			local sup = e

			for i = #self.Data, 1, -1 do
				local sub = self.Data[i]--[[# as TBaseType]] -- TODO, prove that the for loop will always yield TBaseType?
				if sub.Type == sup.Type then
					if sub:IsSubsetOf(sup) then table.remove(self.Data, i) end
				end
			end
		end

		table.insert(self.Data, e)
		return self
	end

	function META:RemoveDuplicates()
		local indices = {}

		for _, a in ipairs(self.Data) do
			for i, b in ipairs(self.Data) do
				if a ~= b and a:Equal(b) then table.insert(indices, i) end
			end
		end

		if indices[1] then
			local off = 0
			local idx = 1

			for i = 1, #self.Data do
				while i + off == indices[idx] do
					off = off + 1
					idx = idx + 1
				end

				self.Data[i] = self.Data[i + off]
			end
		end
	end

	function META:GetData()
		return self.Data
	end

	function META:GetLength()
		return #self.Data
	end

	function META:RemoveType(e--[[#: TBaseType]])
		if e.Type == "union" then
			for i, v in ipairs(e.Data) do
				self:RemoveType(v)
			end

			return self
		end

		for i, v in ipairs(self.Data) do
			if v:Equal(e) then
				table.remove(self.Data, i)

				break
			end
		end

		return self
	end

	function META:Clear()
		self.Data = {}
	end

	function META:GetMinimumLength()
		local min = 1000

		for _, obj in ipairs(self.Data) do
			if obj.Type == "tuple" then
				min = math.min(min, obj:GetMinimumLength())
			else
				min = math.min(min, 1)
			end
		end

		return min
	end

	function META:HasTuples()
		for _, obj in ipairs(self.Data) do
			if obj.Type == "tuple" then return true end
		end

		return false
	end

	function META:GetAtIndex(i--[[#: number]])
		if not self:HasTuples() then return self end

		local val
		local errors = {}

		for _, obj in ipairs(self.Data) do
			if obj.Type == "tuple" then
				local found, err = obj:Get(i)

				if found then
					if val then
						val = self.New({val, found})
						val:SetNode(found:GetNode())
					else
						val = found
					end
				else
					if val then val = self.New({val, Nil()}) else val = Nil() end

					table.insert(errors, err)
				end
			else
				if val then
					-- a non tuple in the union would be treated as a tuple with the value repeated
					val = self.New({val, obj})
					val:SetNode(self:GetNode())
				elseif i == 1 then
					val = obj
				else
					val = Nil()
				end
			end
		end

		if not val then return false, errors end

		return val
	end

	function META:Get(key--[[#: TBaseType]], from_table--[[#: nil | boolean]])
		if from_table then
			for _, obj in ipairs(self.Data) do
				if obj.Get then
					local val = obj:Get(key)

					if val then return val end
				end
			end
		end

		local errors = {}

		for _, obj in ipairs(self.Data) do
			local ok, reason = key:IsSubsetOf(obj)

			if ok then return obj end

			table.insert(errors, reason)
		end

		return type_errors.other(errors)
	end

	function META:Contains(key--[[#: TBaseType]])
		for _, obj in ipairs(self.Data) do
			local ok, reason = key:IsSubsetOf(obj)

			if ok then return true end
		end

		return false
	end

	function META:ContainsOtherThan(key--[[#: TBaseType]])
		local found = false

		for _, obj in ipairs(self.Data) do
			if key:IsSubsetOf(obj) then
				found = true
			elseif found then
				return true
			end
		end

		return false
	end

	function META:IsEmpty()
		return self.Data[1] == nil
	end

	function META:GetTruthy()
		local copy = self:Copy()

		for _, obj in ipairs(self.Data) do
			if not obj:IsTruthy() then copy:RemoveType(obj) end
		end

		return copy
	end

	function META:GetFalsy()
		local copy = self:Copy()

		for _, obj in ipairs(self.Data) do
			if not obj:IsFalsy() then copy:RemoveType(obj) end
		end

		return copy
	end

	function META:IsType(typ--[[#: string]])
		if self:IsEmpty() then return false end

		for _, obj in ipairs(self.Data) do
			if obj.Type ~= typ then return false end
		end

		return true
	end

	function META:HasType(typ--[[#: string]])
		return self:GetType(typ) ~= false
	end

	function META:CanBeNil()
		for _, obj in ipairs(self.Data) do
			if obj.Type == "symbol" and obj:GetData() == nil then return true end
		end

		return false
	end

	function META:GetType(typ--[[#: string]])
		for _, obj in ipairs(self.Data) do
			if obj.Type == typ then return obj end
		end

		return false
	end

	function META:IsTargetSubsetOfChild(target--[[#: TBaseType]])
		local errors = {}

		for _, obj in ipairs(self:GetData()) do
			local ok, reason = target:IsSubsetOf(obj)

			if ok then return true end

			table.insert(errors, reason)
		end

		return type_errors.subset(target, self, errors)
	end

	function META.IsSubsetOf(A--[[#: TUnion]], B--[[#: TBaseType]])
		if B.Type ~= "union" then return A:IsSubsetOf(META.New({B})) end

		if B.Type == "tuple" then B = B:Get(1) end

		for _, a in ipairs(A.Data) do
			if a.Type == "any" then return true end
		end

		for _, a in ipairs(A.Data) do
			local b, reason = B:Get(a)

			if not b then return type_errors.missing(B, a, reason) end

			local ok, reason = a:IsSubsetOf(b)

			if not ok then return type_errors.subset(a, b, reason) end
		end

		return true
	end

	function META:Union(union--[[#: TUnion]])
		local copy = self:Copy()

		for _, e in ipairs(union.Data) do
			copy:AddType(e)
		end

		return copy
	end

	function META:Intersect(union--[[#: TUnion]])
		local copy = META.New()

		for _, e in ipairs(self.Data) do
			if union:Get(e) then copy:AddType(e) end
		end

		return copy
	end

	function META:Subtract(union--[[#: TUnion]])
		local copy = self:Copy()

		for _, e in ipairs(self.Data) do
			copy:RemoveType(e)
		end

		return copy
	end

	function META:Copy(map--[[#: Map<|any, any|>]], copy_tables--[[#: nil | boolean]])
		map = map or {}
		local copy = META.New()
		map[self] = map[self] or copy

		for _, e in ipairs(self.Data) do
			if e.Type == "table" and not copy_tables then
				copy:AddType(e)
			else
				copy:AddType(e:Copy(map, copy_tables))
			end
		end

		copy:CopyInternalsFrom(self)
		return copy
	end

	function META:IsTruthy()
		for _, v in ipairs(self.Data) do
			if v:IsTruthy() then return true end
		end

		return false
	end

	function META:IsFalsy()
		for _, v in ipairs(self.Data) do
			if v:IsFalsy() then return true end
		end

		return false
	end

	function META:DisableTruthy()
		local found = {}

		for _, v in ipairs(self.Data) do
			if v:IsTruthy() then table.insert(found, v) end
		end

		for _, v in ipairs(found) do
			self:RemoveType(v)
		end

		self.truthy_disabled = found
	end

	function META:EnableTruthy()
		if not self.truthy_disabled then return self end

		for _, v in ipairs(self.truthy_disabled) do
			self:AddType(v)
		end

		return self
	end

	function META:DisableFalsy()
		local found = {}

		for _, v in ipairs(self.Data) do
			if v:IsFalsy() then table.insert(found, v) end
		end

		for _, v in ipairs(found) do
			self:RemoveType(v)
		end

		self.falsy_disabled = found
		return self
	end

	function META:EnableFalsy()
		if not self.falsy_disabled then return end

		for _, v in ipairs(self.falsy_disabled) do
			self:AddType(v)
		end
	end

	function META:SetMax(val--[[#: TNumber]])
		local copy = self:Copy()

		for _, e in ipairs(copy.Data) do
			e:SetMax(val)
		end

		return copy
	end

	function META:Call(analyzer--[[#: any]], arguments--[[#: TBaseType]], call_node--[[#: any]])
		if self:IsEmpty() then return type_errors.operation("call", nil) end

		local is_overload = true

		for _, obj in ipairs(self.Data) do
			if obj.Type ~= "function" or obj.function_body_node then
				is_overload = false

				break
			end
		end

		if is_overload then
			local errors = {}

			for _, obj in ipairs(self.Data) do
				if
					obj.Type == "function" and
					arguments:GetLength() < obj:GetArguments():GetMinimumLength()
				then
					table.insert(
						errors,
						{
							"invalid amount of arguments: ",
							arguments,
							" ~= ",
							obj:GetArguments(),
						}
					)
				else
					local res, reason = analyzer:Call(obj, arguments, call_node)

					if res then return res end

					table.insert(errors, reason)
				end
			end

			return type_errors.other(errors)
		end

		local new = META.New({})

		for _, obj in ipairs(self.Data) do
			local val = analyzer:Assert(call_node, analyzer:Call(obj, arguments, call_node))

			-- TODO
			if val.Type == "tuple" and val:GetLength() == 1 then
				val = val:Unpack(1)
			elseif val.Type == "union" and val:GetMinimumLength() == 1 then
				val = val:GetAtIndex(1)
			end

			new:AddType(val)
		end

		local Tuple = require("nattlua.types.tuple").Tuple
		return Tuple({new})
	end

	function META:IsLiteral()
		for _, obj in ipairs(self:GetData()) do
			if not obj:IsLiteral() then return false end
		end

		return true
	end

	function META:GetLargestNumber()
		if #self:GetData() == 0 then return type_errors.other({"union is empty"}) end

		local max = {}

		for _, obj in ipairs(self:GetData()) do
			if obj.Type ~= "number" then
				return type_errors.other({"union must contain numbers only", self})
			end

			if obj:IsLiteral() then table.insert(max, obj) else return obj end
		end

		table.sort(max, function(a, b)
			return a:GetData() > b:GetData()
		end)

		return max[1]
	end

	function META.New(data--[[#: nil | List<|TBaseType|>]])
		local self = setmetatable({
			Data = {},
			Falsy = false,
			Truthy = false,
			Literal = false,
		}, META)

		if data then for _, v in ipairs(data) do
			self:AddType(v)
		end end

		return self
	end

	return {
		Union = META.New,
		Nilable = function(typ)
			return META.New({typ, Nil()})
		end,
	}	
end)("./nattlua/types/union.lua");
package.loaded["nattlua.analyzer.context"] = (function(...)
	local current_analyzer = {}
	local CONTEXT = {}

	function CONTEXT:GetCurrentAnalyzer()
		return current_analyzer[1]
	end

	function CONTEXT:PushCurrentAnalyzer(b)
		table.insert(current_analyzer, 1, b)
	end

	function CONTEXT:PopCurrentAnalyzer()
		table.remove(current_analyzer, 1)
	end

	return CONTEXT	
end)("./nattlua/analyzer/context.lua");
package.loaded["nattlua.types.string"] = (function(...)
	local tostring = tostring
	local setmetatable = _G.setmetatable
	local type_errors = require("nattlua.types.error_messages")
	local Number = require("nattlua.types.number").Number
	local context = require("nattlua.analyzer.context")
	local META = dofile("nattlua/types/base.lua")

	--[[#local type { Token, TokenType } = import("~/nattlua/lexer/token.nlua")]]

	--[[#local type TBaseType = META.TBaseType]]
	META.Type = "string"
	--[[#type META.@Name = "TString"]]
	--[[#type TString = META.@Self]]
	META:GetSet("Data", nil--[[# as string | nil]])
	META:GetSet("PatternContract", nil--[[# as nil | string]])

	function META.Equal(a--[[#: TString]], b--[[#: BaseType]])
		if a.Type ~= b.Type then return false end

		if a:IsLiteral() and b:IsLiteral() then return a:GetData() == b:GetData() end

		if not a:IsLiteral() and not b:IsLiteral() then return true end

		return false
	end

	function META:GetHash()
		if self:IsLiteral() then return self.Data end

		return "__@type@__" .. self.Type
	end

	function META:Copy()
		local copy = self.New(self:GetData()):SetLiteral(self:IsLiteral())
		copy:SetPatternContract(self:GetPatternContract())
		copy:CopyInternalsFrom(self)
		return copy
	end

	function META.IsSubsetOf(A--[[#: TString]], B--[[#: BaseType]])
		if B.Type == "tuple" then B = B:Get(1) end

		if B.Type == "any" then return true end

		if B.Type == "union" then return B:IsTargetSubsetOfChild(A) end

		if B.Type ~= "string" then return type_errors.type_mismatch(A, B) end

		if A:IsLiteral() and B:IsLiteral() and A:GetData() == B:GetData() then -- "A" subsetof "B"
			return true
		end

		if A:IsLiteral() and not B:IsLiteral() then -- "A" subsetof string
			return true
		end

		if not A:IsLiteral() and not B:IsLiteral() then -- string subsetof string
			return true
		end

		if B.PatternContract then
			if not A:GetData() then -- TODO: this is not correct, it should be :IsLiteral() but I have not yet decided this behavior yet
				return type_errors.literal(A)
			end

			if not A:GetData():find(B.PatternContract) then
				return type_errors.string_pattern(A, B)
			end

			return true
		end

		if A:IsLiteral() and B:IsLiteral() then
			return type_errors.value_mismatch(A, B)
		end

		return type_errors.subset(A, B)
	end

	function META:__tostring()
		if self.PatternContract then return "$\"" .. self.PatternContract .. "\"" end

		if self:IsLiteral() then
			if self:GetData() then return "\"" .. self:GetData() .. "\"" end

			if self:GetData() == nil then return "string" end

			return tostring(self:GetData())
		end

		return "string"
	end

	function META.LogicalComparison(a--[[#: TString]], b--[[#: TString]], op)
		if op == ">" then
			if a:IsLiteral() and b:IsLiteral() then return a:GetData() > b:GetData() end

			return nil
		elseif op == "<" then
			if a:IsLiteral() and b:IsLiteral() then return a:GetData() < b:GetData() end

			return nil
		elseif op == "<=" then
			if a:IsLiteral() and b:IsLiteral() then return a:GetData() <= b:GetData() end

			return nil
		elseif op == ">=" then
			if a:IsLiteral() and b:IsLiteral() then return a:GetData() >= b:GetData() end

			return nil
		elseif op == "==" then
			if a:IsLiteral() and b:IsLiteral() then return a:GetData() == b:GetData() end

			return nil
		end

		return type_errors.binary(op, a, b)
	end

	function META:IsFalsy()
		return false
	end

	function META:IsTruthy()
		return true
	end

	function META:PrefixOperator(op--[[#: string]])
		if op == "#" then
			return Number(self:GetData() and #self:GetData() or nil):SetLiteral(self:IsLiteral())
		end
	end

	function META.New(data--[[#: string | nil]])
		local self = setmetatable({Data = data}, META)
		-- analyzer might be nil when strings are made outside of the analyzer, like during tests
		local analyzer = context:GetCurrentAnalyzer()

		if analyzer then
			self:SetMetaTable(analyzer:GetDefaultEnvironment("typesystem").string_metatable)
		end

		return self
	end

	return {
		String = META.New,
		LString = function(num--[[#: string]])
			return META.New(num):SetLiteral(true)
		end,
		LStringNoMeta = function(str)
			return setmetatable({Data = str}, META):SetLiteral(true)
		end,
		NodeToString = function(node--[[#: Token]])
			return META.New(node.value.value):SetLiteral(true):SetNode(node)
		end,
	}	
end)("./nattlua/types/string.lua");
package.loaded["nattlua.types.table"] = (function(...)
	local setmetatable = _G.setmetatable
	local table = require("table")
	local ipairs = _G.ipairs
	local tostring = _G.tostring
	local Union = require("nattlua.types.union").Union
	local Nil = require("nattlua.types.symbol").Nil
	local Number = require("nattlua.types.number").Number
	local LNumber = require("nattlua.types.number").LNumber
	local Tuple = require("nattlua.types.tuple").Tuple
	local type_errors = require("nattlua.types.error_messages")
	local META = dofile("nattlua/types/base.lua")
	--[[#local type BaseType = import("~/nattlua/types/base.lua")]]
	META.Type = "table"
	--[[#type META.@Name = "TTable"]]
	--[[#type TTable = META.@Self]]
	META:GetSet("Data", nil--[[# as {[any] = any} | {}]])
	META:GetSet("BaseTable", nil--[[# as TTable | nil]])
	META:GetSet("ReferenceId", nil--[[# as string | nil]])
	META:GetSet("Self", nil--[[# as TTable]])

	function META:GetName()
		if not self.Name then
			local meta = self:GetMetaTable()

			if meta and meta ~= self then return meta:GetName() end
		end

		return self.Name
	end

	function META:SetSelf(tbl)
		tbl:SetMetaTable(self)
		tbl.mutable = true
		tbl:SetContract(tbl)
		self.Self = tbl
	end

	function META.Equal(a--[[#: BaseType]], b--[[#: BaseType]])
		if a.Type ~= b.Type then return false end

		if a:IsUnique() then return a:GetUniqueID() == b:GetUniqueID() end

		if a:GetContract() and a:GetContract().Name then
			if not b:GetContract() or not b:GetContract().Name then
				a.suppress = false
				return false
			end

			-- never called
			a.suppress = false
			return a:GetContract().Name:GetData() == b:GetContract().Name:GetData()
		end

		if a.Name then
			a.suppress = false

			if not b.Name then return false end

			return a.Name:GetData() == b.Name:GetData()
		end

		if a.suppress then return true end

		local adata = a:GetData()
		local bdata = b:GetData()

		if #adata ~= #bdata then return false end

		for i = 1, #adata do
			local akv = adata[i]
			local ok = false

			for i = 1, #bdata do
				local bkv = bdata[i]
				a.suppress = true
				ok = akv.key:Equal(bkv.key) and akv.val:Equal(bkv.val)
				a.suppress = false

				if ok then break end
			end

			if not ok then
				a.suppress = false
				return false
			end
		end

		return true
	end

	local level = 0

	function META:__tostring()
		if self.suppress then return "current_table" end

		self.suppress = true

		if self:GetContract() and self:GetContract().Name then -- never called
			self.suppress = nil
			return self:GetContract().Name:GetData()
		end

		if self.Name then
			self.suppress = nil
			return self.Name:GetData()
		end

		local s = {}
		level = level + 1
		local indent = ("\t"):rep(level)

		if #self:GetData() <= 1 then indent = " " end

		local contract = self:GetContract()

		if contract and contract.Type == "table" and contract ~= self then
			for i, keyval in ipairs(contract:GetData()) do
				local key, val = tostring(self:GetData()[i] and self:GetData()[i].key or "nil"),
				tostring(self:GetData()[i] and self:GetData()[i].val or "nil")
				local tkey, tval = tostring(keyval.key), tostring(keyval.val)

				if key == tkey then
					s[i] = indent .. "[" .. key .. "]"
				else
					s[i] = indent .. "[" .. key .. " as " .. tkey .. "]"
				end

				if val == tval then
					s[i] = s[i] .. " = " .. val
				else
					s[i] = s[i] .. " = " .. val .. " as " .. tval
				end
			end
		else
			for i, keyval in ipairs(self:GetData()) do
				local key, val = tostring(keyval.key), tostring(keyval.val)
				s[i] = indent .. "[" .. key .. "]" .. " = " .. val
			end
		end

		level = level - 1
		self.suppress = false

		if #self:GetData() <= 1 then return "{" .. table.concat(s, ",") .. " }" end

		return "{\n" .. table.concat(s, ",\n") .. "\n" .. ("\t"):rep(level) .. "}"
	end

	function META:GetLength(analyzer)
		local contract = self:GetContract()

		if contract and contract ~= self then return contract:GetLength(analyzer) end

		local len = 0

		for _, kv in ipairs(self:GetData()) do
			if analyzer and self.mutations then
				local val = analyzer:GetMutatedTableValue(self, kv.key)

				if val.Type == "union" and val:CanBeNil() then
					return Number(len):SetLiteral(true):SetMax(Number(len + 1):SetLiteral(true))
				end

				if val.Type == "symbol" and val:GetData() == nil then
					return Number(len):SetLiteral(true)
				end
			end

			if kv.key.Type == "number" then
				if kv.key:IsLiteral() then
					-- TODO: not very accurate
					if kv.key:GetMax() then return kv.key end

					if len + 1 == kv.key:GetData() then
						len = kv.key:GetData()
					else
						break
					end
				else
					return kv.key
				end
			end
		end

		return Number(len):SetLiteral(true)
	end

	function META:FollowsContract(contract--[[#: TTable]])
		if self:GetContract() == contract then return true end

		do -- todo
			-- i don't think this belongs here
			if not self:GetData()[1] then
				local can_be_empty = true
				contract.suppress = true

				for _, keyval in ipairs(contract:GetData()) do
					if not keyval.val:CanBeNil() then
						can_be_empty = false

						break
					end
				end

				contract.suppress = false

				if can_be_empty then return true end
			end
		end

		for _, keyval in ipairs(contract:GetData()) do
			local res, err = self:FindKeyVal(keyval.key)

			if not res and self:GetMetaTable() then
				res, err = self:GetMetaTable():FindKeyVal(keyval.key)
			end

			if not keyval.val:CanBeNil() then
				if not res then return res, err end

				local ok, err = res.val:IsSubsetOf(keyval.val)

				if not ok then
					return type_errors.other(
						{
							"the key ",
							res.key,
							" is not a subset of ",
							keyval.key,
							" because ",
							err,
						}
					)
				end
			end
		end

		for _, keyval in ipairs(self:GetData()) do
			local res, err = contract:FindKeyValReverse(keyval.key)

			if not keyval.val:CanBeNil() then
				if not res then return res, err end

				local ok, err = keyval.val:IsSubsetOf(res.val)

				if not ok then
					return type_errors.other(
						{
							"the key ",
							keyval.key,
							" is not a subset of ",
							res.val,
							" because ",
							err,
						}
					)
				end
			end
		end

		return true
	end

	function META.IsSubsetOf(A--[[#: BaseType]], B--[[#: BaseType]])
		if A.suppress then return true, "suppressed" end

		if B.Type == "tuple" then B = B:Get(1) end

		if B.Type == "any" then return true, "b is any " end

		local ok, err = A:IsSameUniqueType(B)

		if not ok then return ok, err end

		if A == B then return true, "same type" end

		if B.Type == "table" then
			if B:GetMetaTable() and B:GetMetaTable() == A then
				return true, "same metatable"
			end

			--if B:GetSelf() and B:GetSelf():Equal(A) then return true end
			local can_be_empty = true
			A.suppress = true

			for _, keyval in ipairs(B:GetData()) do
				if not keyval.val:CanBeNil() then
					can_be_empty = false

					break
				end
			end

			A.suppress = false

			if
				not A:GetData()[1] and
				(
					not A:GetContract() or
					not A:GetContract():GetData()[1]
				)
			then
				if can_be_empty then
					return true, "can be empty"
				else
					return type_errors.subset(A, B)
				end
			end

			for _, akeyval in ipairs(A:GetData()) do
				local bkeyval, reason = B:FindKeyValReverse(akeyval.key)

				if not akeyval.val:CanBeNil() then
					if not bkeyval then
						if A.BaseTable and A.BaseTable == B then
							bkeyval = akeyval
						else
							return bkeyval, reason
						end
					end

					A.suppress = true
					local ok, err = akeyval.val:IsSubsetOf(bkeyval.val)
					A.suppress = false

					if not ok then
						return type_errors.table_subset(akeyval.key, bkeyval.key, akeyval.val, bkeyval.val, err)
					end
				end
			end

			return true, "all is equal"
		elseif B.Type == "union" then
			local u = Union({A})
			local ok, err = u:IsSubsetOf(B)
			return ok, err or "is subset of b"
		end

		return type_errors.subset(A, B)
	end

	function META:ContainsAllKeysIn(contract--[[#: TTable]])
		for _, keyval in ipairs(contract:GetData()) do
			if keyval.key:IsLiteral() then
				local ok, err = self:FindKeyVal(keyval.key)

				if not ok then
					if
						(
							keyval.val.Type == "symbol" and
							keyval.val:GetData() == nil
						)
						or
						(
							keyval.val.Type == "union" and
							keyval.val:CanBeNil()
						)
					then
						return true
					end

					return type_errors.other({keyval.key, " is missing from ", contract})
				end
			end
		end

		return true
	end

	function META:IsDynamic()
		return true
	end

	function META:Delete(key--[[#: BaseType]])
		local data = self:GetData()

		for i = #data, 1, -1 do
			local keyval = data[i]

			if key:Equal(keyval.key) then
				keyval.val:SetParent()
				keyval.key:SetParent()
				table.remove(self:GetData(), i)
			end
		end

		return true
	end

	function META:GetKeyUnion()
		-- never called
		local union = Union()

		for _, keyval in ipairs(self:GetData()) do
			union:AddType(keyval.key:Copy())
		end

		return union
	end

	function META:Contains(key--[[#: BaseType]])
		return self:FindKeyValReverse(key)
	end

	function META:IsEmpty()
		if self:GetContract() then return false end

		return self:GetData()[1] == nil
	end

	function META:FindKeyVal(key--[[#: BaseType]])
		local reasons = {}

		for _, keyval in ipairs(self:GetData()) do
			local ok, reason = keyval.key:IsSubsetOf(key)

			if ok then return keyval end

			table.insert(reasons, reason)
		end

		if not reasons[1] then
			local ok, reason = type_errors.missing(self, key, "table is empty")
			reasons[1] = reason
		end

		return type_errors.missing(self, key, reasons)
	end

	function META:FindKeyValReverse(key--[[#: BaseType]])
		local reasons = {}

		for _, keyval in ipairs(self:GetData()) do
			local ok, reason = key:Equal(keyval.key)

			if ok then return keyval end
		end

		for _, keyval in ipairs(self:GetData()) do
			local ok, reason = key:IsSubsetOf(keyval.key)

			if ok then return keyval end

			table.insert(reasons, reason)
		end

		if self.BaseTable then
			local ok, reason = self.BaseTable:FindKeyValReverse(key)

			if ok then return ok end

			table.insert(reasons, reason)
		end

		if not reasons[1] then
			local ok, reason = type_errors.missing(self, key, "table is empty")
			reasons[1] = reason
		end

		return type_errors.missing(self, key, reasons)
	end

	function META:FindKeyValReverseEqual(key--[[#: BaseType]])
		local reasons = {}

		for _, keyval in ipairs(self:GetData()) do
			local ok, reason = key:Equal(keyval.key)

			if ok then return keyval end

			table.insert(reasons, reason)
		end

		if not reasons[1] then
			local ok, reason = type_errors.missing(self, key, "table is empty")
			reasons[1] = reason
		end

		return type_errors.missing(self, key, reasons)
	end

	function META:Insert(val)
		self.size = self.size or LNumber(1)
		self:Set(self.size:Copy(), val)
		self.size:SetData(self.size:GetData() + 1)
	end

	function META:GetGlobalEnvironmentValues()
		local values = {}

		for i, keyval in ipairs(self:GetData()) do
			values[i] = keyval.val
		end

		return values
	end

	function META:Set(key--[[#: BaseType]], val--[[#: BaseType | nil]], no_delete--[[#: boolean | nil]])
		if key.Type == "string" and key:IsLiteral() and key:GetData():sub(1, 1) == "@" then
			self["Set" .. key:GetData():sub(2)](self, val)
			return true
		end

		if key.Type == "symbol" and key:GetData() == nil then
			return type_errors.other("key is nil")
		end

		-- delete entry
		if not no_delete and not self:GetContract() then
			if (not val or (val.Type == "symbol" and val:GetData() == nil)) then
				return self:Delete(key)
			end
		end

		if self:GetContract() and self:GetContract().Type == "table" then -- TODO
			local keyval, reason = self:GetContract():FindKeyValReverse(key)

			if not keyval then return keyval, reason end

			local keyval, reason = val:IsSubsetOf(keyval.val)

			if not keyval then return keyval, reason end
		end

		-- if the key exists, check if we can replace it and maybe the value
		local keyval, reason = self:FindKeyValReverse(key)

		if not keyval then
			val:SetParent(self)
			key:SetParent(self)
			table.insert(self.Data, {key = key, val = val})
		else
			if keyval.key:IsLiteral() and keyval.key:Equal(key) then
				keyval.val = val
			else
				keyval.val = Union({keyval.val, val})
			end
		end

		return true
	end

	function META:SetExplicit(key--[[#: BaseType]], val--[[#: BaseType]])
		if key.Type == "string" and key:IsLiteral() and key:GetData():sub(1, 1) == "@" then
			local key = "Set" .. key:GetData():sub(2)

			if not self[key] then
				return type_errors.other("no such function on table: " .. key)
			end

			self[key](self, val)
			return true
		end

		if key.Type == "symbol" and key:GetData() == nil then
			return type_errors.other("key is nil")
		end

		-- if the key exists, check if we can replace it and maybe the value
		local keyval, reason = self:FindKeyValReverseEqual(key)

		if not keyval then
			val:SetParent(self)
			key:SetParent(self)
			table.insert(self.Data, {key = key, val = val})
		else
			if keyval.key:IsLiteral() and keyval.key:Equal(key) then
				keyval.val = val
			else
				keyval.val = Union({keyval.val, val})
			end
		end

		return true
	end

	function META:Get(key--[[#: BaseType]], from_contract)
		if key.Type == "string" and key:IsLiteral() and key:GetData():sub(1, 1) == "@" then
			return self["Get" .. key:GetData():sub(2)](self)
		end

		if key.Type == "union" then
			local union = Union({})
			local errors = {}

			for _, k in ipairs(key:GetData()) do
				local obj, reason = self:Get(k)

				if obj then
					union:AddType(obj)
				else
					table.insert(errors, reason)
				end
			end

			if union:GetLength() == 0 then return type_errors.other(errors) end

			return union
		end

		if (key.Type == "string" or key.Type == "number") and not key:IsLiteral() then
			local union = Union({Nil()})
			local found_non_literal = false

			for _, keyval in ipairs(self:GetData()) do
				if keyval.key.Type == "union" then
					for _, ukey in ipairs(keyval.key:GetData()) do
						if ukey:IsSubsetOf(key) then union:AddType(keyval.val) end
					end
				elseif keyval.key.Type == key.Type or keyval.key.Type == "any" then
					if keyval.key:IsLiteral() then
						union:AddType(keyval.val)
					else
						found_non_literal = true

						break
					end
				end
			end

			if not found_non_literal then return union end
		end

		local keyval, reason = self:FindKeyValReverse(key)

		if keyval then return keyval.val end

		if not keyval and self:GetContract() then
			local keyval, reason = self:GetContract():FindKeyValReverse(key)

			if keyval then return keyval.val end

			return type_errors.other(reason)
		end

		return type_errors.other(reason)
	end

	function META:IsNumericallyIndexed()
		for _, keyval in ipairs(self:GetData()) do
			if keyval.key.Type ~= "number" then return false end
		end

		return true
	end

	function META:CopyLiteralness(from--[[#: TTable]])
		if not from:GetData() then return false end

		if self:Equal(from) then return true end

		for _, keyval_from in ipairs(from:GetData()) do
			local keyval, reason = self:FindKeyVal(keyval_from.key)

			if not keyval then return type_errors.other(reason) end

			if keyval_from.key.Type == "table" then
				keyval.key:CopyLiteralness(keyval_from.key) -- TODO: never called
			else
				keyval.key:SetLiteral(keyval_from.key:IsLiteral())
			end

			if keyval_from.val.Type == "table" then
				keyval.val:CopyLiteralness(keyval_from.val)
			else
				keyval.val:SetLiteral(keyval_from.val:IsLiteral())
			end
		end

		return true
	end

	function META:CoerceUntypedFunctions(from--[[#: TTable]])
		for _, kv in ipairs(self:GetData()) do
			local kv_from, reason = from:FindKeyValReverse(kv.key)

			if kv.val.Type == "function" and kv_from.val.Type == "function" then
				kv.val:SetArguments(kv_from.val:GetArguments())
				kv.val:SetReturnTypes(kv_from.val:GetReturnTypes())
				kv.val.explicit_arguments = true
			end
		end
	end

	function META:Copy(map--[[#: any]], ...)
		map = map or {}
		local copy = META.New()
		map[self] = map[self] or copy

		for i, keyval in ipairs(self:GetData()) do
			local k, v = keyval.key, keyval.val
			k = map[keyval.key] or k:Copy(map, ...)
			map[keyval.key] = map[keyval.key] or k
			v = map[keyval.val] or v:Copy(map, ...)
			map[keyval.val] = map[keyval.val] or v
			copy:GetData()[i] = {key = k, val = v}
		end

		copy:CopyInternalsFrom(self)
		copy.potential_self = self.potential_self
		copy.mutable = self.mutable
		copy:SetLiteral(self:IsLiteral())
		copy.mutations = self.mutations
		copy.scope = self.scope
		copy.BaseTable = self.BaseTable

		--[[
		
		copy.argument_index = self.argument_index
		copy.parent = self.parent
		copy.reference_id = self.reference_id
		]] if self.Self then copy:SetSelf(self.Self:Copy()) end

		if self.MetaTable then copy:SetMetaTable(self.MetaTable) end

		return copy
	end

	function META:GetContract()
		return self.contracts[#self.contracts] or self.Contract
	end

	function META:PushContract(contract)
		table.insert(self.contracts, contract)
	end

	function META:PopContract()
		table.remove(self.contracts)
	end

	function META:pairs()
		local i = 1
		return function()
			local keyval = self:GetData() and
				self:GetData()[i] or
				self:GetContract() and
				self:GetContract()[i]

			if not keyval then return nil end

			i = i + 1
			return keyval.key, keyval.val
		end
	end

	--[[#type META.@Self.suppress = boolean]]

	function META:HasLiteralKeys()
		if self.suppress then return true end

		for _, v in ipairs(self:GetData()) do
			if
				v.val ~= self and
				v.key ~= self and
				v.val.Type ~= "function" and
				v.key.Type ~= "function"
			then
				self.suppress = true
				local ok, reason = v.key:IsLiteral()
				self.suppress = false

				if not ok then
					return type_errors.other(
						{
							"the key ",
							v.key,
							" is not a literal because ",
							reason,
						}
					)
				end
			end
		end

		return true
	end

	function META:IsLiteral()
		if self.suppress then return true end

		if self:GetContract() then return false end

		for _, v in ipairs(self:GetData()) do
			if
				v.val ~= self and
				v.key ~= self and
				v.val.Type ~= "function" and
				v.key.Type ~= "function"
			then
				if v.key.Type == "union" then
					return false,
					type_errors.other(
						{
							"the value ",
							v.val,
							" is not a literal because it's a union",
						}
					)
				end

				self.suppress = true
				local ok, reason = v.key:IsLiteral()
				self.suppress = false

				if not ok then
					return type_errors.other(
						{
							"the key ",
							v.key,
							" is not a literal because ",
							reason,
						}
					)
				end

				if v.val.Type == "union" then
					return false,
					type_errors.other(
						{
							"the value ",
							v.val,
							" is not a literal because it's a union",
						}
					)
				end

				self.suppress = true
				local ok, reason = v.val:IsLiteral()
				self.suppress = false

				if not ok then
					return type_errors.other(
						{
							"the value ",
							v.val,
							" is not a literal because ",
							reason,
						}
					)
				end
			end
		end

		return true
	end

	function META:IsFalsy()
		return false
	end

	function META:IsTruthy()
		return true
	end

	local function unpack_keyval(keyval--[[#: ref {key = any, val = any}]])
		local key, val = keyval.key, keyval.val
		return key, val
	end

	function META.Extend(A--[[#: TTable]], B--[[#: TTable]])
		if B.Type ~= "table" then return false, "cannot extend non table" end

		local map = {}

		if A:GetContract() then
			if A == A:GetContract() then
				A:SetContract()
				A = A:Copy()
				A:SetContract(A)
			end

			A = A:GetContract()
		else
			A = A:Copy(map)
		end

		map[B] = A
		B = B:Copy(map)

		for _, keyval in ipairs(B:GetData()) do
			local ok, reason = A:SetExplicit(unpack_keyval(keyval))

			if not ok then return ok, reason end
		end

		return A
	end

	function META.Union(A--[[#: TTable]], B--[[#: TTable]])
		local copy = META.New({})

		for _, keyval in ipairs(A:GetData()) do
			copy:Set(unpack_keyval(keyval))
		end

		for _, keyval in ipairs(B:GetData()) do
			copy:Set(unpack_keyval(keyval))
		end

		return copy
	end

	function META:Call(analyzer, arguments, ...)
		local LString = require("nattlua.types.string").LString
		local __call = self:GetMetaTable() and self:GetMetaTable():Get(LString("__call"))

		if __call then
			local new_arguments = {self}

			for _, v in ipairs(arguments:GetData()) do
				table.insert(new_arguments, v)
			end

			return analyzer:Call(__call, Tuple(new_arguments), ...)
		end

		return type_errors.other("table has no __call metamethod")
	end

	function META:PrefixOperator(op--[[#: "#"]])
		if op == "#" then
			local keys = (self:GetContract() or self):GetData()

			if #keys == 1 and keys[1].key and keys[1].key.Type == "number" then
				return keys[1].key:Copy()
			end

			return Number(self:GetLength()):SetLiteral(self:IsLiteral())
		end
	end

	function META.LogicalComparison(l, r, op, env)
		if op == "==" then
			if env == "runtime" then
				if l:GetReferenceId() and r:GetReferenceId() then
					return l:GetReferenceId() == r:GetReferenceId()
				end

				return nil
			elseif env == "typesystem" then
				return l:IsSubsetOf(r) and r:IsSubsetOf(l)
			end
		end

		return type_errors.binary(op, l, r)
	end

	function META.New()
		return setmetatable({Data = {}, contracts = {}}, META)
	end

	return {Table = META.New}	
end)("./nattlua/types/table.lua");
package.loaded["nattlua"] = (function(...)
	if not table.unpack and _G.unpack then table.unpack = _G.unpack end

	if not _G.loadstring and _G.load then _G.loadstring = _G.load end

	do -- these are just helpers for print debugging
		table.print = require("nattlua.other.table_print")
		debug.trace = function(...)
			print(debug.traceback(...))
		end
	-- local old = print; function print(...) old(debug.traceback()) end
	end

	local helpers = require("nattlua.other.helpers")
	helpers.JITOptimize()
	--helpers.EnableJITDumper()
	return require("nattlua.init")	
end)("./nattlua.lua");
package.loaded["nattlua.runtime.base_environment"] = (function(...)
	local Table = require("nattlua.types.table").Table
	local LStringNoMeta = require("nattlua.types.string").LStringNoMeta
	return {
		BuildBaseEnvironment = function()
			if _G.DISABLE_BASE_ENV then
				return require("nattlua.types.table").Table({}),
				require("nattlua.types.table").Table({})
			end

			local nl = require("nattlua")
			local compiler = assert(nl.File("nattlua/definitions/index.nlua"))
			assert(compiler:Lex())
			assert(compiler:Parse())
			local runtime_env = Table()
			local typesystem_env = Table()
			typesystem_env.string_metatable = Table()
			compiler:SetEnvironments(runtime_env, typesystem_env)
			local base = compiler.Analyzer()
			assert(compiler:Analyze(base))
			typesystem_env.string_metatable:Set(LStringNoMeta("__index"), typesystem_env:Get(LStringNoMeta("string")))
			return runtime_env, typesystem_env
		end,
	}	
end)("./nattlua/runtime/base_environment.lua");
package.loaded["nattlua.code.code"] = (function(...)
	local META = {}
	META.__index = META
	--[[#type META.@Name = "Code"]]
	--[[#type META.@Self = {
		Buffer = string,
		Name = string,
	}]]

	function META:GetString()
		return self.Buffer
	end

	function META:GetName()
		return self.Name
	end

	function META:GetByteSize()
		return #self.Buffer
	end

	function META:GetStringSlice(start--[[#: number]], stop--[[#: number]])
		return self.Buffer:sub(start, stop)
	end

	function META:GetByte(pos--[[#: number]])
		return self.Buffer:byte(pos) or 0
	end

	function META:FindNearest(str--[[#: string]], start--[[#: number]])
		local _, pos = self.Buffer:find(str, start, true)

		if not pos then return nil end

		return pos + 1
	end

	local function remove_bom_header(str--[[#: string]])--[[#: string]]
		if str:sub(1, 2) == "\xFE\xFF" then
			return str:sub(3)
		elseif str:sub(1, 3) == "\xEF\xBB\xBF" then
			return str:sub(4)
		end

		return str
	end

	local function get_default_name()
		local info = debug.getinfo(3)

		if info then
			local parent_line = info.currentline
			local parent_name = info.source:sub(2)
			return parent_name .. ":" .. parent_line
		end

		return "unknown line : unknown name"
	end

	function META.New(lua_code--[[#: string]], name--[[#: string | nil]])
		local self = setmetatable(
			{
				Buffer = remove_bom_header(lua_code),
				Name = name or get_default_name(),
			},
			META
		)
		return self
	end

	--[[#type Code = META.@Self]]
	return META.New	
end)("./nattlua/code/code.lua");
package.loaded["nattlua.other.table_pool"] = (function(...)
	local pcall = _G.pcall
	local pairs = _G.pairs
	local ok, table_new = pcall(require, "table.new")

	if not ok then table_new = function()
		return {}
	end end

	return function(alloc--[[#: ref (function=()>({[string] = any}))]], size--[[#: number]])
		local records = 0

		for _, _ in pairs(alloc()) do
			records = records + 1
		end

		local i
		local pool = table_new(size, records)--[[# as {[number] = nil | return_type<|alloc|>[1]}]]

		local function refill()
			i = 1

			for i = 1, size do
				pool[i] = alloc()
			end
		end

		refill()
		return function()
			local tbl = pool[i]

			if not tbl then
				refill()
				tbl = pool[i]--[[# as return_type<|alloc|>[1] ]]
			end

			i = i + 1
			return tbl
		end
	end	
end)("./nattlua/other/table_pool.lua");
package.loaded["nattlua.lexer.token"] = (function(...)
	local table_pool = require("nattlua.other.table_pool")
	--[[#local type TokenWhitespaceType = "line_comment" | "multiline_comment" | "comment_escape" | "space"]]
	--[[#local type TokenType = "analyzer_debug_code" | "parser_debug_code" | "letter" | "string" | "number" | "symbol" | "end_of_file" | "shebang" | "discard" | "unknown" | TokenWhitespaceType]]
	--[[#local type TokenReturnType = TokenType | false]]
	--[[#local type WhitespaceToken = {
		type = TokenWhitespaceType,
		value = string,
		start = number,
		stop = number,
	}]]
	local META = {}
	META.__index = META

	--[[#local analyzer function parent_type(what: literal string, offset: literal number)
		return analyzer:GetCurrentType(what:GetData(), offset:GetData())
	end]]

	--[[#type META.@Name = "Token"]]
	--[[#type META.@Self = {
		type = TokenType,
		value = string,
		start = number,
		stop = number,
		is_whitespace = boolean | nil,
		string_value = nil | string,
		inferred_type = nil | any,
		inferred_types = nil | List<|any|>,
		whitespace = false | nil | {
			[1 .. inf] = parent_type<|"table", 2|>,
		},
	}]]

	function META:__tostring()
		return self.type .. ": " .. self.value
	end

	function META:AddType(obj)
		self.inferred_types = self.inferred_types or {}
		table.insert(self.inferred_types, obj)
		self.inferred_type = obj
	end

	function META:GetTypes()
		return self.inferred_types or {}
	end

	function META:GetLastType()
		do
			return self.inferred_type
		end

		return self.inferred_types and self.inferred_types[#self.inferred_types]
	end

	local new_token = table_pool(
		function()
			local x = {
				type = "unknown",
				value = "",
				whitespace = false,
				start = 0,
				stop = 0,
			}
			return x
		end,
		3105585
	)

	function META.New(
		type--[[#: TokenType]],
		is_whitespace--[[#: boolean]],
		start--[[#: number]],
		stop--[[#: number]]
	)--[[#: META.@Self]]
		local tk = new_token()
		tk.type = type
		tk.is_whitespace = is_whitespace
		tk.start = start
		tk.stop = stop
		setmetatable(tk, META)
		return tk
	end

	META.TokenWhitespaceType = TokenWhitespaceType
	META.TokenType = TokenType
	META.TokenReturnType = TokenReturnType
	META.WhitespaceToken = TokenReturnType
	return META	
end)("./nattlua/lexer/token.lua");
package.loaded["nattlua.syntax.characters"] = (function(...)
	local characters = {}
	local B = string.byte

	function characters.IsLetter(c--[[#: number]])--[[#: boolean]]
		return (
				c >= B("a") and
				c <= B("z")
			)
			or
			(
				c >= B("A") and
				c <= B("Z")
			)
			or
			(
				c == B("_") or
				c == B("@")
				or
				c >= 127
			)
	end

	function characters.IsDuringLetter(c--[[#: number]])--[[#: boolean]]
		return (
				c >= B("a") and
				c <= B("z")
			)
			or
			(
				c >= B("0") and
				c <= B("9")
			)
			or
			(
				c >= B("A") and
				c <= B("Z")
			)
			or
			(
				c == B("_") or
				c == B("@")
				or
				c >= 127
			)
	end

	function characters.IsNumber(c--[[#: number]])--[[#: boolean]]
		return (c >= B("0") and c <= B("9"))
	end

	function characters.IsSpace(c--[[#: number]])--[[#: boolean]]
		return c > 0 and c <= 32
	end

	function characters.IsSymbol(c--[[#: number]])--[[#: boolean]]
		return c ~= B("_") and
			(
				(
					c >= B("!") and
					c <= B("/")
				)
				or
				(
					c >= B(":") and
					c <= B("?")
				)
				or
				(
					c >= B("[") and
					c <= B("`")
				)
				or
				(
					c >= B("{") and
					c <= B("~")
				)
			)
	end

	local function generate_map(str--[[#: string]])
		local out = {}

		for i = 1, #str do
			out[str:byte(i)] = true
		end

		return out
	end

	local allowed_hex = generate_map("1234567890abcdefABCDEF")

	function characters.IsHex(c--[[#: number]])--[[#: boolean]]
		return allowed_hex[c] ~= nil
	end

	return characters	
end)("./nattlua/syntax/characters.lua");
package.loaded["nattlua.syntax.syntax"] = (function(...)
	--[[#local type { Token } = import("~/nattlua/lexer/token.nlua")]]

	local META = {}
	META.__index = META
	--[[#type META.@Name = "Syntax"]]
	--[[#type META.@Self = {
		BinaryOperatorInfo = Map<|string, {left_priority = number, right_priority = number}|>,
		NumberAnnotations = List<|string|>,
		Symbols = List<|string|>,
		BinaryOperators = List<|List<|string|>|>,
		PrefixOperators = Map<|string, true|>,
		PostfixOperators = Map<|string, true|>,
		PrimaryBinaryOperators = Map<|string, true|>,
		SymbolCharacters = List<|string|>,
		KeywordValues = Map<|string, true|>,
		Keywords = Map<|string, true|>,
		NonStandardKeywords = Map<|string, true|>,
		BinaryOperatorFunctionTranslate = Map<|string, {string, string, string}|>,
		PostfixOperatorFunctionTranslate = Map<|string, {string, string}|>,
		PrefixOperatorFunctionTranslate = Map<|string, {string, string}|>,
	}]]

	function META.New()
		local self = setmetatable(
			{
				NumberAnnotations = {},
				BinaryOperatorInfo = {},
				Symbols = {},
				BinaryOperators = {},
				PrefixOperators = {},
				PostfixOperators = {},
				PrimaryBinaryOperators = {},
				SymbolCharacters = {},
				KeywordValues = {},
				Keywords = {},
				NonStandardKeywords = {},
				BinaryOperatorFunctionTranslate = {},
				PostfixOperatorFunctionTranslate = {},
				PrefixOperatorFunctionTranslate = {},
			},
			META
		)
		return self
	end

	local function has_value(tbl--[[#: {[1 .. inf] = string} | {}]], value--[[#: string]])
		for k, v in ipairs(tbl) do
			if v == value then return true end
		end

		return false
	end

	function META:AddSymbols(tbl--[[#: List<|string|>]])
		for _, symbol in pairs(tbl) do
			if symbol:find("%p") and not has_value(self.Symbols, symbol) then
				table.insert(self.Symbols, symbol)
			end
		end

		table.sort(self.Symbols, function(a, b)
			return #a > #b
		end)
	end

	function META:AddNumberAnnotations(tbl--[[#: List<|string|>]])
		for i, v in ipairs(tbl) do
			if not has_value(self.NumberAnnotations, v) then
				table.insert(self.NumberAnnotations, v)
			end
		end

		table.sort(self.NumberAnnotations, function(a, b)
			return #a > #b
		end)
	end

	function META:GetNumberAnnotations()
		return self.NumberAnnotations
	end

	function META:AddBinaryOperators(tbl--[[#: List<|List<|string|>|>]])
		for priority, group in ipairs(tbl) do
			for _, token in ipairs(group) do
				local right = token:sub(1, 1) == "R"

				if right then token = token:sub(2) end

				if right then
					self.BinaryOperatorInfo[token] = {
						left_priority = priority + 1,
						right_priority = priority,
					}
				else
					self.BinaryOperatorInfo[token] = {
						left_priority = priority,
						right_priority = priority,
					}
				end

				self:AddSymbols({token})
			end
		end
	end

	function META:GetBinaryOperatorInfo(tk--[[#: Token]])
		return self.BinaryOperatorInfo[tk.value]
	end

	function META:AddPrefixOperators(tbl--[[#: List<|string|>]])
		self:AddSymbols(tbl)

		for _, str in ipairs(tbl) do
			self.PrefixOperators[str] = true
		end
	end

	function META:IsPrefixOperator(token--[[#: Token]])
		return self.PrefixOperators[token.value]
	end

	function META:AddPostfixOperators(tbl--[[#: List<|string|>]])
		self:AddSymbols(tbl)

		for _, str in ipairs(tbl) do
			self.PostfixOperators[str] = true
		end
	end

	function META:IsPostfixOperator(token--[[#: Token]])
		return self.PostfixOperators[token.value]
	end

	function META:AddPrimaryBinaryOperators(tbl--[[#: List<|string|>]])
		self:AddSymbols(tbl)

		for _, str in ipairs(tbl) do
			self.PrimaryBinaryOperators[str] = true
		end
	end

	function META:IsPrimaryBinaryOperator(token--[[#: Token]])
		return self.PrimaryBinaryOperators[token.value]
	end

	function META:AddSymbolCharacters(tbl--[[#: List<|string|>]])
		self.SymbolCharacters = tbl
		self:AddSymbols(tbl)
	end

	function META:AddKeywords(tbl--[[#: List<|string|>]])
		self:AddSymbols(tbl)

		for _, str in ipairs(tbl) do
			self.Keywords[str] = true
		end
	end

	function META:IsKeyword(token--[[#: Token]])
		return self.Keywords[token.value]
	end

	function META:AddKeywordValues(tbl--[[#: List<|string|>]])
		self:AddSymbols(tbl)

		for _, str in ipairs(tbl) do
			self.Keywords[str] = true
			self.KeywordValues[str] = true
		end
	end

	function META:IsKeywordValue(token--[[#: Token]])
		return self.KeywordValues[token.value]
	end

	function META:AddNonStandardKeywords(tbl--[[#: List<|string|>]])
		self:AddSymbols(tbl)

		for _, str in ipairs(tbl) do
			self.NonStandardKeywords[str] = true
		end
	end

	function META:IsNonStandardKeyword(token--[[#: Token]])
		return self.NonStandardKeywords[token.value]
	end

	function META:GetSymbols()
		return self.Symbols
	end

	function META:AddBinaryOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
		for k, v in pairs(tbl) do
			local a, b, c = v:match("(.-)A(.-)B(.*)")

			if a and b and c then
				self.BinaryOperatorFunctionTranslate[k] = {" " .. a, b, c .. " "}
			end
		end
	end

	function META:GetFunctionForBinaryOperator(token--[[#: Token]])
		return self.BinaryOperatorFunctionTranslate[token.value]
	end

	function META:AddPrefixOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
		for k, v in pairs(tbl) do
			local a, b = v:match("^(.-)A(.-)$")

			if a and b then
				self.PrefixOperatorFunctionTranslate[k] = {" " .. a, b .. " "}
			end
		end
	end

	function META:GetFunctionForPrefixOperator(token--[[#: Token]])
		return self.PrefixOperatorFunctionTranslate[token.value]
	end

	function META:AddPostfixOperatorFunctionTranslate(tbl--[[#: Map<|string, string|>]])
		for k, v in pairs(tbl) do
			local a, b = v:match("^(.-)A(.-)$")

			if a and b then
				self.PostfixOperatorFunctionTranslate[k] = {" " .. a, b .. " "}
			end
		end
	end

	function META:GetFunctionForPostfixOperator(token--[[#: Token]])
		return self.PostfixOperatorFunctionTranslate[token.value]
	end

	function META:IsValue(token--[[#: Token]])
		if token.type == "number" or token.type == "string" then return true end

		if self:IsKeywordValue(token) then return true end

		if self:IsKeyword(token) then return false end

		if token.type == "letter" then return true end

		return false
	end

	function META:GetTokenType(tk--[[#: Token]])
		if tk.type == "letter" and self:IsKeyword(tk) then
			return "keyword"
		elseif tk.type == "symbol" then
			if self:IsPrefixOperator(tk) then
				return "operator_prefix"
			elseif self:IsPostfixOperator(tk) then
				return "operator_postfix"
			elseif self:GetBinaryOperatorInfo(tk) then
				return "operator_binary"
			end
		end

		return tk.type
	end

	return META.New	
end)("./nattlua/syntax/syntax.lua");
package.loaded["nattlua.syntax.runtime"] = (function(...)
	local Syntax = require("nattlua.syntax.syntax")
	local runtime = Syntax()
	runtime:AddSymbolCharacters(
		{
			",",
			";",
			"(",
			")",
			"{",
			"}",
			"[",
			"]",
			"=",
			"::",
			"\"",
			"'",
			"<|",
			"|>",
		}
	)
	runtime:AddNumberAnnotations({
		"ull",
		"ll",
		"ul",
		"i",
	})
	runtime:AddKeywords(
		{
			"do",
			"end",
			"if",
			"then",
			"else",
			"elseif",
			"for",
			"in",
			"while",
			"repeat",
			"until",
			"break",
			"return",
			"local",
			"function",
			"and",
			"not",
			"or",
			-- these are just to make sure all code is covered by tests
			"ÆØÅ",
			"ÆØÅÆ",
		}
	)
	-- these are keywords, but can be used as names
	runtime:AddNonStandardKeywords({"continue", "import", "literal", "ref", "mutable", "goto"})
	runtime:AddKeywordValues({
		"...",
		"nil",
		"true",
		"false",
	})
	runtime:AddPrefixOperators({"-", "#", "not", "!", "~", "supertype"})
	runtime:AddPostfixOperators(
		{
			-- these are just to make sure all code is covered by tests
			"++",
			"ÆØÅ",
			"ÆØÅÆ",
		}
	)
	runtime:AddBinaryOperators(
		{
			{"or", "||"},
			{"and", "&&"},
			{"<", ">", "<=", ">=", "~=", "==", "!="},
			{"|"},
			{"~"},
			{"&"},
			{"<<", ">>"},
			{"R.."}, -- right associative
			{"+", "-"},
			{"*", "/", "/idiv/", "%"},
			{"R^"}, -- right associative
		}
	)
	runtime:AddPrimaryBinaryOperators({
		".",
		":",
	})
	runtime:AddBinaryOperatorFunctionTranslate(
		{
			[">>"] = "bit.rshift(A, B)",
			["<<"] = "bit.lshift(A, B)",
			["|"] = "bit.bor(A, B)",
			["&"] = "bit.band(A, B)",
			["//"] = "math.floor(A / B)",
			["~"] = "bit.bxor(A, B)",
		}
	)
	runtime:AddPrefixOperatorFunctionTranslate({
		["~"] = "bit.bnot(A)",
	})
	runtime:AddPostfixOperatorFunctionTranslate({
		["++"] = "(A+1)",
		["ÆØÅ"] = "(A)",
		["ÆØÅÆ"] = "(A)",
	})
	return runtime	
end)("./nattlua/syntax/runtime.lua");
package.loaded["nattlua.lexer.lexer"] = (function(...)
	--[[#local type { TokenType } = import("~/nattlua/lexer/token.nlua")]]

	local Code = require("nattlua.code.code")
	local Token = require("nattlua.lexer.token").New
	local setmetatable = _G.setmetatable
	local ipairs = _G.ipairs
	local META = {}
	META.__index = META
	--[[#type META.@Name = "Lexer"]]
	--[[#type META.@Self = {
		Code = Code,
		Position = number,
	}]]
	local B = string.byte

	function META:GetLength()--[[#: number]]
		return self.Code:GetByteSize()
	end

	function META:GetStringSlice(start--[[#: number]], stop--[[#: number]])--[[#: string]]
		return self.Code:GetStringSlice(start, stop)
	end

	function META:PeekByte(offset--[[#: number | nil]])--[[#: number]]
		offset = offset or 0
		return self.Code:GetByte(self.Position + offset)
	end

	function META:FindNearest(str--[[#: string]])--[[#: nil | number]]
		return self.Code:FindNearest(str, self.Position)
	end

	function META:ReadByte()--[[#: number]]
		local char = self:PeekByte()
		self.Position = self.Position + 1
		return char
	end

	function META:ResetState()
		self.Position = 1
	end

	function META:Advance(len--[[#: number]])
		self.Position = self.Position + len
	end

	function META:SetPosition(i--[[#: number]])
		self.Position = i
	end

	function META:GetPosition()
		return self.Position
	end

	function META:TheEnd()--[[#: boolean]]
		return self.Position > self:GetLength()
	end

	function META:IsString(str--[[#: string]], offset--[[#: number | nil]])--[[#: boolean]]
		offset = offset or 0
		return self.Code:GetStringSlice(self.Position + offset, self.Position + offset + #str - 1) == str
	end

	function META:IsStringLower(str--[[#: string]], offset--[[#: number | nil]])--[[#: boolean]]
		offset = offset or 0
		return self.Code:GetStringSlice(self.Position + offset, self.Position + offset + #str - 1):lower() == str
	end

	function META:OnError(
		code--[[#: Code]],
		msg--[[#: string]],
		start--[[#: number | nil]],
		stop--[[#: number | nil]]
	) end

	function META:Error(msg--[[#: string]], start--[[#: number | nil]], stop--[[#: number | nil]])
		self:OnError(self.Code, msg, start or self.Position, stop or self.Position)
	end

	function META:ReadShebang()
		if self.Position == 1 and self:IsString("#") then
			for _ = self.Position, self:GetLength() do
				self:Advance(1)

				if self:IsString("\n") then break end
			end

			return true
		end

		return false
	end

	function META:ReadEndOfFile()
		if self.Position > self:GetLength() then
			-- nothing to capture, but remaining whitespace will be added
			self:Advance(1)
			return true
		end

		return false
	end

	function META:ReadUnknown()
		self:Advance(1)
		return "unknown", false
	end

	function META:Read()--[[#: (TokenType, boolean) | (nil, nil)]]
		return nil, nil
	end

	function META:ReadSimple()--[[#: TokenType,boolean,number,number]]
		if self:ReadShebang() then return "shebang", false, 1, self.Position - 1 end

		local start = self.Position
		local type, is_whitespace = self:Read()

		if not type then
			if self:ReadEndOfFile() then
				type = "end_of_file"
				is_whitespace = false
			end
		end

		if not type then type, is_whitespace = self:ReadUnknown() end

		is_whitespace = is_whitespace or false
		return type, is_whitespace, start, self.Position - 1
	end

	function META:NewToken(
		type--[[#: TokenType]],
		is_whitespace--[[#: boolean]],
		start--[[#: number]],
		stop--[[#: number]]
	)
		return Token(type, is_whitespace, start, stop)
	end

	function META:ReadToken()
		local a, b, c, d = self:ReadSimple() -- TODO: unpack not working
		return self:NewToken(a, b, c, d)
	end

	function META:ReadFirstFromArray(strings--[[#: List<|string|>]])--[[#: boolean]]
		for _, str in ipairs(strings) do
			if self:IsStringLower(str) then
				self:Advance(#str)
				return true
			end
		end

		return false
	end

	local fixed = {
		"a",
		"b",
		"f",
		"n",
		"r",
		"t",
		"v",
		"\\",
		"\"",
		"'",
	}
	local pattern = "\\[" .. table.concat(fixed, "\\") .. "]"
	local map_double_quote = {[ [[\"]] ] = [["]]}
	local map_single_quote = {[ [[\']] ] = [[']]}

	for _, v in ipairs(fixed) do
		map_double_quote["\\" .. v] = load("return \"\\" .. v .. "\"")()
		map_single_quote["\\" .. v] = load("return \"\\" .. v .. "\"")()
	end

	local function reverse_escape_string(str, quote--[[#: '"' | "'"]])
		if quote == "\"" then
			str = str:gsub(pattern, map_double_quote)
		elseif quote == "'" then
			str = str:gsub(pattern, map_single_quote)
		end

		return str
	end

	function META:GetTokens()
		self:ResetState()
		local tokens = {}

		for i = self.Position, self:GetLength() + 1 do
			tokens[i] = self:ReadToken()

			if tokens[i].type == "end_of_file" then break end
		end

		for _, token in ipairs(tokens) do
			token.value = self:GetStringSlice(token.start, token.stop)

			if token.type == "string" then
				if token.value:sub(1, 1) == [["]] then
					token.string_value = reverse_escape_string(token.value:sub(2, #token.value - 1), "\"")
				elseif token.value:sub(1, 1) == [[']] then
					token.string_value = reverse_escape_string(token.value:sub(2, #token.value - 1), "'")
				elseif token.value:sub(1, 1) == "[" then
					local start = token.value:match("(%[[%=]*%[)")

					if not start then error("unable to match string") end

					token.string_value = token.value:sub(#start + 1, -#start - 1)
				end
			end
		end

		local whitespace_buffer = {}
		local whitespace_buffer_i = 1
		local non_whitespace = {}
		local non_whitespace_i = 1

		for _, token in ipairs(tokens) do
			if token.type ~= "discard" then
				if token.is_whitespace then
					whitespace_buffer[whitespace_buffer_i] = token
					whitespace_buffer_i = whitespace_buffer_i + 1
				else
					token.whitespace = whitespace_buffer
					non_whitespace[non_whitespace_i] = token
					non_whitespace_i = non_whitespace_i + 1
					whitespace_buffer = {}
					whitespace_buffer_i = 1
				end
			end
		end

		local tokens = non_whitespace
		tokens[#tokens].value = ""
		return tokens
	end

	function META.New(code--[[#: Code]])
		local self = setmetatable({
			Code = code,
			Position = 1,
		}, META)
		self:ResetState()
		return self
	end

	-- lua lexer
	do
		--[[#local type Lexer = META.@Self]]

		--[[#local type { TokenReturnType } = import("~/nattlua/lexer/token.nlua")]]

		local characters = require("nattlua.syntax.characters")
		local runtime_syntax = require("nattlua.syntax.runtime")
		local helpers = require("nattlua.other.quote")

		local function ReadSpace(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if characters.IsSpace(lexer:PeekByte()) then
				while not lexer:TheEnd() do
					lexer:Advance(1)

					if not characters.IsSpace(lexer:PeekByte()) then break end
				end

				return "space"
			end

			return false
		end

		local function ReadLetter(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if not characters.IsLetter(lexer:PeekByte()) then return false end

			while not lexer:TheEnd() do
				lexer:Advance(1)

				if not characters.IsDuringLetter(lexer:PeekByte()) then break end
			end

			return "letter"
		end

		local function ReadMultilineCComment(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if not lexer:IsString("/*") then return false end

			local start = lexer:GetPosition()
			lexer:Advance(2)

			while not lexer:TheEnd() do
				if lexer:IsString("*/") then
					lexer:Advance(2)
					return "multiline_comment"
				end

				lexer:Advance(1)
			end

			lexer:Error(
				"expected multiline c comment to end, reached end of code",
				start,
				start + 1
			)
			return false
		end

		local function ReadLineCComment(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if not lexer:IsString("//") then return false end

			lexer:Advance(2)

			while not lexer:TheEnd() do
				if lexer:IsString("\n") then break end

				lexer:Advance(1)
			end

			return "line_comment"
		end

		local function ReadLineComment(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if not lexer:IsString("--") then return false end

			lexer:Advance(2)

			while not lexer:TheEnd() do
				if lexer:IsString("\n") then break end

				lexer:Advance(1)
			end

			return "line_comment"
		end

		local function ReadMultilineComment(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if
				not lexer:IsString("--[") or
				(
					not lexer:IsString("[", 3) and
					not lexer:IsString("=", 3)
				)
			then
				return false
			end

			local start = lexer:GetPosition()
			-- skip past the --[
			lexer:Advance(3)

			while lexer:IsString("=") do
				lexer:Advance(1)
			end

			if not lexer:IsString("[") then
				-- if we have an incomplete multiline comment, it's just a single line comment
				lexer:SetPosition(start)
				return ReadLineComment(lexer)
			end

			-- skip the last [
			lexer:Advance(1)
			local pos = lexer:FindNearest("]" .. string.rep("=", (lexer:GetPosition() - start) - 4) .. "]")

			if pos then
				lexer:SetPosition(pos)
				return "multiline_comment"
			end

			lexer:Error("expected multiline comment to end, reached end of code", start, start + 1)
			lexer:SetPosition(start + 2)
			return false
		end

		local function ReadInlineAnalyzerDebugCode(lexer--[[#: Lexer & {comment_escape = string | nil}]])--[[#: TokenReturnType]]
			if not lexer:IsString("§") then return false end

			lexer:Advance(#"§")

			while not lexer:TheEnd() do
				if
					lexer:IsString("\n") or
					(
						lexer.comment_escape and
						lexer:IsString(lexer.comment_escape)
					)
				then
					break
				end

				lexer:Advance(1)
			end

			return "analyzer_debug_code"
		end

		local function ReadInlineParserDebugCode(lexer--[[#: Lexer & {comment_escape = string | nil}]])--[[#: TokenReturnType]]
			if not lexer:IsString("£") then return false end

			lexer:Advance(#"£")

			while not lexer:TheEnd() do
				if
					lexer:IsString("\n") or
					(
						lexer.comment_escape and
						lexer:IsString(lexer.comment_escape)
					)
				then
					break
				end

				lexer:Advance(1)
			end

			return "parser_debug_code"
		end

		local function ReadNumberPowExponent(lexer--[[#: Lexer]], what--[[#: string]])
			lexer:Advance(1)

			if lexer:IsString("+") or lexer:IsString("-") then
				lexer:Advance(1)

				if not characters.IsNumber(lexer:PeekByte()) then
					lexer:Error(
						"malformed " .. what .. " expected number, got " .. string.char(lexer:PeekByte()),
						lexer:GetPosition() - 2
					)
					return false
				end
			end

			while not lexer:TheEnd() do
				if not characters.IsNumber(lexer:PeekByte()) then break end

				lexer:Advance(1)
			end

			return true
		end

		local function ReadHexNumber(lexer--[[#: Lexer]])
			if not lexer:IsString("0") or not lexer:IsStringLower("x", 1) then
				return false
			end

			lexer:Advance(2)
			local has_dot = false

			while not lexer:TheEnd() do
				if lexer:IsString("_") then lexer:Advance(1) end

				if not has_dot and lexer:IsString(".") then
					-- 22..66 would be a number range
					-- so we have to return 22 only
					if lexer:IsString(".", 1) then break end

					has_dot = true
					lexer:Advance(1)
				end

				if characters.IsHex(lexer:PeekByte()) then
					lexer:Advance(1)
				else
					if characters.IsSpace(lexer:PeekByte()) or characters.IsSymbol(lexer:PeekByte()) then
						break
					end

					if lexer:IsStringLower("p") then
						if ReadNumberPowExponent(lexer, "pow") then break end
					end

					if lexer:ReadFirstFromArray(runtime_syntax:GetNumberAnnotations()) then break end

					lexer:Error(
						"malformed hex number, got " .. string.char(lexer:PeekByte()),
						lexer:GetPosition() - 1,
						lexer:GetPosition()
					)
					return false
				end
			end

			return "number"
		end

		local function ReadBinaryNumber(lexer--[[#: Lexer]])
			if not lexer:IsString("0") or not lexer:IsStringLower("b", 1) then
				return false
			end

			-- skip past 0b
			lexer:Advance(2)

			while not lexer:TheEnd() do
				if lexer:IsString("_") then lexer:Advance(1) end

				if lexer:IsString("1") or lexer:IsString("0") then
					lexer:Advance(1)
				else
					if characters.IsSpace(lexer:PeekByte()) or characters.IsSymbol(lexer:PeekByte()) then
						break
					end

					if lexer:IsStringLower("e") then
						if ReadNumberPowExponent(lexer, "exponent") then break end
					end

					if lexer:ReadFirstFromArray(runtime_syntax:GetNumberAnnotations()) then break end

					lexer:Error(
						"malformed binary number, got " .. string.char(lexer:PeekByte()),
						lexer:GetPosition() - 1,
						lexer:GetPosition()
					)
					return false
				end
			end

			return "number"
		end

		local function ReadDecimalNumber(lexer--[[#: Lexer]])
			if
				not characters.IsNumber(lexer:PeekByte()) and
				(
					not lexer:IsString(".") or
					not characters.IsNumber(lexer:PeekByte(1))
				)
			then
				return false
			end

			-- if we start with a dot
			-- .0
			local has_dot = false

			if lexer:IsString(".") then
				has_dot = true
				lexer:Advance(1)
			end

			while not lexer:TheEnd() do
				if lexer:IsString("_") then lexer:Advance(1) end

				if not has_dot and lexer:IsString(".") then
					-- 22..66 would be a number range
					-- so we have to return 22 only
					if lexer:IsString(".", 1) then break end

					has_dot = true
					lexer:Advance(1)
				end

				if characters.IsNumber(lexer:PeekByte()) then
					lexer:Advance(1)
				else
					if characters.IsSpace(lexer:PeekByte()) or characters.IsSymbol(lexer:PeekByte()) then
						break
					end

					if lexer:IsString("e") or lexer:IsString("E") then
						if ReadNumberPowExponent(lexer, "exponent") then break end
					end

					if lexer:ReadFirstFromArray(runtime_syntax:GetNumberAnnotations()) then break end

					lexer:Error(
						"malformed number, got " .. string.char(lexer:PeekByte()) .. " in decimal notation",
						lexer:GetPosition() - 1,
						lexer:GetPosition()
					)
					return false
				end
			end

			return "number"
		end

		local function ReadMultilineString(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if
				not lexer:IsString("[", 0) or
				(
					not lexer:IsString("[", 1) and
					not lexer:IsString("=", 1)
				)
			then
				return false
			end

			local start = lexer:GetPosition()
			lexer:Advance(1)

			if lexer:IsString("=") then
				while not lexer:TheEnd() do
					lexer:Advance(1)

					if not lexer:IsString("=") then break end
				end
			end

			if not lexer:IsString("[") then
				lexer:Error(
					"expected multiline string " .. helpers.QuoteToken(lexer:GetStringSlice(start, lexer:GetPosition() - 1) .. "[") .. " got " .. helpers.QuoteToken(lexer:GetStringSlice(start, lexer:GetPosition())),
					start,
					start + 1
				)
				return false
			end

			lexer:Advance(1)
			local closing = "]" .. string.rep("=", (lexer:GetPosition() - start) - 2) .. "]"
			local pos = lexer:FindNearest(closing)

			if pos then
				lexer:SetPosition(pos)
				return "string"
			end

			lexer:Error("expected multiline string " .. helpers.QuoteToken(closing) .. " reached end of code", start, start + 1)
			return false
		end

		local ReadSingleQuoteString
		local ReadDoubleQuoteString

		do
			local B = string.byte
			local escape_character = B([[\]])

			local function build_string_reader(name--[[#: string]], quote--[[#: string]])
				return function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
					if not lexer:IsString(quote) then return false end

					local start = lexer:GetPosition()
					lexer:Advance(1)

					while not lexer:TheEnd() do
						local char = lexer:ReadByte()

						if char == escape_character then
							local char = lexer:ReadByte()

							if char == B("z") and not lexer:IsString(quote) then
								ReadSpace(lexer)
							end
						elseif char == B("\n") then
							lexer:Advance(-1)
							lexer:Error("expected " .. name:lower() .. " quote to end", start, lexer:GetPosition() - 1)
							return "string"
						elseif char == B(quote) then
							return "string"
						end
					end

					lexer:Error(
						"expected " .. name:lower() .. " quote to end: reached end of file",
						start,
						lexer:GetPosition() - 1
					)
					return "string"
				end
			end

			ReadDoubleQuoteString = build_string_reader("double", "\"")
			ReadSingleQuoteString = build_string_reader("single", "'")
		end

		local function ReadSymbol(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if lexer:ReadFirstFromArray(runtime_syntax:GetSymbols()) then return "symbol" end

			return false
		end

		local function ReadCommentEscape(lexer--[[#: Lexer & {comment_escape = string | nil}]])--[[#: TokenReturnType]]
			if lexer:IsString("--[[#") then
				lexer:Advance(5)
				lexer.comment_escape = "]]"
				return "comment_escape"
			elseif lexer:IsString("--[=[#") then
				lexer:Advance(6)
				lexer.comment_escape = "]=]"
				return "comment_escape"
			end

			return false
		end

		local function ReadRemainingCommentEscape(lexer--[[#: Lexer & {comment_escape = string | nil}]])--[[#: TokenReturnType]]
			if lexer.comment_escape and lexer:IsString(lexer.comment_escape--[[# as string]]) then
				lexer:Advance(#lexer.comment_escape--[[# as string]])
				return "comment_escape"
			end

			return false
		end

		function META:Read()--[[#: (TokenType, boolean) | (nil, nil)]]
			if ReadRemainingCommentEscape(self) then return "discard", false end

			do
				local name = ReadSpace(self) or
					ReadCommentEscape(self) or
					ReadMultilineCComment(self) or
					ReadLineCComment(self) or
					ReadMultilineComment(self) or
					ReadLineComment(self)

				if name then return name, true end
			end

			do
				local name = ReadInlineAnalyzerDebugCode(self) or
					ReadInlineParserDebugCode(self) or
					ReadHexNumber(self) or
					ReadBinaryNumber(self) or
					ReadDecimalNumber(self) or
					ReadMultilineString(self) or
					ReadSingleQuoteString(self) or
					ReadDoubleQuoteString(self) or
					ReadLetter(self) or
					ReadSymbol(self)

				if name then return name, false end
			end
		end
	end

	return META.New	
end)("./nattlua/lexer/lexer.lua");
package.loaded["nattlua.transpiler.emitter"] = (function(...)
	local runtime_syntax = require("nattlua.syntax.runtime")
	local characters = require("nattlua.syntax.characters")
	local print = _G.print
	local error = _G.error
	local debug = _G.debug
	local tostring = _G.tostring
	local pairs = _G.pairs
	local table = require("table")
	local ipairs = _G.ipairs
	local assert = _G.assert
	local type = _G.type
	local setmetatable = _G.setmetatable
	local B = string.byte
	local META = {}
	META.__index = META
	local translate_binary = {
		["&&"] = "and",
		["||"] = "or",
		["!="] = "~=",
	}
	local translate_prefix = {
		["!"] = "not ",
	}

	do -- internal
		function META:Whitespace(str, force)
			if self.config.preserve_whitespace == nil and not force then return end

			if str == "\t" then
				if self.config.no_newlines then
					self:Emit(" ")
				else
					self:Emit(("\t"):rep(self.level))
					self.last_indent_index = #self.out
				end
			elseif str == " " then
				self:Emit(" ")
			elseif str == "\n" then
				self:Emit(self.config.no_newlines and " " or "\n")
				self.last_newline_index = #self.out
			else
				error("unknown whitespace " .. ("%q"):format(str))
			end
		end

		function META:Emit(str)
			if type(str) ~= "string" then
				error(debug.traceback("attempted to emit a non string " .. tostring(str)))
			end

			if str == "" then return end

			self.out[self.i] = str or ""
			self.i = self.i + 1
		end

		function META:EmitNonSpace(str)
			self:Emit(str)
			self.last_non_space_index = #self.out
		end

		function META:EmitSpace(str)
			self:Emit(str)
		end

		function META:Indent()
			self.level = self.level + 1
		end

		function META:Outdent()
			self.level = self.level - 1
		end

		function META:GetPrevChar()
			local prev = self.out[self.i - 1]
			local char = prev and prev:sub(-1)
			return char and char:byte() or 0
		end

		function META:EmitWhitespace(token)
			if self.config.preserve_whitespace == false and token.type == "space" then
				return
			end

			self:EmitToken(token)

			if token.type ~= "space" then
				self:Whitespace("\n")
				self:Whitespace("\t")
			end
		end

		function META:EmitToken(node, translate)
			if
				self.config.extra_indent and
				self.config.preserve_whitespace == false and
				self.inside_call_expression
			then
				self.tracking_indents = self.tracking_indents or {}

				if type(self.config.extra_indent[node.value]) == "table" then
					self:Indent()
					local info = self.config.extra_indent[node.value]

					if type(info.to) == "table" then
						for to in pairs(info.to) do
							self.tracking_indents[to] = self.tracking_indents[to] or {}
							table.insert(self.tracking_indents[to], {info = info, level = self.level})
						end
					else
						self.tracking_indents[info.to] = self.tracking_indents[info.to] or {}
						table.insert(self.tracking_indents[info.to], {info = info, level = self.level})
					end
				elseif self.tracking_indents[node.value] then
					for _, info in ipairs(self.tracking_indents[node.value]) do
						if info.level == self.level or info.level == self.pre_toggle_level then
							self:Outdent()
							local info = self.tracking_indents[node.value]

							for key, val in pairs(self.tracking_indents) do
								if info == val.info then self.tracking_indents[key] = nil end
							end

							if self.out[self.last_indent_index] then
								self.out[self.last_indent_index] = self.out[self.last_indent_index]:sub(2)
							end

							if self.toggled_indents then
								self:Outdent()
								self.toggled_indents = {}

								if self.out[self.last_indent_index] then
									self.out[self.last_indent_index] = self.out[self.last_indent_index]:sub(2)
								end
							end

							break
						end
					end
				end

				if self.config.extra_indent[node.value] == "toggle" then
					self.toggled_indents = self.toggled_indents or {}

					if not self.toggled_indents[node.value] then
						self.toggled_indents[node.value] = true
						self.pre_toggle_level = self.level
						self:Indent()
					elseif self.toggled_indents[node.value] then
						if self.out[self.last_indent_index] then
							self.out[self.last_indent_index] = self.out[self.last_indent_index]:sub(2)
						end
					end
				end
			end

			if node.whitespace then
				if self.config.preserve_whitespace == false then
					for i, token in ipairs(node.whitespace) do
						if token.type == "line_comment" then
							local start = i

							for i = self.i - 1, 1, -1 do
								if not self.out[i]:find("^%s+") then
									local found_newline = false

									for i = start, 1, -1 do
										local token = node.whitespace[i]

										if token.value:find("\n") then
											found_newline = true

											break
										end
									end

									if not found_newline then
										self.i = i + 1
										self:Emit(" ")
									end

									break
								end
							end

							self:EmitToken(token)

							if node.whitespace[i + 1] then
								self:Whitespace("\n")
								self:Whitespace("\t")
							end
						elseif token.type == "multiline_comment" then
							self:EmitToken(token)
							self:Whitespace(" ")
						end
					end
				else
					for _, token in ipairs(node.whitespace) do
						if token.type ~= "comment_escape" then self:EmitWhitespace(token) end
					end
				end
			end

			if self.TranslateToken then
				translate = self:TranslateToken(node) or translate
			end

			if translate then
				if type(translate) == "table" then
					self:Emit(translate[node.value] or node.value)
				elseif type(translate) == "function" then
					self:Emit(translate(node.value))
				elseif translate ~= "" then
					self:Emit(translate)
				end
			else
				self:Emit(node.value)
			end

			if
				node.type ~= "line_comment" and
				node.type ~= "multiline_comment" and
				node.type ~= "space"
			then
				self.last_non_space_index = #self.out
			end
		end

		function META:Initialize()
			self.level = 0
			self.out = {}
			self.i = 1
		end

		function META:Concat()
			return table.concat(self.out)
		end

		do
			function META:PushLoop(node)
				self.loop_nodes = self.loop_nodes or {}
				table.insert(self.loop_nodes, node)
			end

			function META:PopLoop()
				local node = table.remove(self.loop_nodes)

				if node.on_pop then node:on_pop() end
			end

			function META:GetLoopNode()
				if self.loop_nodes then return self.loop_nodes[#self.loop_nodes] end

				return nil
			end
		end
	end

	do -- newline breaking
		do
			function META:PushForcedLineBreaking(b)
				self.force_newlines = self.force_newlines or {}
				table.insert(self.force_newlines, b and debug.traceback())
			end

			function META:PopForcedLineBreaking()
				table.remove(self.force_newlines)
			end

			function META:IsLineBreaking()
				if self.force_newlines then return self.force_newlines[#self.force_newlines] end
			end
		end

		function META:ShouldLineBreakNode(node)
			if node.kind == "table" or node.kind == "type_table" then
				for _, exp in ipairs(node.children) do
					if exp.value_expression and exp.value_expression.kind == "function" then
						return true
					end
				end

				if #node.children > 0 and #node.children == #node.tokens["separators"] then
					return true
				end
			end

			if node.kind == "function" then return #node.statements > 1 end

			if node.kind == "if" then
				for i = 1, #node.statements do
					if #node.statements[i] > 1 then return true end
				end
			end

			return node:GetLength() > self.config.max_line_length
		end

		function META:EmitLineBreakableExpression(node)
			local newlines = self:ShouldLineBreakNode(node)

			if newlines then
				self:Indent()
				self:Whitespace("\n")
				self:Whitespace("\t")
			else
				self:Whitespace(" ")
			end

			self:PushForcedLineBreaking(newlines)
			self:EmitExpression(node)
			self:PopForcedLineBreaking()

			if newlines then
				self:Outdent()
				self:Whitespace("\n")
				self:Whitespace("\t")
			else
				self:Whitespace(" ")
			end
		end

		function META:EmitLineBreakableList(tbl, func)
			local newline = self:ShouldBreakExpressionList(tbl)
			self:PushForcedLineBreaking(newline)

			if newline then
				self:Indent()
				self:Whitespace("\n")
				self:Whitespace("\t")
			end

			func(self, tbl)

			if newline then
				self:Outdent()
				self:Whitespace("\n")
				self:Whitespace("\t")
			end

			self:PopForcedLineBreaking()
		end

		function META:EmitExpressionList(tbl)
			self:EmitNodeList(tbl, self.EmitExpression)
		end

		function META:EmitIdentifierList(tbl)
			self:EmitNodeList(tbl, self.EmitIdentifier)
		end
	end

	function META:BuildCode(block)
		if block.imports then
			self.done = {}
			self:EmitNonSpace("IMPORTS = IMPORTS or {}\n")

			for i, node in ipairs(block.imports) do
				if not self.done[node.path] and node.root then
					self:Emit(
						"IMPORTS['" .. node.path .. "'] = function(...) " .. node.root:Render(self.config or {}) .. " end\n"
					)
					self.done[node.path] = true
				end
			end
		end

		if block.required_files then
			self.done = {}

			for i, node in ipairs(block.required_files) do
				if not self.done[node.path] and node.root then
					self:EmitNonSpace("package.loaded[")
					self:EmitToken(node.expressions[1].value)
					self:EmitNonSpace("] = (function(...)")
					self:Whitespace("\n")
					self:Indent()
					self:EmitStatements(node.root.statements)
					self:Outdent()
					self:Whitespace("\n")
					self:EmitNonSpace("end)(\"" .. node.path .. "\");")
					self:Whitespace("\n")
					self.done[node.path] = true
				end
			end
		end

		self:EmitStatements(block.statements)
		return self:Concat()
	end

	function META:OptionalWhitespace()
		if self.config.preserve_whitespace == nil then return end

		if
			characters.IsLetter(self:GetPrevChar()) or
			characters.IsNumber(self:GetPrevChar())
		then
			self:EmitSpace(" ")
		end
	end

	do
		local escape = {
			["\a"] = [[\a]],
			["\b"] = [[\b]],
			["\f"] = [[\f]],
			["\n"] = [[\n]],
			["\r"] = [[\r]],
			["\t"] = [[\t]],
			["\v"] = [[\v]],
		}
		local skip_escape = {
			["x"] = true,
			["X"] = true,
			["u"] = true,
			["U"] = true,
		}

		local function escape_string(str, quote)
			local new_str = {}

			for i = 1, #str do
				local c = str:sub(i, i)

				if c == quote then
					new_str[i] = "\\" .. c
				elseif escape[c] then
					new_str[i] = escape[c]
				elseif c == "\\" and not skip_escape[str:sub(i + 1, i + 1)] then
					new_str[i] = "\\\\"
				else
					new_str[i] = c
				end
			end

			return table.concat(new_str)
		end

		function META:EmitStringToken(token)
			if self.config.string_quote then
				local current = token.value:sub(1, 1)
				local target = self.config.string_quote

				if current == "\"" or current == "'" then
					local contents = escape_string(token.string_value, target)
					self:EmitToken(token, target .. contents .. target)
					return
				end
			end

			local needs_space = token.value:sub(1, 1) == "[" and self:GetPrevChar() == B("[")

			if needs_space then self:Whitespace(" ") end

			self:EmitToken(token)

			if needs_space then self:Whitespace(" ") end
		end
	end

	function META:EmitNumberToken(token)
		self:EmitToken(token)
	end

	function META:EmitFunctionSignature(node)
		self:EmitToken(node.tokens["function"])
		self:EmitToken(node.tokens["="])
		self:EmitToken(node.tokens["arguments("])
		self:EmitLineBreakableList(node.identifiers, self.EmitIdentifierList)
		self:EmitToken(node.tokens["arguments)"])
		self:EmitToken(node.tokens[">"])
		self:EmitToken(node.tokens["return("])
		self:EmitLineBreakableList(node.return_types, self.EmitExpressionList)
		self:EmitToken(node.tokens["return)"])
	end

	function META:EmitExpression(node)
		local newlines = self:IsLineBreaking()

		if node.tokens["("] then
			for _, node in ipairs(node.tokens["("]) do
				self:EmitToken(node)
			end

			if node.tokens["("] and newlines then
				self:Indent()
				self:Whitespace("\n")
				self:Whitespace("\t")
			end
		end

		if node.kind == "binary_operator" then
			self:EmitBinaryOperator(node)
		elseif node.kind == "function" then
			self:EmitAnonymousFunction(node)
		elseif node.kind == "analyzer_function" then
			self:EmitInvalidLuaCode("EmitAnalyzerFunction", node)
		elseif node.kind == "table" then
			self:EmitTable(node)
		elseif node.kind == "prefix_operator" then
			self:EmitPrefixOperator(node)
		elseif node.kind == "postfix_operator" then
			self:EmitPostfixOperator(node)
		elseif node.kind == "postfix_call" then
			if node.expressions_typesystem then
				self:EmitCall(node)
			elseif node.type_call then
				self:EmitInvalidLuaCode("EmitCall", node)
			else
				self:EmitCall(node)
			end
		elseif node.kind == "postfix_expression_index" then
			self:EmitExpressionIndex(node)
		elseif node.kind == "value" then
			if node.tokens["is"] then
				self:EmitToken(node.value, tostring(node.result_is))
			else
				if node.value.type == "string" then
					self:EmitStringToken(node.value)
				elseif node.value.type == "number" then
					self:EmitNumberToken(node.value)
				else
					self:EmitToken(node.value)
				end
			end
		elseif node.kind == "import" then
			self:EmitImportExpression(node)
		elseif node.kind == "require" then
			self:EmitRequireExpression(node)
		elseif node.kind == "type_table" then
			self:EmitTableType(node)
		elseif node.kind == "table_expression_value" then
			self:EmitTableExpressionValue(node)
		elseif node.kind == "table_key_value" then
			self:EmitTableKeyValue(node)
		elseif node.kind == "empty_union" then
			self:EmitEmptyUnion(node)
		elseif node.kind == "tuple" then
			self:EmitTuple(node)
		elseif node.kind == "type_function" then
			self:EmitInvalidLuaCode("EmitTypeFunction", node)
		elseif node.kind == "function_signature" then
			self:EmitInvalidLuaCode("EmitFunctionSignature", node)
		elseif node.kind == "vararg" then
			self:EmitVararg(node)
		else
			error("unhandled token type " .. node.kind)
		end

		if node.tokens[")"] and newlines then
			self:Outdent()
			self:Whitespace("\n")
			self:Whitespace("\t")
		end

		if not node.tokens[")"] then
			if self.config.annotate and node.tokens[":"] then
				self:EmitInvalidLuaCode("EmitColonAnnotationExpression", node)
			end

			if self.config.annotate and node.tokens["as"] then
				self:EmitInvalidLuaCode("EmitAsAnnotationExpression", node)
			end
		else
			local colon_expression = false
			local as_expression = false

			for _, token in ipairs(node.tokens[")"]) do
				if not colon_expression then
					if self.config.annotate and node.tokens[":"] and node.tokens[":"].stop < token.start then
						self:EmitInvalidLuaCode("EmitColonAnnotationExpression", node)
						colon_expression = true
					end
				end

				if not as_expression then
					if
						self.config.annotate and
						node.tokens["as"] and
						node.tokens["as"].stop < token.start
					then
						self:EmitInvalidLuaCode("EmitAsAnnotationExpression", node)
						as_expression = true
					end
				end

				self:EmitToken(token)
			end

			if not colon_expression then
				if self.config.annotate and node.tokens[":"] then
					self:EmitInvalidLuaCode("EmitColonAnnotationExpression", node)
				end
			end

			if not as_expression then
				if self.config.annotate and node.tokens["as"] then
					self:EmitInvalidLuaCode("EmitAsAnnotationExpression", node)
				end
			end
		end
	end

	function META:EmitVarargTuple(node)
		self:Emit(tostring(node:GetLastType()))
	end

	function META:EmitExpressionIndex(node)
		self:EmitExpression(node.left)
		self:EmitToken(node.tokens["["])
		self:EmitExpression(node.expression)
		self:EmitToken(node.tokens["]"])
	end

	function META:EmitCall(node)
		local multiline_string = false

		if #node.expressions == 1 and node.expressions[1].kind == "value" then
			multiline_string = node.expressions[1].value.value:sub(1, 1) == "["
		end

		if node.expand then
			if not node.expand.expanded then
				self:EmitNonSpace("local ")
				self:EmitExpression(node.left.left)
				self:EmitNonSpace("=")
				self:EmitExpression(node.expand:GetNode())
				node.expand.expanded = true
			end

			self.inside_call_expression = true
			self:EmitExpression(node.left.left)

			if node.tokens["call("] then
				self:EmitToken(node.tokens["call("])
			else
				if self.config.force_parenthesis and not multiline_string then
					self:EmitNonSpace("(")
				end
			end
		else
			-- this will not work for calls with functions that contain statements
			self.inside_call_expression = true
			self:EmitExpression(node.left)

			if node.expressions_typesystem then
				local emitted = self:StartEmittingInvalidLuaCode()
				self:EmitToken(node.tokens["call_typesystem("])
				self:EmitExpressionList(node.expressions_typesystem)
				self:EmitToken(node.tokens["call_typesystem)"])
				self:StopEmittingInvalidLuaCode(emitted)
			end

			if node.tokens["call("] then
				self:EmitToken(node.tokens["call("])
			else
				if self.config.force_parenthesis and not multiline_string then
					self:EmitNonSpace("(")
				end
			end
		end

		local newlines = self:ShouldBreakExpressionList(node.expressions)

		if multiline_string then newlines = false end

		local last = node.expressions[#node.expressions]

		if last and last.kind == "function" and #node.expressions < 4 then
			newlines = false
		end

		if node.tokens["call("] and newlines then
			self:Indent()
			self:Whitespace("\n")
			self:Whitespace("\t")
		end

		self:PushForcedLineBreaking(newlines)
		self:EmitExpressionList(node.expressions)
		self:PopForcedLineBreaking()

		if newlines then self:Outdent() end

		if node.tokens["call)"] then
			if newlines then
				self:Whitespace("\n")
				self:Whitespace("\t")
			end

			self:EmitToken(node.tokens["call)"])
		else
			if self.config.force_parenthesis and not multiline_string then
				if newlines then
					self:Whitespace("\n")
					self:Whitespace("\t")
				end

				self:EmitNonSpace(")")
			end
		end

		self.inside_call_expression = false
	end

	function META:EmitBinaryOperator(node)
		local func_chunks = node.environment == "runtime" and
			runtime_syntax:GetFunctionForBinaryOperator(node.value)

		if func_chunks then
			self:Emit(func_chunks[1])

			if node.left then self:EmitExpression(node.left) end

			self:Emit(func_chunks[2])

			if node.right then self:EmitExpression(node.right) end

			self:Emit(func_chunks[3])
			self.operator_transformed = true
		else
			if node.left then self:EmitExpression(node.left) end

			if node.value.value == "." or node.value.value == ":" then
				self:EmitToken(node.value)
			elseif
				node.value.value == "and" or
				node.value.value == "or" or
				node.value.value == "||" or
				node.value.value == "&&"
			then
				if self:IsLineBreaking() then
					if
						self:GetPrevChar() == B(")") and
						node.left.kind ~= "postfix_call" and
						(
							node.left.kind == "binary_operator" and
							node.left.right.kind ~= "postfix_call"
						)
					then
						self:Whitespace("\n")
						self:Whitespace("\t")
					else
						self:Whitespace(" ")
					end

					self:EmitToken(node.value, translate_binary[node.value.value])

					if node.right then
						self:Whitespace("\n")
						self:Whitespace("\t")
					end
				else
					self:Whitespace(" ")
					self:EmitToken(node.value, translate_binary[node.value.value])
					self:Whitespace(" ")
				end
			else
				self:Whitespace(" ")
				self:EmitToken(node.value, translate_binary[node.value.value])
				self:Whitespace(" ")
			end

			if node.right then self:EmitExpression(node.right) end
		end
	end

	do
		function META:EmitFunctionBody(node)
			if node.identifiers_typesystem then
				local emitted = self:StartEmittingInvalidLuaCode()
				self:EmitToken(node.tokens["arguments_typesystem("])
				self:EmitExpressionList(node.identifiers_typesystem)
				self:EmitToken(node.tokens["arguments_typesystem)"])
				self:StopEmittingInvalidLuaCode(emitted)
			end

			self:EmitToken(node.tokens["arguments("])
			self:EmitLineBreakableList(node.identifiers, self.EmitIdentifierList)
			self:EmitToken(node.tokens["arguments)"])
			self:EmitFunctionReturnAnnotation(node)

			if #node.statements == 0 then
				self:Whitespace(" ")
			else
				self:Whitespace("\n")
				self:EmitBlock(node.statements)
				self:Whitespace("\n")
				self:Whitespace("\t")
			end

			self:EmitToken(node.tokens["end"])
		end

		function META:EmitAnonymousFunction(node)
			self:EmitToken(node.tokens["function"])
			local distance = (node.tokens["end"].start - node.tokens["arguments)"].start)
			self:EmitFunctionBody(node)
		end

		function META:EmitLocalFunction(node)
			self:EmitToken(node.tokens["local"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["identifier"])
			self:EmitFunctionBody(node)
		end

		function META:EmitLocalAnalyzerFunction(node)
			self:EmitToken(node.tokens["local"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["analyzer"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["identifier"])
			self:EmitFunctionBody(node)
		end

		function META:EmitLocalTypeFunction(node)
			self:EmitToken(node.tokens["local"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["identifier"])
			self:EmitFunctionBody(node, true)
		end

		function META:EmitTypeFunction(node)
			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")

			if node.expression or node.identifier then
				self:EmitExpression(node.expression or node.identifier)
			end

			self:EmitFunctionBody(node)
		end

		function META:EmitFunction(node)
			if node.tokens["local"] then
				self:EmitToken(node.tokens["local"])
				self:Whitespace(" ")
			end

			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")
			self:EmitExpression(node.expression or node.identifier)
			self:EmitFunctionBody(node)
		end

		function META:EmitAnalyzerFunctionStatement(node)
			if node.tokens["local"] then
				self:EmitToken(node.tokens["local"])
				self:Whitespace(" ")
			end

			if node.tokens["analyzer"] then
				self:EmitToken(node.tokens["analyzer"])
				self:Whitespace(" ")
			end

			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")

			if node.tokens["^"] then self:EmitToken(node.tokens["^"]) end

			if node.expression or node.identifier then
				self:EmitExpression(node.expression or node.identifier)
			end

			self:EmitFunctionBody(node)
		end
	end

	function META:EmitTableExpressionValue(node)
		self:EmitToken(node.tokens["["])
		self:EmitExpression(node.key_expression)
		self:EmitToken(node.tokens["]"])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["="])
		self:Whitespace(" ")
		self:EmitExpression(node.value_expression)
	end

	function META:EmitTableKeyValue(node)
		self:EmitToken(node.tokens["identifier"])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["="])
		self:Whitespace(" ")
		local break_binary = node.value_expression.kind == "binary_operator" and
			self:ShouldLineBreakNode(node.value_expression)

		if break_binary then self:Indent() end

		self:PushForcedLineBreaking(break_binary)
		self:EmitExpression(node.value_expression)
		self:PopForcedLineBreaking()

		if break_binary then self:Outdent() end
	end

	function META:EmitEmptyUnion(node)
		self:EmitToken(node.tokens["|"])
	end

	function META:EmitTuple(node)
		self:EmitToken(node.tokens["("])
		self:EmitExpressionList(node.expressions)

		if #node.expressions == 1 then
			if node.expressions[1].tokens[","] then
				self:EmitToken(node.expressions[1].tokens[","])
			end
		end

		self:EmitToken(node.tokens[")"])
	end

	function META:EmitVararg(node)
		self:EmitToken(node.tokens["..."])

		if not self.config.analyzer_function then self:EmitExpression(node.value) end
	end

	function META:EmitTable(tree)
		if tree.spread then self:EmitNonSpace("table.mergetables") end

		local during_spread = false
		self:EmitToken(tree.tokens["{"])
		local newline = self:ShouldLineBreakNode(tree)

		if newline then
			self:Whitespace("\n")
			self:Indent()
		end

		if tree.children[1] then
			for i, node in ipairs(tree.children) do
				if newline then self:Whitespace("\t") end

				if node.kind == "table_index_value" then
					if node.spread then
						if during_spread then
							self:EmitNonSpace("},")
							during_spread = false
						end

						self:EmitExpression(node.spread.expression)
					else
						self:EmitExpression(node.value_expression)
					end
				elseif node.kind == "table_key_value" then
					if tree.spread and not during_spread then
						during_spread = true
						self:EmitNonSpace("{")
					end

					self:EmitTableKeyValue(node)
				elseif node.kind == "table_expression_value" then
					self:EmitTableExpressionValue(node)
				end

				if tree.tokens["separators"][i] then
					self:EmitToken(tree.tokens["separators"][i])
				else
					if newline then self:EmitNonSpace(",") end
				end

				if newline then
					self:Whitespace("\n")
				else
					if i ~= #tree.children then self:Whitespace(" ") end
				end
			end
		end

		if during_spread then self:EmitNonSpace("}") end

		if newline then
			self:Outdent()
			self:Whitespace("\t")
		end

		self:EmitToken(tree.tokens["}"])
	end

	function META:EmitPrefixOperator(node)
		local func_chunks = node.environment == "runtime" and
			runtime_syntax:GetFunctionForPrefixOperator(node.value)

		if self.TranslatePrefixOperator then
			func_chunks = self:TranslatePrefixOperator(node) or func_chunks
		end

		if func_chunks then
			self:Emit(func_chunks[1])
			self:EmitExpression(node.right)
			self:Emit(func_chunks[2])
			self.operator_transformed = true
		else
			if
				runtime_syntax:IsKeyword(node.value) or
				runtime_syntax:IsNonStandardKeyword(node.value)
			then
				self:OptionalWhitespace()
				self:EmitToken(node.value, translate_prefix[node.value.value])
				self:OptionalWhitespace()
				self:EmitExpression(node.right)
			else
				self:EmitToken(node.value, translate_prefix[node.value.value])
				self:OptionalWhitespace()
				self:EmitExpression(node.right)
			end
		end
	end

	function META:EmitPostfixOperator(node)
		local func_chunks = node.environment == "runtime" and
			runtime_syntax:GetFunctionForPostfixOperator(node.value)
		-- no such thing as postfix operator in lua,
		-- so we have to assume that there's a translation
		assert(func_chunks)
		self:Emit(func_chunks[1])
		self:EmitExpression(node.left)
		self:Emit(func_chunks[2])
		self.operator_transformed = true
	end

	function META:EmitBlock(statements)
		self:PushForcedLineBreaking(false)
		self:Indent()
		self:EmitStatements(statements)
		self:Outdent()
		self:PopForcedLineBreaking()
	end

	function META:EmitIfStatement(node)
		local short = not self:ShouldLineBreakNode(node)

		for i = 1, #node.statements do
			if node.expressions[i] then
				if not short and i > 1 then
					self:Whitespace("\n")
					self:Whitespace("\t")
				end

				self:EmitToken(node.tokens["if/else/elseif"][i])
				self:EmitLineBreakableExpression(node.expressions[i])
				self:EmitToken(node.tokens["then"][i])
			elseif node.tokens["if/else/elseif"][i] then
				if not short then
					self:Whitespace("\n")
					self:Whitespace("\t")
				end

				self:EmitToken(node.tokens["if/else/elseif"][i])
			end

			if short then self:Whitespace(" ") else self:Whitespace("\n") end

			if #node.statements[i] == 1 and short then
				self:EmitStatement(node.statements[i][1])
			else
				self:EmitBlock(node.statements[i])
			end

			if short then self:Whitespace(" ") end
		end

		if not short then
			self:Whitespace("\n")
			self:Whitespace("\t")
		end

		self:EmitToken(node.tokens["end"])
	end

	function META:EmitGenericForStatement(node)
		self:EmitToken(node.tokens["for"])
		self:Whitespace(" ")
		self:EmitIdentifierList(node.identifiers)
		self:Whitespace(" ")
		self:EmitToken(node.tokens["in"])
		self:Whitespace(" ")
		self:EmitExpressionList(node.expressions)
		self:Whitespace(" ")
		self:EmitToken(node.tokens["do"])
		self:PushLoop(node)
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\n")
		self:Whitespace("\t")
		self:PopLoop()
		self:EmitToken(node.tokens["end"])
	end

	function META:EmitNumericForStatement(node)
		self:EmitToken(node.tokens["for"])
		self:PushLoop(node)
		self:Whitespace(" ")
		self:EmitIdentifierList(node.identifiers)
		self:Whitespace(" ")
		self:EmitToken(node.tokens["="])
		self:Whitespace(" ")
		self:EmitExpressionList(node.expressions)
		self:Whitespace(" ")
		self:EmitToken(node.tokens["do"])
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\n")
		self:Whitespace("\t")
		self:PopLoop()
		self:EmitToken(node.tokens["end"])
	end

	function META:EmitWhileStatement(node)
		self:EmitToken(node.tokens["while"])
		self:EmitLineBreakableExpression(node.expression)
		self:EmitToken(node.tokens["do"])
		self:PushLoop(node)
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\n")
		self:Whitespace("\t")
		self:PopLoop()
		self:EmitToken(node.tokens["end"])
	end

	function META:EmitRepeatStatement(node)
		self:EmitToken(node.tokens["repeat"])
		self:PushLoop(node)
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\t")
		self:PopLoop()
		self:EmitToken(node.tokens["until"])
		self:Whitespace(" ")
		self:EmitExpression(node.expression)
	end

	function META:EmitLabelStatement(node)
		self:EmitToken(node.tokens["::"])
		self:EmitToken(node.tokens["identifier"])
		self:EmitToken(node.tokens["::"])
	end

	function META:EmitGotoStatement(node)
		self:EmitToken(node.tokens["goto"])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["identifier"])
	end

	function META:EmitBreakStatement(node)
		self:EmitToken(node.tokens["break"])
	end

	function META:EmitContinueStatement(node)
		local loop_node = self:GetLoopNode()

		if loop_node then
			self:EmitToken(node.tokens["continue"], "goto __CONTINUE__")
			loop_node.on_pop = function()
				self:EmitNonSpace("::__CONTINUE__::;")
			end
		else
			self:EmitToken(node.tokens["continue"])
		end
	end

	function META:EmitDoStatement(node)
		self:EmitToken(node.tokens["do"])
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\n")
		self:Whitespace("\t")
		self:EmitToken(node.tokens["end"])
	end

	function META:EmitReturnStatement(node)
		self:EmitToken(node.tokens["return"])

		if node.expressions[1] then
			self:Whitespace(" ")
			self:PushForcedLineBreaking(self:ShouldLineBreakNode(node))
			self:EmitExpressionList(node.expressions)
			self:PopForcedLineBreaking()
		end
	end

	function META:EmitSemicolonStatement(node)
		if self.config.no_semicolon then
			self:EmitToken(node.tokens[";"], "")
		else
			self:EmitToken(node.tokens[";"])
		end
	end

	function META:EmitAssignment(node)
		if node.tokens["local"] then
			self:EmitToken(node.tokens["local"])
			self:Whitespace(" ")
		end

		if node.tokens["type"] then
			self:EmitToken(node.tokens["type"])
			self:Whitespace(" ")
		end

		if node.tokens["local"] then
			self:EmitIdentifierList(node.left)
		else
			self:EmitExpressionList(node.left)
		end

		if node.tokens["="] then
			self:Whitespace(" ")
			self:EmitToken(node.tokens["="])
			self:Whitespace(" ")
			self:PushForcedLineBreaking(self:ShouldBreakExpressionList(node.right))
			self:EmitExpressionList(node.right)
			self:PopForcedLineBreaking()
		end
	end

	function META:EmitStatement(node)
		if node.kind == "if" then
			self:EmitIfStatement(node)
		elseif node.kind == "goto" then
			self:EmitGotoStatement(node)
		elseif node.kind == "goto_label" then
			self:EmitLabelStatement(node)
		elseif node.kind == "while" then
			self:EmitWhileStatement(node)
		elseif node.kind == "repeat" then
			self:EmitRepeatStatement(node)
		elseif node.kind == "break" then
			self:EmitBreakStatement(node)
		elseif node.kind == "return" then
			self:EmitReturnStatement(node)
		elseif node.kind == "numeric_for" then
			self:EmitNumericForStatement(node)
		elseif node.kind == "generic_for" then
			self:EmitGenericForStatement(node)
		elseif node.kind == "do" then
			self:EmitDoStatement(node)
		elseif node.kind == "analyzer_function" then
			self:EmitInvalidLuaCode("EmitAnalyzerFunctionStatement", node)
		elseif node.kind == "function" then
			self:EmitFunction(node)
		elseif node.kind == "local_function" then
			self:EmitLocalFunction(node)
		elseif node.kind == "local_analyzer_function" then
			self:EmitInvalidLuaCode("EmitLocalAnalyzerFunction", node)
		elseif node.kind == "local_type_function" then
			if node.identifiers_typesystem then
				self:EmitLocalTypeFunction(node)
			else
				self:EmitInvalidLuaCode("EmitLocalTypeFunction", node)
			end
		elseif node.kind == "type_function" then
			self:EmitInvalidLuaCode("EmitTypeFunction", node)
		elseif
			node.kind == "destructure_assignment" or
			node.kind == "local_destructure_assignment"
		then
			if self.config.use_comment_types or node.environment == "typesystem" then
				self:EmitInvalidLuaCode("EmitDestructureAssignment", node)
			else
				self:EmitTranspiledDestructureAssignment(node)
			end
		elseif node.kind == "assignment" or node.kind == "local_assignment" then
			if node.environment == "typesystem" and self.config.use_comment_types then
				self:EmitInvalidLuaCode("EmitAssignment", node)
			else
				self:EmitAssignment(node)

				if node.kind == "assignment" then self:Emit_ENVFromAssignment(node) end
			end
		elseif node.kind == "import" then
			self:EmitNonSpace("local")
			self:EmitSpace(" ")
			self:EmitIdentifierList(node.left)
			self:EmitSpace(" ")
			self:EmitNonSpace("=")
			self:EmitSpace(" ")
			self:EmitImportExpression(node)
		elseif node.kind == "call_expression" then
			self:EmitExpression(node.value)
		elseif node.kind == "shebang" then
			self:EmitToken(node.tokens["shebang"])
		elseif node.kind == "continue" then
			self:EmitContinueStatement(node)
		elseif node.kind == "semicolon" then
			self:EmitSemicolonStatement(node)

			if self.config.preserve_whitespace == false then
				if self.out[self.i - 2] and self.out[self.i - 2] == "\n" then
					self.out[self.i - 2] = ""
				end
			end
		elseif node.kind == "end_of_file" then
			self:EmitToken(node.tokens["end_of_file"])
		elseif node.kind == "root" then
			self:EmitStatements(node.statements)
		elseif node.kind == "analyzer_debug_code" then
			self:EmitInvalidLuaCode("EmitExpression", node.lua_code)
		elseif node.kind == "parser_debug_code" then
			self:EmitInvalidLuaCode("EmitExpression", node.lua_code)
		elseif node.kind then
			error("unhandled statement: " .. node.kind)
		else
			for k, v in pairs(node) do
				print(k, v)
			end

			error("invalid statement: " .. tostring(node))
		end

		if self.OnEmitStatement then
			if node.kind ~= "end_of_file" then self:OnEmitStatement() end
		end
	end

	local function general_kind(self, node)
		if node.kind == "call_expression" then
			for i, v in ipairs(node.value.expressions) do
				if v.kind == "function" then return "other" end
			end
		end

		if
			node.kind == "call_expression" or
			node.kind == "local_assignment" or
			node.kind == "assignment" or
			node.kind == "return"
		then
			return "expression_statement"
		end

		return "other"
	end

	function META:EmitStatements(tbl)
		for i, node in ipairs(tbl) do
			if i > 1 and general_kind(self, node) == "other" and node.kind ~= "end_of_file" then
				self:Whitespace("\n")
			end

			self:Whitespace("\t")
			self:EmitStatement(node)

			if
				node.kind ~= "semicolon" and
				node.kind ~= "end_of_file" and
				tbl[i + 1] and
				tbl[i + 1].kind ~= "end_of_file"
			then
				self:Whitespace("\n")
			end

			if general_kind(self, node) == "other" then
				if tbl[i + 1] and general_kind(self, tbl[i + 1]) == "expression_statement" then
					self:Whitespace("\n")
				end
			end
		end
	end

	function META:ShouldBreakExpressionList(tbl)
		if self.config.preserve_whitespace == false then
			if #tbl == 0 then return false end

			local first_node = tbl[1]
			local last_node = tbl[#tbl]
			--first_node = first_node:GetStatement()
			--last_node = last_node:GetStatement()
			local start = first_node.code_start
			local stop = last_node.code_stop
			return (stop - start) > self.config.max_line_length
		end

		return false
	end

	function META:EmitNodeList(tbl, func)
		for i = 1, #tbl do
			self:PushForcedLineBreaking(self:ShouldLineBreakNode(tbl[i]))
			local break_binary = self:IsLineBreaking() and tbl[i].kind == "binary_operator"

			if break_binary then self:Indent() end

			func(self, tbl[i])

			if break_binary then self:Outdent() end

			self:PopForcedLineBreaking()

			if i ~= #tbl then
				self:EmitToken(tbl[i].tokens[","])

				if self:IsLineBreaking() then
					self:Whitespace("\n")
					self:Whitespace("\t")
				else
					self:Whitespace(" ")
				end
			end
		end
	end

	function META:HasTypeNotation(node)
		return node.type_expression or node:GetLastType() or node.return_types
	end

	function META:EmitFunctionReturnAnnotationExpression(node, analyzer_function)
		if node.tokens["return:"] then
			self:EmitToken(node.tokens["return:"])
		else
			self:EmitNonSpace(":")
		end

		self:Whitespace(" ")

		if node.return_types then
			for i, exp in ipairs(node.return_types) do
				self:EmitTypeExpression(exp)

				if i ~= #node.return_types then self:EmitToken(exp.tokens[","]) end
			end
		elseif node:GetLastType() and self.config.annotate ~= "explicit" then
			local str = {}
			-- this iterates the first return tuple
			local obj = node:GetLastType():GetContract() or node:GetLastType()

			if obj.Type == "function" then
				for i, v in ipairs(obj:GetReturnTypes():GetData()) do
					str[i] = tostring(v)
				end
			else
				str[1] = tostring(obj)
			end

			if str[1] then self:EmitNonSpace(table.concat(str, ", ")) end
		end
	end

	function META:EmitFunctionReturnAnnotation(node, analyzer_function)
		if not self.config.annotate then return end

		if self:HasTypeNotation(node) and node.tokens["return:"] then
			self:EmitInvalidLuaCode("EmitFunctionReturnAnnotationExpression", node, analyzer_function)
		end
	end

	function META:EmitAnnotationExpression(node)
		if node.type_expression then
			self:EmitTypeExpression(node.type_expression)
		elseif node:GetLastType() and self.config.annotate ~= "explicit" then
			self:Emit(tostring(node:GetLastType():GetContract() or node:GetLastType()))
		end
	end

	function META:EmitAsAnnotationExpression(node)
		self:OptionalWhitespace()
		self:Whitespace(" ")
		self:EmitToken(node.tokens["as"])
		self:Whitespace(" ")
		self:EmitAnnotationExpression(node)
	end

	function META:EmitColonAnnotationExpression(node)
		if node.tokens[":"] then
			self:EmitToken(node.tokens[":"])
		else
			self:EmitNonSpace(":")
		end

		self:Whitespace(" ")
		self:EmitAnnotationExpression(node)
	end

	function META:EmitAnnotation(node)
		if not self.config.annotate then return end

		if self:HasTypeNotation(node) and not node.tokens["as"] then
			self:EmitInvalidLuaCode("EmitColonAnnotationExpression", node)
		end
	end

	function META:EmitIdentifier(node)
		if node.identifier then
			local ok = self:StartEmittingInvalidLuaCode()
			self:EmitToken(node.identifier)
			self:EmitToken(node.tokens[":"])
			self:Whitespace(" ")
			self:EmitTypeExpression(node)
			self:StopEmittingInvalidLuaCode(ok)
			return
		end

		self:EmitExpression(node)
	end

	do -- types
		function META:EmitTypeBinaryOperator(node)
			if node.left then self:EmitTypeExpression(node.left) end

			if node.value.value == "." or node.value.value == ":" then
				self:EmitToken(node.value)
			else
				self:Whitespace(" ")
				self:EmitToken(node.value)
				self:Whitespace(" ")
			end

			if node.right then self:EmitTypeExpression(node.right) end
		end

		function META:EmitType(node)
			self:EmitToken(node.value)
			self:EmitAnnotation(node)
		end

		function META:EmitTableType(node)
			local tree = node
			self:EmitToken(tree.tokens["{"])
			local newline = self:ShouldLineBreakNode(tree)

			if newline then
				self:Indent()
				self:Whitespace("\n")
			end

			if tree.children[1] then
				for i, node in ipairs(tree.children) do
					if newline then self:Whitespace("\t") end

					if node.kind == "table_index_value" then
						self:EmitTypeExpression(node.value_expression)
					elseif node.kind == "table_key_value" then
						self:EmitToken(node.tokens["identifier"])
						self:Whitespace(" ")
						self:EmitToken(node.tokens["="])
						self:Whitespace(" ")
						self:EmitTypeExpression(node.value_expression)
					elseif node.kind == "table_expression_value" then
						self:EmitToken(node.tokens["["])
						self:EmitTypeExpression(node.key_expression)
						self:EmitToken(node.tokens["]"])
						self:Whitespace(" ")
						self:EmitToken(node.tokens["="])
						self:Whitespace(" ")
						self:EmitTypeExpression(node.value_expression)
					end

					if tree.tokens["separators"][i] then
						self:EmitToken(tree.tokens["separators"][i])
					else
						if newline then self:EmitNonSpace(",") end
					end

					if newline then
						self:Whitespace("\n")
					else
						if i ~= #tree.children then self:Whitespace(" ") end
					end
				end
			end

			if newline then
				self:Outdent()
				self:Whitespace("\t")
			end

			self:EmitToken(tree.tokens["}"])
		end

		function META:EmitAnalyzerFunction(node)
			if not self.config.analyzer_function then
				if node.tokens["analyzer"] then
					self:EmitToken(node.tokens["analyzer"])
					self:Whitespace(" ")
				end
			end

			self:EmitToken(node.tokens["function"])

			if not self.config.analyzer_function then
				if node.tokens["^"] then self:EmitToken(node.tokens["^"]) end
			end

			self:EmitToken(node.tokens["arguments("])

			for i, exp in ipairs(node.identifiers) do
				if not self.config.annotate and node.statements then
					if exp.identifier then
						self:EmitToken(exp.identifier)
					else
						self:EmitTypeExpression(exp)
					end
				else
					if exp.identifier then
						self:EmitToken(exp.identifier)
						self:EmitToken(exp.tokens[":"])
						self:Whitespace(" ")
					end

					self:EmitTypeExpression(exp)
				end

				if i ~= #node.identifiers then
					if exp.tokens[","] then
						self:EmitToken(exp.tokens[","])
						self:Whitespace(" ")
					end
				end
			end

			self:EmitToken(node.tokens["arguments)"])

			if node.tokens[":"] and not self.config.analyzer_function then
				self:EmitToken(node.tokens[":"])
				self:Whitespace(" ")

				for i, exp in ipairs(node.return_types) do
					self:EmitTypeExpression(exp)

					if i ~= #node.return_types then
						self:EmitToken(exp.tokens[","])
						self:Whitespace(" ")
					end
				end
			end

			if node.statements then
				self:Whitespace("\n")
				self:EmitBlock(node.statements)
				self:Whitespace("\n")
				self:Whitespace("\t")
				self:EmitToken(node.tokens["end"])
			end
		end

		function META:EmitTypeExpression(node)
			if node.tokens["("] then
				for _, node in ipairs(node.tokens["("]) do
					self:EmitToken(node)
				end
			end

			if node.kind == "binary_operator" then
				self:EmitTypeBinaryOperator(node)
			elseif node.kind == "analyzer_function" then
				self:EmitInvalidLuaCode("EmitAnalyzerFunction", node)
			elseif node.kind == "table" then
				self:EmitTable(node)
			elseif node.kind == "prefix_operator" then
				self:EmitPrefixOperator(node)
			elseif node.kind == "postfix_operator" then
				self:EmitPostfixOperator(node)
			elseif node.kind == "postfix_call" then
				if node.type_call then
					self:EmitInvalidLuaCode("EmitCall", node)
				else
					self:EmitCall(node)
				end
			elseif node.kind == "postfix_expression_index" then
				self:EmitExpressionIndex(node)
			elseif node.kind == "value" then
				self:EmitToken(node.value)
			elseif node.kind == "type_table" then
				self:EmitTableType(node)
			elseif node.kind == "table_expression_value" then
				self:EmitTableExpressionValue(node)
			elseif node.kind == "table_key_value" then
				self:EmitTableKeyValue(node)
			elseif node.kind == "empty_union" then
				self:EmitEmptyUnion(node)
			elseif node.kind == "tuple" then
				self:EmitTuple(node)
			elseif node.kind == "type_function" then
				self:EmitInvalidLuaCode("EmitTypeFunction", node)
			elseif node.kind == "function" then
				self:EmitAnonymousFunction(node)
			elseif node.kind == "function_signature" then
				self:EmitInvalidLuaCode("EmitFunctionSignature", node)
			elseif node.kind == "vararg" then
				self:EmitVararg(node)
			else
				error("unhandled token type " .. node.kind)
			end

			if not self.config.analyzer_function then
				if node.type_expression then
					self:EmitTypeExpression(node.type_expression)
				end
			end

			if node.tokens[")"] then
				for _, node in ipairs(node.tokens[")"]) do
					self:EmitToken(node)
				end
			end
		end

		function META:StartEmittingInvalidLuaCode()
			local emitted = false

			if not self.config.uncomment_types then
				if not self.during_comment_type or self.during_comment_type == 0 then
					self:EmitNonSpace("--[[#")
					emitted = #self.out
				end

				self.during_comment_type = self.during_comment_type or 0
				self.during_comment_type = self.during_comment_type + 1
			end

			return emitted
		end

		function META:StopEmittingInvalidLuaCode(emitted)
			if emitted then
				if self:GetPrevChar() == B("]") then self:Whitespace(" ") end

				local needs_escape = false

				for i = emitted, #self.out do
					local str = self.out[i]

					if str:find("]]", nil, true) then
						self.out[emitted] = "--[=[#"
						needs_escape = true

						break
					end
				end

				if needs_escape then
					self:EmitNonSpace("]=]")
				else
					self:EmitNonSpace("]]")
				end
			end

			if not self.config.uncomment_types then
				self.during_comment_type = self.during_comment_type - 1
			end
		end

		function META:EmitInvalidLuaCode(func, ...)
			local emitted = self:StartEmittingInvalidLuaCode()
			self[func](self, ...)
			self:StopEmittingInvalidLuaCode(emitted)
		end
	end

	do -- extra
		function META:EmitTranspiledDestructureAssignment(node)
			self:EmitToken(node.tokens["{"], "")

			if node.default then
				self:EmitToken(node.default.value)
				self:EmitToken(node.default_comma)
			end

			self:EmitToken(node.tokens["{"], "")
			self:Whitespace(" ")
			self:EmitIdentifierList(node.left)
			self:EmitToken(node.tokens["}"], "")
			self:Whitespace(" ")
			self:EmitToken(node.tokens["="])
			self:Whitespace(" ")
			self:EmitNonSpace("table.destructure(")
			self:EmitExpression(node.right)
			self:EmitNonSpace(",")
			self:EmitSpace(" ")
			self:EmitNonSpace("{")

			for i, v in ipairs(node.left) do
				self:EmitNonSpace("\"")
				self:Emit(v.value.value)
				self:EmitNonSpace("\"")

				if i ~= #node.left then
					self:EmitNonSpace(",")
					self:EmitSpace(" ")
				end
			end

			self:EmitNonSpace("}")

			if node.default then
				self:EmitNonSpace(",")
				self:EmitSpace(" ")
				self:EmitNonSpace("true")
			end

			self:EmitNonSpace(")")
		end

		function META:EmitDestructureAssignment(node)
			if node.tokens["local"] then self:EmitToken(node.tokens["local"]) end

			if node.tokens["type"] then
				self:Whitespace(" ")
				self:EmitToken(node.tokens["type"])
			end

			self:Whitespace(" ")
			self:EmitToken(node.tokens["{"])
			self:Whitespace(" ")
			self:EmitLineBreakableList(node.left, self.EmitIdentifierList)
			self:PopForcedLineBreaking()
			self:Whitespace(" ")
			self:EmitToken(node.tokens["}"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["="])
			self:Whitespace(" ")
			self:EmitExpression(node.right)
		end

		function META:Emit_ENVFromAssignment(node)
			for i, v in ipairs(node.left) do
				if v.kind == "value" and v.value.value == "_ENV" then
					if node.right[i] then
						local key = node.left[i]
						local val = node.right[i]
						self:EmitNonSpace(";setfenv(1, _ENV);")
					end
				end
			end
		end

		function META:EmitImportExpression(node)
			if not node.path then
				self:EmitToken(node.tokens["import"])
				self:EmitToken(node.tokens["arguments("])
				self:EmitExpressionList(node.expressions)
				self:EmitToken(node.tokens["arguments)"])
				return
			end

			self:EmitToken(node.tokens.import, "IMPORTS['" .. node.path .. "']")
			self:EmitToken(node.tokens["arguments("])
			self:EmitExpressionList(node.expressions)
			self:EmitToken(node.tokens["arguments)"])
		end

		function META:EmitRequireExpression(node)
			self:EmitToken(node.tokens["require"])
			self:EmitToken(node.tokens["arguments("])
			self:EmitExpressionList(node.expressions)
			self:EmitToken(node.tokens["arguments)"])
		end
	end

	function META.New(config)
		local self = setmetatable({}, META)
		self.config = config or {}
		self.config.max_argument_length = self.config.max_argument_length or 5
		self.config.max_line_length = self.config.max_line_length or 80
		self:Initialize()
		return self
	end

	return META	
end)("./nattlua/transpiler/emitter.lua");
package.loaded["nattlua.parser.node"] = (function(...)
	--[[#local type { Token } = import("~/nattlua/lexer/token.nlua")]]

	--[[#local type { ExpressionKind, StatementKind } = import("~/nattlua/parser/nodes.nlua")]]

	--[[#import("~/nattlua/code/code.lua")]]
	--[[#local type NodeType = "expression" | "statement"]]
	--[[#local type Node = any]]
	local ipairs = _G.ipairs
	local pairs = _G.pairs
	local setmetatable = _G.setmetatable
	local type = _G.type
	local table = require("table")
	local helpers = require("nattlua.other.helpers")
	local quote_helper = require("nattlua.other.quote")
	local META = {}
	META.__index = META
	META.Type = "node"
	--[[#type META.@Name = "Node"]]
	--[[#type META.@Self = {
		type = "expression" | "statement",
		kind = ExpressionKind | StatementKind,
		id = number,
		Code = Code,
		tokens = Map<|string, Token|>,
		environment = "typesystem" | "runtime",
		parent = nil | self,
		code_start = number,
		code_stop = number,
		first_node = nil | self,
		statements = nil | List<|any|>,
		value = nil | Token,
		inferred_type = nil | any,
		inferred_types = nil | List<|any|>,
	}]]
	--[[#local type Node = META.@Self]]
	local id = 0

	function META.New(init--[[#: Omit<|META.@Self, "id" | "tokens"|>]])--[[#: Node]]
		id = id + 1
		init.tokens = {}
		init.id = id
		return setmetatable(init--[[# as META.@Self]], META)
	end

	function META:__tostring()
		if self.type == "statement" then
			local str = "[" .. self.type .. " - " .. self.kind .. "]"
			local lua_code = self.Code:GetString()
			local name = self.Code:GetName()

			if name:sub(1, 1) == "@" then
				local data = helpers.SubPositionToLinePosition(lua_code, self:GetStartStop())

				if data and data.line_start then
					str = str .. " @ " .. name:sub(2) .. ":" .. data.line_start
				else
					str = str .. " @ " .. name:sub(2) .. ":" .. "?"
				end
			else
				str = str .. " " .. ("%s"):format(self.id)
			end

			return str
		elseif self.type == "expression" then
			local str = "[" .. self.type .. " - " .. self.kind .. " - " .. ("%s"):format(self.id) .. "]"

			if self.value and type(self.value.value) == "string" then
				str = str .. ": " .. quote_helper.QuoteToken(self.value.value)
			end

			return str
		end
	end

	function META:Render(config)
		local em = require("nattlua.transpiler.emitter"--[[# as string]]).New(config or {preserve_whitespace = false, no_newlines = true})

		if self.type == "expression" then
			em:EmitExpression(self)
		else
			em:EmitStatement(self)
		end

		return em:Concat()
	end

	function META:GetStartStop()
		return self.code_start, self.code_stop
	end

	function META:GetStatement()
		if self.type == "statement" then return self end

		if self.parent then return self.parent:GetStatement() end

		return self
	end

	function META:GetRootExpression()
		if self.parent and self.parent.type == "expression" then
			return self.parent:GetRootExpression()
		end

		return self
	end

	function META:GetLength()
		local start, stop = self:GetStartStop()

		if self.first_node then
			local start2, stop2 = self.first_node:GetStartStop()

			if start2 < start then start = start2 end

			if stop2 > stop then stop = stop2 end
		end

		return stop - start
	end

	function META:GetNodes()--[[#: List<|any|>]]
		if self.kind == "if" then
			local flat--[[#: List<|any|>]] = {}

			for _, statements in ipairs(assert(self.statements)) do
				for _, v in ipairs(statements) do
					table.insert(flat, v)
				end
			end

			return flat
		end

		return self.statements or {}
	end

	function META:HasNodes()
		return self.statements ~= nil
	end

	function META:AddType(obj)
		self.inferred_types = self.inferred_types or {}
		table.insert(self.inferred_types, obj)
		self.inferred_type = obj
	end

	function META:GetTypes()
		return self.inferred_types or {}
	end

	function META:GetLastType()
		do
			return self.inferred_type
		end

		return self.inferred_types and self.inferred_types[#self.inferred_types]
	end

	local function find_by_type(
		node--[[#: META.@Self]],
		what--[[#: StatementKind | ExpressionKind]],
		out--[[#: List<|META.@Name|>]]
	)
		out = out or {}

		for _, child in ipairs(node:GetNodes()) do
			if child.kind == what then
				table.insert(out, child)
			elseif child:GetNodes() then
				find_by_type(child, what, out)
			end
		end

		return out
	end

	function META:FindNodesByType(what--[[#: StatementKind | ExpressionKind]])
		return find_by_type(self, what, {})
	end

	return META	
end)("./nattlua/parser/node.lua");
package.loaded["nattlua.parser.base"] = (function(...)
	--[[#local type { Token, TokenType } = import("~/nattlua/lexer/token.nlua")]]

	--[[#local type { 
		ExpressionKind,
		StatementKind,
		FunctionAnalyzerStatement,
		FunctionTypeStatement,
		FunctionAnalyzerExpression,
		FunctionTypeExpression,
		FunctionExpression,
		FunctionLocalStatement,
		FunctionLocalTypeStatement,
		FunctionStatement,
		FunctionLocalAnalyzerStatement,
		ValueExpression
	 } = import("~/nattlua/parser/nodes.nlua")]]

	--[[#import("~/nattlua/code/code.lua")]]
	--[[#local type NodeType = "expression" | "statement"]]
	local Node = require("nattlua.parser.node")
	local ipairs = _G.ipairs
	local pairs = _G.pairs
	local setmetatable = _G.setmetatable
	local type = _G.type
	local table = require("table")
	local helpers = require("nattlua.other.helpers")
	local quote_helper = require("nattlua.other.quote")
	local META = {}
	META.__index = META
	--[[#local type Node = Node.@Self]]
	--[[#type META.@Self = {
		config = any,
		nodes = List<|any|>,
		Code = Code,
		current_statement = false | any,
		current_expression = false | any,
		root = false | any,
		i = number,
		tokens = List<|Token|>,
		environment_stack = List<|"typesystem" | "runtime"|>,
		OnNode = nil | function=(self, any)>(nil),
	}]]
	--[[#type META.@Name = "Parser"]]
	--[[#local type Parser = META.@Self]]

	function META.New(
		tokens--[[#: List<|Token|>]],
		code--[[#: Code]],
		config--[[#: nil | {
			root = nil | Node,
			on_statement = nil | function=(Parser, Node)>(Node),
			path = nil | string,
		}]]
	)
		return setmetatable(
			{
				config = config or {},
				Code = code,
				nodes = {},
				current_statement = false,
				current_expression = false,
				environment_stack = {},
				root = false,
				i = 1,
				tokens = tokens,
			},
			META
		)
	end

	do
		function META:GetCurrentParserEnvironment()
			return self.environment_stack[1] or "runtime"
		end

		function META:PushParserEnvironment(env--[[#: "runtime" | "typesystem"]])
			table.insert(self.environment_stack, 1, env)
		end

		function META:PopParserEnvironment()
			table.remove(self.environment_stack, 1)
		end
	end

	function META:StartNode(
		type--[[#: "statement" | "expression"]],
		kind--[[#: StatementKind | ExpressionKind]]
	)
		local code_start = assert(self:GetToken()).start
		local node = Node.New(
			{
				type = type,
				kind = kind,
				Code = self.Code,
				code_start = code_start,
				code_stop = code_start,
				environment = self:GetCurrentParserEnvironment(),
				parent = self.nodes[1],
			}
		)

		if type == "expression" then
			self.current_expression = node
		else
			self.current_statement = node
		end

		if self.OnNode then self:OnNode(node) end

		table.insert(self.nodes, 1, node)
		return node
	end

	function META:EndNode(node--[[#: Node]])
		local prev = self:GetToken(-1)

		if prev then
			node.code_stop = prev.stop
		else
			local cur = self:GetToken()

			if cur then node.code_stop = cur.stop end
		end

		table.remove(self.nodes, 1)
		return self
	end

	function META:Error(
		msg--[[#: string]],
		start_token--[[#: Token | nil]],
		stop_token--[[#: Token | nil]],
		...--[[#: ...any]]
	)
		local tk = self:GetToken()
		local start = 0
		local stop = 0

		if start_token then
			start = start_token.start
		elseif tk then
			start = tk.start
		end

		if stop_token then stop = stop_token.stop elseif tk then stop = tk.stop end

		self:OnError(self.Code, msg, start, stop, ...)
	end

	function META:OnError(
		code--[[#: Code]],
		message--[[#: string]],
		start--[[#: number]],
		stop--[[#: number]],
		...--[[#: ...any]]
	) end

	function META:GetToken(offset--[[#: number | nil]])
		return self.tokens[self.i + (offset or 0)]
	end

	function META:GetLength()
		return #self.tokens
	end

	function META:Advance(offset--[[#: number]])
		self.i = self.i + offset
	end

	function META:IsValue(str--[[#: string]], offset--[[#: number | nil]])
		local tk = self:GetToken(offset)

		if tk then return tk.value == str end
	end

	function META:IsType(token_type--[[#: TokenType]], offset--[[#: number | nil]])
		local tk = self:GetToken(offset)

		if tk then return tk.type == token_type end
	end

	function META:ReadToken()
		local tk = self:GetToken()

		if not tk then return nil end

		self:Advance(1)
		tk.parent = self.nodes[1]
		return tk
	end

	function META:RemoveToken(i)
		local t = self.tokens[i]
		table.remove(self.tokens, i)
		return t
	end

	function META:AddTokens(tokens--[[#: {[1 .. inf] = Token}]])
		local eof = table.remove(self.tokens)

		for i, token in ipairs(tokens) do
			if token.type == "end_of_file" then break end

			table.insert(self.tokens, self.i + i - 1, token)
		end

		table.insert(self.tokens, eof)
	end

	do
		local function error_expect(
			self--[[#: META.@Self]],
			str--[[#: string]],
			what--[[#: string]],
			start--[[#: Token | nil]],
			stop--[[#: Token | nil]]
		)
			local tk = self:GetToken()

			if not tk then
				self:Error("expected $1 $2: reached end of code", start, stop, what, str)
			else
				self:Error("expected $1 $2: got $3", start, stop, what, str, tk[what])
			end
		end

		function META:ExpectValue(str--[[#: string]], error_start--[[#: Token | nil]], error_stop--[[#: Token | nil]])--[[#: Token]]
			if not self:IsValue(str) then
				error_expect(self, str, "value", error_start, error_stop)
			end

			return self:ReadToken()--[[# as Token]]
		end

		function META:ExpectType(
			str--[[#: TokenType]],
			error_start--[[#: Token | nil]],
			error_stop--[[#: Token | nil]]
		)--[[#: Token]]
			if not self:IsType(str) then
				error_expect(self, str, "type", error_start, error_stop)
			end

			return self:ReadToken()--[[# as Token]]
		end
	end

	function META:ReadValues(
		values--[[#: Map<|string, true|>]],
		start--[[#: Token | nil]],
		stop--[[#: Token | nil]]
	)
		local tk = self:GetToken()

		if not tk then
			self:Error("expected $1: reached end of code", start, stop, values)
			return
		end

		if not values[tk.value] then
			local array = {}

			for k in pairs(values) do
				table.insert(array, k)
			end

			self:Error("expected $1 got $2", start, stop, array, tk.type)
		end

		return self:ReadToken()
	end

	function META:ReadNodes(stop_token--[[#: {[string] = true} | nil]])
		local out = {}
		local i = 1

		for _ = 1, self:GetLength() do
			local tk = self:GetToken()

			if not tk then break end

			if stop_token and stop_token[tk.value] then break end

			local node = self:ReadNode()

			if not node then break end

			if node[1] then
				for _, v in ipairs(node) do
					out[i] = v
					i = i + 1
				end
			else
				out[i] = node
				i = i + 1
			end

			if self.config and self.config.on_statement then
				out[i] = self.config.on_statement(self, out[i - 1]) or out[i - 1]
			end
		end

		return out
	end

	function META:ResolvePath(path--[[#: string]])
		return path
	end

	function META:ReadMultipleValues(
		max--[[#: nil | number]],
		reader--[[#: ref function=(Parser, ...: ...any)>(nil | Node)]],
		...--[[#: ref ...any]]
	)
		local out = {}

		for i = 1, max or self:GetLength() do
			local node = reader(self, ...)--[[# as Node | nil]]

			if not node then break end

			out[i] = node

			if not self:IsValue(",") then break end

			node.tokens[","] = self:ExpectValue(",")
		end

		return out
	end

	return META	
end)("./nattlua/parser/base.lua");
package.loaded["nattlua.syntax.typesystem"] = (function(...)
	local Syntax = require("nattlua.syntax.syntax")
	local typesystem = Syntax()
	typesystem:AddSymbolCharacters(
		{
			",",
			";",
			"(",
			")",
			"{",
			"}",
			"[",
			"]",
			"=",
			"::",
			"\"",
			"'",
			"<|",
			"|>",
		}
	)
	typesystem:AddNumberAnnotations({
		"ull",
		"ll",
		"ul",
		"i",
	})
	typesystem:AddKeywords(
		{
			"do",
			"end",
			"if",
			"then",
			"else",
			"elseif",
			"for",
			"in",
			"while",
			"repeat",
			"until",
			"break",
			"return",
			"local",
			"function",
			"and",
			"not",
			"or",
			-- these are just to make sure all code is covered by tests
			"ÆØÅ",
			"ÆØÅÆ",
		}
	)
	-- these are keywords, but can be used as names
	typesystem:AddNonStandardKeywords({
		"continue",
		"import",
		"literal",
		"ref",
		"mutable",
	})
	typesystem:AddKeywordValues({
		"...",
		"nil",
		"true",
		"false",
	})
	typesystem:AddPrefixOperators({"-", "#", "not", "!", "~", "supertype"})
	typesystem:AddPostfixOperators(
		{
			-- these are just to make sure all code is covered by tests
			"++",
			"ÆØÅ",
			"ÆØÅÆ",
		}
	)
	typesystem:AddBinaryOperators(
		{
			{"or", "||"},
			{"and", "&&"},
			{"<", ">", "<=", ">=", "~=", "==", "!="},
			{"|"},
			{"~"},
			{"&"},
			{"<<", ">>"},
			{"R.."}, -- right associative
			{"+", "-"},
			{"*", "/", "/idiv/", "%"},
			{"R^"}, -- right associative
		}
	)
	typesystem:AddPrimaryBinaryOperators({
		".",
		":",
	})
	typesystem:AddBinaryOperatorFunctionTranslate(
		{
			[">>"] = "bit.rshift(A, B)",
			["<<"] = "bit.lshift(A, B)",
			["|"] = "bit.bor(A, B)",
			["&"] = "bit.band(A, B)",
			["//"] = "math.floor(A / B)",
			["~"] = "bit.bxor(A, B)",
		}
	)
	typesystem:AddPrefixOperatorFunctionTranslate({
		["~"] = "bit.bnot(A)",
	})
	typesystem:AddPostfixOperatorFunctionTranslate({
		["++"] = "(A+1)",
		["ÆØÅ"] = "(A)",
		["ÆØÅÆ"] = "(A)",
	})
	typesystem:AddPrefixOperators(
		{
			"-",
			"#",
			"not",
			"~",
			"typeof",
			"$",
			"unique",
			"mutable",
			"ref",
			"literal",
			"supertype",
			"expand",
		}
	)
	typesystem:AddPrimaryBinaryOperators({"."})
	typesystem:AddBinaryOperators(
		{
			{"or"},
			{"and"},
			{"extends"},
			{"subsetof"},
			{"supersetof"},
			{"<", ">", "<=", ">=", "~=", "=="},
			{"|"},
			{"~"},
			{"&"},
			{"<<", ">>"},
			{"R.."}, -- right associative
			{"+", "-"},
			{"*", "/", "/idiv/", "%"},
			{"R^"}, -- right associative
		}
	)
	return typesystem	
end)("./nattlua/syntax/typesystem.lua");
package.loaded["nattlua.parser.parser"] = (function(...)
	local META = require("nattlua.parser.base")
	local runtime_syntax = require("nattlua.syntax.runtime")
	local typesystem_syntax = require("nattlua.syntax.typesystem")
	local math = require("math")
	local math_huge = math.huge
	local table_insert = require("table").insert
	local table_remove = require("table").remove
	local ipairs = _G.ipairs

	function META:ReadIdentifier(expect_type--[[#: nil | boolean]])
		if not self:IsType("letter") and not self:IsValue("...") then return end

		local node = self:StartNode("expression", "value") -- as ValueExpression ]]
		if self:IsValue("...") then
			node.value = self:ExpectValue("...")
		else
			node.value = self:ExpectType("letter")

			if self:IsValue("<") then
				node.tokens["<"] = self:ExpectValue("<")
				node.attribute = self:ExpectType("letter")
				node.tokens[">"] = self:ExpectValue(">")
			end
		end

		if expect_type ~= false then
			if self:IsValue(":") or expect_type then
				node.tokens[":"] = self:ExpectValue(":")
				node.type_expression = self:ExpectTypeExpression(0)
			end
		end

		self:EndNode(node)
		return node
	end

	function META:ReadValueExpressionToken(expect_value--[[#: nil | string]])
		local node = self:StartNode("expression", "value")
		node.value = expect_value and self:ExpectValue(expect_value) or self:ReadToken()
		self:EndNode(node)
		return node
	end

	function META:ReadValueExpressionType(expect_value--[[#: TokenType]])
		local node = self:StartNode("expression", "value")
		node.value = self:ExpectType(expect_value)
		self:EndNode(node)
		return node
	end

	function META:ReadFunctionBody(
		node--[[#: FunctionAnalyzerExpression | FunctionExpression | FunctionLocalStatement | FunctionStatement]]
	)
		if self.TealCompat then
			if self:IsValue("<") then
				node.tokens["arguments_typesystem("] = self:ExpectValue("<")
				node.identifiers_typesystem = self:ReadMultipleValues(nil, self.ReadIdentifier)
				node.tokens["arguments_typesystem)"] = self:ExpectValue(">")
			end
		end

		node.tokens["arguments("] = self:ExpectValue("(")
		node.identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier)
		node.tokens["arguments)"] = self:ExpectValue(")", node.tokens["arguments("])

		if self:IsValue(":") then
			node.tokens["return:"] = self:ExpectValue(":")
			self:PushParserEnvironment("typesystem")
			node.return_types = self:ReadMultipleValues(nil, self.ReadTypeExpression, 0)
			self:PopParserEnvironment("typesystem")
		end

		node.statements = self:ReadNodes({["end"] = true})
		node.tokens["end"] = self:ExpectValue("end", node.tokens["function"])
		return node
	end

	function META:ReadTypeFunctionBody(
		node--[[#: FunctionTypeStatement | FunctionTypeExpression | FunctionLocalTypeStatement]]
	)
		if self:IsValue("!") then
			node.tokens["!"] = self:ExpectValue("!")
			node.tokens["arguments("] = self:ExpectValue("(")
			node.identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier, true)

			if self:IsValue("...") then
				table_insert(node.identifiers, self:ReadValueExpressionToken("..."))
			end

			node.tokens["arguments)"] = self:ExpectValue(")")
		else
			node.tokens["arguments("] = self:ExpectValue("<|")
			node.identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier, true)

			if self:IsValue("...") then
				table_insert(node.identifiers, self:ReadValueExpressionToken("..."))
			end

			node.tokens["arguments)"] = self:ExpectValue("|>", node.tokens["arguments("])

			if self:IsValue("(") then
				local lparen = self:ExpectValue("(")
				local identifiers = self:ReadMultipleValues(nil, self.ReadIdentifier, true)
				local rparen = self:ExpectValue(")")
				node.identifiers_typesystem = node.identifiers
				node.identifiers = identifiers
				node.tokens["arguments_typesystem("] = node.tokens["arguments("]
				node.tokens["arguments_typesystem)"] = node.tokens["arguments)"]
				node.tokens["arguments("] = lparen
				node.tokens["arguments)"] = rparen
			end
		end

		if self:IsValue(":") then
			node.tokens["return:"] = self:ExpectValue(":")
			self:PushParserEnvironment("typesystem")
			node.return_types = self:ReadMultipleValues(math.huge, self.ExpectTypeExpression, 0)
			self:PopParserEnvironment("typesystem")
		end

		node.environment = "typesystem"
		self:PushParserEnvironment("typesystem")
		local start = self:GetToken()
		node.statements = self:ReadNodes({["end"] = true})
		node.tokens["end"] = self:ExpectValue("end", start, start)
		self:PopParserEnvironment()
		return node
	end

	function META:ReadTypeFunctionArgument(expect_type--[[#: nil | boolean]])
		if self:IsValue(")") then return end

		if self:IsValue("...") then return end

		if expect_type or self:IsType("letter") and self:IsValue(":", 1) then
			local identifier = self:ReadToken()
			local token = self:ExpectValue(":")
			local exp = self:ExpectTypeExpression(0)
			exp.tokens[":"] = token
			exp.identifier = identifier
			return exp
		end

		return self:ExpectTypeExpression(0)
	end

	function META:ReadAnalyzerFunctionBody(
		node--[[#: FunctionAnalyzerStatement | FunctionAnalyzerExpression | FunctionLocalAnalyzerStatement]],
		type_args--[[#: boolean]]
	)
		node.tokens["arguments("] = self:ExpectValue("(")
		node.identifiers = self:ReadMultipleValues(math_huge, self.ReadTypeFunctionArgument, type_args)

		if self:IsValue("...") then
			local vararg = self:StartNode("expression", "value")
			vararg.value = self:ExpectValue("...")

			if self:IsValue(":") or type_args then
				vararg.tokens[":"] = self:ExpectValue(":")
				vararg.type_expression = self:ExpectTypeExpression(0)
			else
				if self:IsType("letter") then
					vararg.type_expression = self:ExpectTypeExpression(0)
				end
			end

			self:EndNode(vararg)
			table_insert(node.identifiers, vararg)
		end

		node.tokens["arguments)"] = self:ExpectValue(")", node.tokens["arguments("])

		if self:IsValue(":") then
			node.tokens["return:"] = self:ExpectValue(":")
			self:PushParserEnvironment("typesystem")
			node.return_types = self:ReadMultipleValues(math.huge, self.ReadTypeExpression, 0)
			self:PopParserEnvironment("typesystem")
			local start = self:GetToken()
			node.statements = self:ReadNodes({["end"] = true})
			node.tokens["end"] = self:ExpectValue("end", start, start)
		elseif not self:IsValue(",") then
			local start = self:GetToken()
			node.statements = self:ReadNodes({["end"] = true})
			node.tokens["end"] = self:ExpectValue("end", start, start)
		end

		return node
	end

	assert(loadfile("nattlua/parser/expressions.lua"))(META)
	assert(loadfile("nattlua/parser/statements.lua"))(META)
	assert(loadfile("nattlua/parser/teal.lua"))(META)

	function META:ReadRootNode()
		local node = self:StartNode("statement", "root")
		self.root = self.config and self.config.root or node
		local shebang

		if self:IsType("shebang") then
			shebang = self:StartNode("statement", "shebang")
			shebang.tokens["shebang"] = self:ExpectType("shebang")
			self:EndNode(shebang)
			node.tokens["shebang"] = shebang.tokens["shebang"]
		end

		node.statements = self:ReadNodes()

		if shebang then table.insert(node.statements, 1, shebang) end

		if self:IsType("end_of_file") then
			local eof = self:StartNode("statement", "end_of_file")
			eof.tokens["end_of_file"] = self.tokens[#self.tokens]
			self:EndNode(node)
			table.insert(node.statements, eof)
			node.tokens["eof"] = eof.tokens["end_of_file"]
		end

		self:EndNode(node)
		return node
	end

	function META:ReadNode()
		if self:IsType("end_of_file") then return end

		return self:ReadDebugCodeStatement() or
			self:ReadReturnStatement() or
			self:ReadBreakStatement() or
			self:ReadContinueStatement() or
			self:ReadSemicolonStatement() or
			self:ReadGotoStatement() or
			self:ReadGotoLabelStatement() or
			self:ReadRepeatStatement() or
			self:ReadAnalyzerFunctionStatement() or
			self:ReadFunctionStatement() or
			self:ReadLocalTypeFunctionStatement() or
			self:ReadLocalFunctionStatement() or
			self:ReadLocalAnalyzerFunctionStatement() or
			self:ReadLocalTypeAssignmentStatement() or
			self:ReadLocalDestructureAssignmentStatement() or
			self.TealCompat and
			self:ReadLocalTealRecord()
			or
			self.TealCompat and
			self:ReadLocalTealEnumStatement()
			or
			self:ReadLocalAssignmentStatement() or
			self:ReadTypeAssignmentStatement() or
			self:ReadDoStatement() or
			self:ReadIfStatement() or
			self:ReadWhileStatement() or
			self:ReadNumericForStatement() or
			self:ReadGenericForStatement() or
			self:ReadDestructureAssignmentStatement() or
			self:ReadCallOrAssignmentStatement()
	end

	return META.New	
end)("./nattlua/parser/parser.lua");
package.loaded["nattlua.types.types"] = (function(...)
	local types = {}

	function types.Initialize()
		types.Table = require("nattlua.types.table").Table
		types.Union = require("nattlua.types.union").Union
		types.Nilable = require("nattlua.types.union").Nilable
		types.Tuple = require("nattlua.types.tuple").Tuple
		types.VarArg = require("nattlua.types.tuple").VarArg
		types.Number = require("nattlua.types.number").Number
		types.LNumber = require("nattlua.types.number").LNumber
		types.Function = require("nattlua.types.function").Function
		types.AnyFunction = require("nattlua.types.function").AnyFunction
		types.LuaTypeFunction = require("nattlua.types.function").LuaTypeFunction
		types.String = require("nattlua.types.string").String
		types.LString = require("nattlua.types.string").LString
		types.Any = require("nattlua.types.any").Any
		types.Symbol = require("nattlua.types.symbol").Symbol
		types.Nil = require("nattlua.types.symbol").Nil
		types.True = require("nattlua.types.symbol").True
		types.False = require("nattlua.types.symbol").False
		types.Boolean = require("nattlua.types.symbol").Boolean
	end

	return types	
end)("./nattlua/types/types.lua");
package.loaded["nattlua.analyzer.base.lexical_scope"] = (function(...)
	local ipairs = ipairs
	local pairs = pairs
	local error = error
	local tostring = tostring
	local assert = assert
	local setmetatable = setmetatable
	local Union = require("nattlua.types.union").Union
	local table_insert = table.insert
	local table = require("table")
	local type = _G.type
	local upvalue_meta

	do
		local META = {}
		META.__index = META
		META.Type = "upvalue"

		function META:__tostring()
			return "[" .. self.key .. ":" .. tostring(self.value) .. "]"
		end

		function META:GetValue()
			return self.value
		end

		function META:GetKey()
			return self.key
		end

		function META:SetValue(value)
			self.value = value
			value:SetUpvalue(self)
		end

		function META:SetImmutable(b)
			self.immutable = b
		end

		function META:IsImmutable()
			return self.immutable
		end

		upvalue_meta = META
	end

	local function Upvalue(obj)
		local self = setmetatable({}, upvalue_meta)
		self:SetValue(obj)
		return self
	end

	local META = {}
	META.__index = META
	local LexicalScope

	function META.GetSet(tbl--[[#: ref any]], name--[[#: ref string]], default--[[#: ref any]])
		tbl[name] = default--[[# as NonLiteral<|default|>]]
		--[[#type tbl.@Self[name] = tbl[name] ]]
		tbl["Set" .. name] = function(self--[[#: tbl.@Self]], val--[[#: tbl[name] ]])
			self[name] = val
			return self
		end
		tbl["Get" .. name] = function(self--[[#: tbl.@Self]])--[[#: tbl[name] ]]
			return self[name]
		end
	end

	function META.IsSet(tbl--[[#: ref any]], name--[[#: ref string]], default--[[#: ref any]])
		tbl[name] = default--[[# as NonLiteral<|default|>]]
		--[[#type tbl.@Self[name] = tbl[name] ]]
		tbl["Set" .. name] = function(self--[[#: tbl.@Self]], val--[[#: tbl[name] ]])
			self[name] = val
			return self
		end
		tbl["Is" .. name] = function(self--[[#: tbl.@Self]])--[[#: tbl[name] ]]
			return self[name]
		end
	end

	do
		function META:IsUncertain()
			return self:IsTruthy() and self:IsFalsy()
		end

		function META:IsCertain()
			return not self:IsUncertain()
		end

		function META:IsCertainlyFalse()
			return self:IsFalsy() and not self:IsTruthy()
		end

		function META:IsCertainlyTrue()
			return self:IsTruthy() and not self:IsFalsy()
		end

		META:IsSet("Falsy", false--[[# as boolean]])
		META:IsSet("Truthy", false--[[# as boolean]])
	end

	META:IsSet("ConditionalScope", false--[[# as boolean]])
	META:GetSet("Parent", nil--[[# as boolean]])
	META:GetSet("Children", nil--[[# as boolean]])

	function META:SetParent(parent)
		self.Parent = parent

		if parent then table_insert(parent:GetChildren(), self) end
	end

	function META:GetMemberInParents(what)
		local scope = self

		while true do
			if scope[what] then return scope[what], scope end

			scope = scope:GetParent()

			if not scope then break end
		end

		return nil
	end

	function META:AddTrackedObject(val)
		local scope = self:GetNearestFunctionScope()
		scope.TrackedObjects = scope.TrackedObjects or {}
		table.insert(scope.TrackedObjects, val)
	end

	function META:AddDependency(val)
		self.dependencies = self.dependencies or {}
		self.dependencies[val] = val
	end

	function META:GetDependencies()
		local out = {}

		if self.dependencies then
			for val in pairs(self.dependencies) do
				table.insert(out, val)
			end
		end

		return out
	end

	function META:FindUpvalue(key, env)
		if type(key) == "table" and key.Type == "string" and key:IsLiteral() then
			key = key:GetData()
		end

		local scope = self
		local prev_scope

		for _ = 1, 1000 do
			if not scope then return end

			local upvalue = scope.upvalues[env].map[key]

			if upvalue then
				local upvalue_position = prev_scope and prev_scope.upvalue_position

				if upvalue_position then
					if upvalue.position >= upvalue_position then
						local upvalue = upvalue.shadow

						while upvalue do
							if upvalue.position <= upvalue_position then return upvalue end

							upvalue = upvalue.shadow
						end
					end
				end

				return upvalue, scope
			end

			prev_scope = scope
			scope = scope:GetParent()
		end

		error("this should never happen")
	end

	function META:CreateUpvalue(key, obj, env)
		local shadow

		if key ~= "..." and env == "runtime" then
			shadow = self.upvalues[env].map[key]
		end

		local upvalue = Upvalue(obj)
		upvalue.key = key
		upvalue.shadow = shadow
		upvalue.position = #self.upvalues[env].list
		upvalue.scope = self
		table_insert(self.upvalues[env].list, upvalue)
		self.upvalues[env].map[key] = upvalue
		return upvalue
	end

	function META:GetUpvalues(type--[[#: "runtime" | "typesystem"]])
		return self.upvalues[type].list
	end

	function META:Copy()
		local copy = LexicalScope()

		if self.upvalues.typesystem then
			for _, upvalue in ipairs(self.upvalues.typesystem.list) do
				copy:CreateUpvalue(upvalue.key, upvalue:GetValue(), "typesystem")
			end
		end

		if self.upvalues.runtime then
			for _, upvalue in ipairs(self.upvalues.runtime.list) do
				copy:CreateUpvalue(upvalue.key, upvalue:GetValue(), "runtime")
			end
		end

		copy.returns = self.returns
		copy:SetParent(self:GetParent())
		copy:SetConditionalScope(self:IsConditionalScope())
		return copy
	end

	META:GetSet("TrackedUpvalues")
	META:GetSet("TrackedTables")

	function META:TracksSameAs(scope)
		local upvalues_a, tables_a = self:GetTrackedUpvalues(), self:GetTrackedTables()
		local upvalues_b, tables_b = scope:GetTrackedUpvalues(), scope:GetTrackedTables()

		if not upvalues_a or not upvalues_b then return false end

		if not tables_a or not tables_b then return false end

		for i, data_a in ipairs(upvalues_a) do
			for i, data_b in ipairs(upvalues_b) do
				if data_a.upvalue == data_b.upvalue then return true end
			end
		end

		for i, data_a in ipairs(tables_a) do
			for i, data_b in ipairs(tables_b) do
				if data_a.obj == data_b.obj then return true end
			end
		end

		return false
	end

	function META:FindResponsibleConditionalScopeFromUpvalue(upvalue)
		local scope = self

		while true do
			local upvalues = scope:GetTrackedUpvalues()

			if upvalues then
				for i, data in ipairs(upvalues) do
					if data.upvalue == upvalue then return scope, data end
				end
			end

			-- find in siblings too, if they have returned
			-- ideally when cloning a scope, the new scope should be 
			-- inside of the returned scope, then we wouldn't need this code
			for _, child in ipairs(scope:GetChildren()) do
				if child ~= scope and self:IsPartOfTestStatementAs(child) then
					local upvalues = child:GetTrackedUpvalues()

					if upvalues then
						for i, data in ipairs(upvalues) do
							if data.upvalue == upvalue then return child, data end
						end
					end
				end
			end

			scope = scope:GetParent()

			if not scope then return end
		end

		return nil
	end

	META:GetSet("PreviousConditionalSibling")
	META:GetSet("NextConditionalSibling")
	META:IsSet("ElseConditionalScope")

	function META:SetStatement(statement)
		self.statement = statement
	end

	function META:GetStatementType()
		return self.statement and self.statement.kind
	end

	function META.IsPartOfTestStatementAs(a, b)
		return a:GetStatementType() == "if" and
			b:GetStatementType() == "if" and
			a.statement == b.statement
	end

	function META:FindFirstConditionalScope()
		local obj, scope = self:GetMemberInParents("ConditionalScope")
		return scope
	end

	function META:Contains(scope)
		if scope == self then return true end

		local parent = scope

		for i = 1, 1000 do
			if not parent then break end

			if parent == self then return true end

			parent = parent:GetParent()
		end

		return false
	end

	function META:GetRoot()
		local parent = self

		for i = 1, 1000 do
			if not parent:GetParent() then break end

			parent = parent:GetParent()
		end

		return parent
	end

	do
		function META:MakeFunctionScope(node)
			self.returns = {}
			self.node = node
		end

		function META:IsFunctionScope()
			return self.returns ~= nil
		end

		function META:CollectReturnTypes(node, types)
			table.insert(self:GetNearestFunctionScope().returns, {node = node, types = types})
		end

		function META:DidCertainReturn()
			return self.certain_return ~= nil
		end

		function META:ClearCertainReturn()
			self.certain_return = nil
		end

		function META:CertainReturn()
			local scope = self

			while true do
				scope.certain_return = true

				if scope.returns then break end

				scope = scope:GetParent()

				if not scope then break end
			end
		end

		function META:UncertainReturn()
			self:GetNearestFunctionScope().uncertain_function_return = true
		end

		function META:GetNearestFunctionScope()
			local ok, scope = self:GetMemberInParents("returns")

			if ok then return scope end

			return self
		end

		function META:GetReturnTypes()
			return self.returns
		end

		function META:ClearCertainReturnTypes()
			self.returns = {}
		end

		function META:IsCertainFromScope(from)
			return not self:IsUncertainFromScope(from)
		end

		function META:IsUncertainFromScope(from)
			if from == self then return false end

			local scope = self

			if self:IsPartOfTestStatementAs(from) then return true end

			while true do
				if scope == from then break end

				if scope:IsFunctionScope() then
					if
						scope.node and
						scope.node:GetLastType() and
						scope.node:GetLastType().Type == "function" and
						not scope:Contains(from)
					then
						return not scope.node:GetLastType():IsCalled()
					end
				end

				if scope:IsTruthy() and scope:IsFalsy() then
					if scope:Contains(from) then return false end

					return true, scope
				end

				scope = scope:GetParent()

				if not scope then break end
			end

			return false
		end
	end

	function META:__tostring()
		local x = 1

		do
			local scope = self

			while scope:GetParent() do
				x = x + 1
				scope = scope:GetParent()
			end
		end

		local y = 1

		if self:GetParent() then
			for i, v in ipairs(self:GetParent():GetChildren()) do
				if v == self then
					y = i

					break
				end
			end
		end

		local s = "scope[" .. x .. "," .. y .. "]" .. "[" .. (
				self:IsUncertain() and
				"uncertain" or
				"certain"
			) .. "]"

		if self.node then s = s .. tostring(self.node) end

		return s
	end

	function META:DumpScope()
		local s = {}

		for i, v in ipairs(self.upvalues.runtime.list) do
			table.insert(s, "local " .. tostring(v.key) .. " = " .. tostring(v))
		end

		for i, v in ipairs(self.upvalues.typesystem.list) do
			table.insert(s, "local type " .. tostring(v.key) .. " = " .. tostring(v))
		end

		for i, v in ipairs(self:GetChildren()) do
			table.insert(s, "do\n" .. v:DumpScope() .. "\nend\n")
		end

		return table.concat(s, "\n")
	end

	local ref = 0

	function LexicalScope(parent, upvalue_position)
		ref = ref + 1
		local scope = {
			ref = ref,
			Children = {},
			upvalue_position = upvalue_position,
			upvalues = {
				runtime = {
					list = {},
					map = {},
				},
				typesystem = {
					list = {},
					map = {},
				},
			},
		}
		setmetatable(scope, META)
		scope:SetParent(parent)
		return scope
	end

	return LexicalScope	
end)("./nattlua/analyzer/base/lexical_scope.lua");
package.loaded["nattlua.analyzer.base.scopes"] = (function(...)
	local type = type
	local ipairs = ipairs
	local tostring = tostring
	local LexicalScope = require("nattlua.analyzer.base.lexical_scope")
	local Table = require("nattlua.types.table").Table
	local LString = require("nattlua.types.string").LString
	local table = require("table")
	return function(META)
		table.insert(META.OnInitialize, function(self)
			self.default_environment = {
				runtime = Table(),
				typesystem = Table(),
			}
			self.environments = {runtime = {}, typesystem = {}}
			self.scope_stack = {}
		end)

		function META:Hash(node)
			if node.Type == "string" then return node:GetHash() end

			if type(node) == "string" then return node end

			if type(node.value) == "string" then return node.value end

			return node.value.value
		end

		function META:PushScope(scope)
			table.insert(self.scope_stack, self.scope)
			self.scope = scope
			return scope
		end

		function META:CreateAndPushFunctionScope(scope, upvalue_position)
			return self:PushScope(LexicalScope(scope or self:GetScope(), upvalue_position))
		end

		function META:CreateAndPushModuleScope()
			return self:PushScope(LexicalScope())
		end

		function META:CreateAndPushScope()
			return self:PushScope(LexicalScope(self:GetScope()))
		end

		function META:PopScope()
			local new = table.remove(self.scope_stack)
			local old = self.scope

			if new then self.scope = new end

			return old
		end

		function META:GetScope()
			return self.scope
		end

		function META:GetScopeStack()
			return self.scope_stack
		end

		function META:CloneCurrentScope()
			local scope_copy = self:GetScope():Copy(true)
			local g = self:GetGlobalEnvironment("runtime"):Copy()
			local last_node = self.environment_nodes[#self.environment_nodes]
			self:PopScope()
			self:PopGlobalEnvironment("runtime")
			scope_copy:SetParent(scope_copy:GetParent() or self:GetScope())
			self:PushGlobalEnvironment(last_node, g, "runtime")
			self:PushScope(scope_copy)

			for _, keyval in ipairs(g:GetData()) do
				self:MutateTable(g, keyval.key, keyval.val)
			end

			for _, upvalue in ipairs(scope_copy:GetUpvalues("runtime")) do
				self:MutateUpvalue(upvalue, upvalue:GetValue())
			end

			return scope_copy
		end

		function META:CreateLocalValue(key, obj, const)
			local upvalue = self:GetScope():CreateUpvalue(key, obj, self:GetCurrentAnalyzerEnvironment())
			self:MutateUpvalue(upvalue, obj)
			upvalue:SetImmutable(const)
			return upvalue
		end

		function META:OnCreateLocalValue(upvalue, key, val) end

		function META:FindLocalUpvalue(key, scope)
			scope = scope or self:GetScope()

			if not scope then return end

			local found, scope = scope:FindUpvalue(key, self:GetCurrentAnalyzerEnvironment())

			if found then return found, scope end
		end

		function META:FindLocalValue(key, scope)
			local upvalue, scope = self:FindLocalUpvalue(key, scope)

			if upvalue then
				if self:IsRuntime() then
					return self:GetMutatedUpvalue(upvalue) or upvalue:GetValue()
				end

				return upvalue:GetValue()
			end
		end

		function META:LocalValueExists(key, scope)
			scope = scope or self:GetScope()

			if not scope then return end

			local found = scope:FindUpvalue(key, self:GetCurrentAnalyzerEnvironment())
			return found ~= nil
		end

		function META:SetEnvironmentOverride(node, obj, env)
			node.environments_override = node.environments_override or {}
			node.environments_override[env] = obj
		end

		function META:GetGlobalEnvironmentOverride(node, env)
			if node.environments_override then return node.environments_override[env] end
		end

		function META:SetDefaultEnvironment(obj, env)
			self.default_environment[env] = obj
		end

		function META:GetDefaultEnvironment(env)
			return self.default_environment[env]
		end

		function META:PushGlobalEnvironment(node, obj, env)
			table.insert(self.environments[env], 1, obj)
			node.environments = node.environments or {}
			node.environments[env] = obj
			self.environment_nodes = self.environment_nodes or {}
			table.insert(self.environment_nodes, 1, node)
		end

		function META:PopGlobalEnvironment(env)
			table.remove(self.environment_nodes, 1)
			table.remove(self.environments[env], 1)
		end

		function META:GetGlobalEnvironment(env)
			local g = self.environments[env][1] or self:GetDefaultEnvironment(env)

			if
				self.environment_nodes[1] and
				self.environment_nodes[1].environments_override and
				self.environment_nodes[1].environments_override[env]
			then
				g = self.environment_nodes[1].environments_override[env]
			end

			return g
		end

		function META:FindEnvironmentValue(key)
			-- look up in parent if not found
			if self:IsRuntime() then
				local g = self:GetGlobalEnvironment(self:GetCurrentAnalyzerEnvironment())
				local val, err = g:Get(key)

				if not val then
					self:PushAnalyzerEnvironment("typesystem")
					local val, err = self:GetLocalOrGlobalValue(key)
					self:PopAnalyzerEnvironment()
					return val, err
				end

				return self:IndexOperator(key:GetNode(), g, key)
			end

			return self:IndexOperator(key:GetNode(), self:GetGlobalEnvironment(self:GetCurrentAnalyzerEnvironment()), key)
		end

		function META:GetLocalOrGlobalValue(key, scope)
			local val = self:FindLocalValue(key, scope)

			if val then return val end

			return self:FindEnvironmentValue(key)
		end

		function META:SetLocalOrGlobalValue(key, val, scope)
			local upvalue, found_scope = self:FindLocalUpvalue(key, scope)

			if upvalue then
				if upvalue:IsImmutable() then
					return self:Error(key:GetNode(), {"cannot assign to const variable ", key})
				end

				if not self:MutateUpvalue(upvalue, val) then upvalue:SetValue(val) end

				return upvalue
			end

			local g = self:GetGlobalEnvironment(self:GetCurrentAnalyzerEnvironment())

			if not g then
				self:FatalError("tried to set environment value outside of Push/Pop/Environment")
			end

			if self:IsRuntime() then
				self:Warning(key:GetNode(), {"_G[\"", key:GetNode(), "\"] = ", val})
			end

			self:Assert(key, self:NewIndexOperator(key:GetNode(), g, key, val))
			return val
		end
	end	
end)("./nattlua/analyzer/base/scopes.lua");
package.loaded["nattlua.analyzer.base.error_handling"] = (function(...)
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

		function META:Assert(node, ok, err, ...)
			if ok == false then
				err = err or "assertion failed!"
				self:Error(node, err)
				return Any():SetNode(node)
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

			return table.concat(out)
		end

		function META:ReportDiagnostic(
			node,
			msg--[[#: {reasons = {[number] = string}} | {[number] = string}]],
			severity--[[#: "warning" | "error"]]
		)
			if self.SuppressDiagnostics then return end

			if not node then
				io.write(
					"reporting diagnostic without node, defaulting to current expression or statement\n"
				)
				--			io.write(debug.traceback(), "\n")
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
			local start, stop = node:GetStartStop()

			if self.OnDiagnostic and not self:IsTypeProtectedCall() then
				self:OnDiagnostic(node.Code, msg_str, severity, start, stop)
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
					protected_call = self:IsTypeProtectedCall(),
				}
			)
		end

		function META:PushProtectedCall()
			self.type_protected_call_stack = self.type_protected_call_stack or 0
			self.type_protected_call_stack = self.type_protected_call_stack + 1
		end

		function META:PopProtectedCall()
			self.type_protected_call_stack = self.type_protected_call_stack - 1
		end

		function META:IsTypeProtectedCall()
			return self.type_protected_call_stack and self.type_protected_call_stack > 0
		end

		function META:Error(node, msg)
			return self:ReportDiagnostic(node, msg, "error")
		end

		function META:Warning(node, msg)
			return self:ReportDiagnostic(node, msg, "warning")
		end

		function META:FatalError(msg, node)
			node = node or self.current_expression or self.current_statement

			if node then self:ReportDiagnostic(node, msg, "fatal") end

			error(msg, 2)
		end

		function META:GetDiagnostics()
			return self.diagnostics
		end
	end	
end)("./nattlua/analyzer/base/error_handling.lua");
package.loaded["nattlua.analyzer.base.base_analyzer"] = (function(...)
	local tonumber = tonumber
	local ipairs = ipairs
	local os = os
	local print = print
	local pairs = pairs
	local setmetatable = setmetatable
	local pcall = pcall
	local tostring = tostring
	local debug = debug
	local io = io
	local load = loadstring or load
	local LString = require("nattlua.types.string").LString
	local Tuple = require("nattlua.types.tuple").Tuple
	local Nil = require("nattlua.types.symbol").Nil
	local Any = require("nattlua.types.any").Any
	local context = require("nattlua.analyzer.context")
	local table = require("table")
	local math = require("math")
	return function(META)
		require("nattlua.analyzer.base.scopes")(META)
		require("nattlua.analyzer.base.error_handling")(META)

		function META:AnalyzeRootStatement(statement, ...)
			context:PushCurrentAnalyzer(self)
			local argument_tuple = ... and
				Tuple({...}) or
				Tuple({...}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
			self:CreateAndPushModuleScope()
			self:PushGlobalEnvironment(statement, self:GetDefaultEnvironment("runtime"), "runtime")
			self:PushGlobalEnvironment(statement, self:GetDefaultEnvironment("typesystem"), "typesystem")
			local g = self:GetGlobalEnvironment("typesystem")
			g:Set(LString("_G"), g)
			self:PushAnalyzerEnvironment("runtime")
			self:CreateLocalValue("...", argument_tuple)
			local analyzed_return = self:AnalyzeStatementsAndCollectReturnTypes(statement)
			self:PopAnalyzerEnvironment()
			self:PopGlobalEnvironment("runtime")
			self:PopGlobalEnvironment("typesystem")
			self:PopScope()
			context:PopCurrentAnalyzer()
			return analyzed_return
		end

		function META:AnalyzeExpressions(expressions)
			if not expressions then return end

			local out = {}

			for _, expression in ipairs(expressions) do
				local obj = self:AnalyzeExpression(expression)

				if obj and obj.Type == "tuple" and obj:GetLength() == 1 then
					obj = obj:Get(1)
				end

				table.insert(out, obj)
			end

			return out
		end

		do
			local function add_potential_self(tup)
				local self = tup:Get(1)

				if self and self.Type == "union" then self = self:GetType("table") end

				if self and self.Self then
					local self = self.Self
					local new_tup = Tuple({})

					for i, obj in ipairs(tup:GetData()) do
						if i == 1 then
							new_tup:Set(i, self)
						else
							new_tup:Set(i, obj)
						end
					end

					return new_tup
				elseif self and self.potential_self then
					local meta = self
					local self = self.potential_self:Copy()

					if self.Type == "union" then
						for _, obj in ipairs(self:GetData()) do
							obj:SetMetaTable(meta)
						end
					else
						self:SetMetaTable(meta)
					end

					local new_tup = Tuple({})

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
				-- disregard arguments and use function's arguments in case they have been maniupulated (ie string.gsub)
				arguments = obj:GetArguments():Copy()
				arguments = add_potential_self(arguments)

				for _, obj in ipairs(arguments:GetData()) do
					obj.mutations = nil
				end

				self:CreateAndPushFunctionScope(obj:GetData().scope, obj:GetData().upvalue_position)
				self:Assert(node, self:Call(obj, arguments, node))
				self:PopScope()
			end

			function META:CallMeLater(obj, arguments, node)
				self.deferred_calls = self.deferred_calls or {}
				table.insert(self.deferred_calls, 1, {obj, arguments, node})
			end

			function META:AnalyzeUnreachableCode()
				if not self.deferred_calls then return end

				context:PushCurrentAnalyzer(self)
				local total = #self.deferred_calls
				self.processing_deferred_calls = true
				local called_count = 0

				for _, v in ipairs(self.deferred_calls) do
					if not v[1].called and not v[1].done and v[1].explicit_arguments then
						local time = os.clock()
						call(self, table.unpack(v))
						called_count = called_count + 1
						v[1].done = true
						v[1].called = nil
					end
				end

				for _, v in ipairs(self.deferred_calls) do
					if not v[1].called and not v[1].done and not v[1].explicit_arguments then
						local time = os.clock()
						call(self, table.unpack(v))
						called_count = called_count + 1
						v[1].done = true
						v[1].called = nil
					end
				end

				self.processing_deferred_calls = false
				self.deferred_calls = nil
				context:PopCurrentAnalyzer()
			end
		end

		do
			local helpers = require("nattlua.other.helpers")
			local locals = ""
			locals = locals .. "local nl=require(\"nattlua\");"
			locals = locals .. "local types=require(\"nattlua.types.types\");"
			locals = locals .. "local context=require(\"nattlua.analyzer.context\");"

			for k, v in pairs(_G) do
				locals = locals .. "local " .. tostring(k) .. "=_G." .. k .. ";"
			end

			local runtime_injection = [[
			local analyzer = context:GetCurrentAnalyzer()
			local env = analyzer:GetScopeHelper(analyzer.function_scope)
		]]
			runtime_injection = runtime_injection:gsub("\n", ";")

			function META:CompileLuaAnalyzerDebugCode(code, node)
				local start, stop = code:find("^.-function%b()")

				if start and stop then
					local before_function = code:sub(1, stop)
					local after_function = code:sub(stop + 1, #code)
					code = before_function .. runtime_injection .. after_function
				else
					code = runtime_injection .. code
				end

				code = locals .. code
				-- append newlines so that potential line errors are correct
				local lua_code = node.Code:GetString()

				if lua_code then
					local start, stop = node:GetStartStop()
					local line = helpers.SubPositionToLinePosition(lua_code, start, stop).line_start
					code = ("\n"):rep(line - 1) .. code
				end

				local func, err = load(code, node.name)

				if not func then
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

			function META:CallLuaTypeFunction(node, func, scope, ...)
				self.function_scope = scope
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

					local trace = self:TypeTraceback(1)

					if trace and trace ~= "" then msg = msg .. "\ntraceback:\n" .. trace end

					self:Error(node, msg)
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
					self.analyzer:SetLocalOrGlobalValue(LString(key), LString(val), self.scope)
					self.analyzer:PopAnalyzerEnvironment()
				end

				function META:GetScopeHelper(scope)
					self.scope_helper = {
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
					self.scope_helper.scope = scope
					return self.scope_helper
				end

				function META:CallTypesystemUpvalue(name, ...)
					-- this is very internal-ish code
					-- not sure what a nice interface for this really should be yet
					self:PushAnalyzerEnvironment("typesystem")
					local generics_func = self:GetLocalOrGlobalValue(name)
					assert(generics_func.Type == "function", "cannot find typesystem function " .. name:GetData())
					local argument_tuple = Tuple({...})
					local returned_tuple = assert(self:Call(generics_func, argument_tuple))
					self:PopAnalyzerEnvironment()
					return returned_tuple:Unpack()
				end
			end

			function META:TypeTraceback(from)
				if not self.call_stack then return "" end

				local str = ""

				for i, v in ipairs(self.call_stack) do
					if v.call_node and (not from or i > from) then
						local start, stop = v.call_node:GetStartStop()

						if start and stop then
							local part = helpers.FormatError(self.compiler:GetCode(), "", start, stop, 1)
							str = str .. part .. "#" .. tostring(i) .. ": " .. self.compiler:GetCode():GetName()
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
					s = s .. self:TypeTraceback()
				end)

				return s
			end

			function META:ResolvePath(path)
				return path
			end

			do
				function META:GetCurrentAnalyzerEnvironment()
					return self.environment_stack and self.environment_stack[1] or "runtime"
				end

				function META:PushAnalyzerEnvironment(env--[[#: "typesystem" | "runtime"]])
					self.environment_stack = self.environment_stack or {}
					table.insert(self.environment_stack, 1, env)
				end

				function META:PopAnalyzerEnvironment()
					table.remove(self.environment_stack, 1)
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
					scope = scope or self:GetScope():GetNearestFunctionScope()
					return self.uncertain_loop_stack and
						self.uncertain_loop_stack[1] == scope:GetNearestFunctionScope()
				end

				function META:PushUncertainLoop(b)
					self.uncertain_loop_stack = self.uncertain_loop_stack or {}
					table.insert(self.uncertain_loop_stack, 1, b and self:GetScope():GetNearestFunctionScope())
				end

				function META:PopUncertainLoop()
					table.remove(self.uncertain_loop_stack, 1)
				end
			end

			do
				function META:GetActiveNode()
					return self.active_node_stack and self.active_node_stack[1]
				end

				function META:PushActiveNode(node)
					self.active_node_stack = self.active_node_stack or {}
					table.insert(self.active_node_stack, 1, node)
				end

				function META:PopActiveNode()
					table.remove(self.active_node_stack, 1)
				end
			end

			do
				function META:PushCurrentType(obj, type)
					self.current_type_stack = self.current_type_stack or {}
					self.current_type_stack[type] = self.current_type_stack[type] or {}
					table.insert(self.current_type_stack[type], 1, obj)
				end

				function META:PopCurrentType(type)
					table.remove(self.current_type_stack[type], 1)
				end

				function META:GetCurrentType(type, offset)
					return self.current_type_stack and
						self.current_type_stack[type] and
						self.current_type_stack[type][offset or
						1]
				end
			end
		end
	end	
end)("./nattlua/analyzer/base/base_analyzer.lua");
package.loaded["nattlua.analyzer.control_flow"] = (function(...)
	local ipairs = ipairs
	local type = type
	local LString = require("nattlua.types.string").LString
	local LNumber = require("nattlua.types.number").LNumber
	local Nil = require("nattlua.types.symbol").Nil
	local Tuple = require("nattlua.types.tuple").Tuple
	local Union = require("nattlua.types.union").Union
	-- this turns out to be really hard so I'm trying 
	-- naive approaches while writing tests
	return function(META)
		function META:AnalyzeStatements(statements)
			for _, statement in ipairs(statements) do
				self:AnalyzeStatement(statement)

				if self.break_out_scope or self._continue_ then return end

				if self:GetScope():DidCertainReturn() then
					self:GetScope():ClearCertainReturn()
					return
				end
			end

			if self:GetScope().uncertain_function_return == nil then
				self:GetScope().uncertain_function_return = false
			end

			if statements[1] then
				self:GetScope().missing_return = statements[#statements].kind ~= "return"
			else
				self:GetScope().missing_return = true
			end
		end

		function META:AnalyzeStatementsAndCollectReturnTypes(statement)
			local scope = self:GetScope()
			scope:MakeFunctionScope(statement)
			self:AnalyzeStatements(statement.statements)

			if scope.missing_return and self:IsMaybeReachable() then
				self:Return(statement, {Nil():SetNode(statement)})
			end

			local union = Union({})

			for _, ret in ipairs(scope:GetReturnTypes()) do
				if #ret.types == 1 then
					union:AddType(ret.types[1])
				else
					local tup = Tuple(ret.types)
					tup:SetNode(ret.node)
					union:AddType(tup)
				end
			end

			scope:ClearCertainReturnTypes()

			if #union:GetData() == 1 then return union:GetData()[1] end

			return union
		end

		function META:ThrowSilentError(assert_expression)
			if assert_expression and assert_expression:IsCertainlyTrue() then return end

			for i = #self.call_stack, 1, -1 do
				local frame = self.call_stack[i]
				local function_scope = frame.scope:GetNearestFunctionScope()

				if not assert_expression or assert_expression:IsCertainlyTrue() then
					function_scope.lua_silent_error = function_scope.lua_silent_error or {}
					table.insert(function_scope.lua_silent_error, 1, self:GetScope())
					frame.scope:UncertainReturn()
				end

				if assert_expression and assert_expression:IsTruthy() then
					-- track the assertion expression
					local upvalues

					if frame.scope:GetTrackedUpvalues() then
						upvalues = {}

						for _, a in ipairs(frame.scope:GetTrackedUpvalues()) do
							for _, b in ipairs(self:GetTrackedUpvalues()) do
								if a.upvalue == b.upvalue then table.insert(upvalues, a) end
							end
						end
					end

					local tables

					if frame.scope:GetTrackedTables() then
						tables = {}

						for _, a in ipairs(frame.scope:GetTrackedTables()) do
							for _, b in ipairs(self:GetTrackedTables()) do
								if a.obj == b.obj then table.insert(tables, a) end
							end
						end
					end

					self:ApplyMutationsAfterReturn(frame.scope, frame.scope, true, upvalues, tables)
					return
				end

				self:ApplyMutationsAfterReturn(
					frame.scope,
					function_scope,
					true,
					frame.scope:GetTrackedUpvalues(),
					frame.scope:GetTrackedTables()
				)
			end
		end

		function META:ThrowError(msg, obj, no_report)
			if obj then
				-- track "if x then" which has no binary or prefix operators
				self:TrackUpvalue(obj)
				self.lua_assert_error_thrown = {
					msg = msg,
					obj = obj,
				}

				if obj:IsTruthy() then
					self:GetScope():UncertainReturn()
				else
					self:GetScope():CertainReturn()
				end

				local old = {}

				for i, upvalue in ipairs(self:GetScope().upvalues.runtime.list) do
					old[i] = upvalue
				end

				self:ApplyMutationsAfterReturn(self:GetScope(), nil, false, self:GetTrackedUpvalues(old), self:GetTrackedTables())
			else
				self.lua_error_thrown = msg
			end

			if not no_report then self:Error(self.current_call, msg) end
		end

		function META:GetThrownErrorMessage()
			return self.lua_error_thrown or
				self.lua_assert_error_thrown and
				self.lua_assert_error_thrown.msg
		end

		function META:ClearError()
			self.lua_error_thrown = nil
			self.lua_assert_error_thrown = nil
		end

		function META:Return(node, types)
			local scope = self:GetScope()
			local function_scope = scope:GetNearestFunctionScope()

			if scope == function_scope then
				-- the root scope of the function when being called is definetly certain
				function_scope.uncertain_function_return = false
			elseif scope:IsUncertain() then
				function_scope.uncertain_function_return = true

				-- else always hits, so even if the else part is uncertain
				-- it does mean that this function at least returns something
				if scope:IsElseConditionalScope() then
					function_scope.uncertain_function_return = false
					function_scope:CertainReturn()
				end
			elseif function_scope.uncertain_function_return then
				function_scope.uncertain_function_return = false
			end

			local thrown = false

			if function_scope.lua_silent_error then
				local errored_scope = table.remove(function_scope.lua_silent_error)

				if
					errored_scope and
					self:GetScope():IsCertainFromScope(errored_scope) and
					errored_scope:IsCertain()
				then
					thrown = true
				end
			end

			if not thrown then scope:CollectReturnTypes(node, types) end

			if scope:IsUncertain() then
				function_scope:UncertainReturn()
				scope:UncertainReturn()
			else
				function_scope:CertainReturn(self)
				scope:CertainReturn(self)
			end

			self:ApplyMutationsAfterReturn(scope, function_scope, true, scope:GetTrackedUpvalues(), scope:GetTrackedTables())
		end

		function META:Print(...)
			local helpers = require("nattlua.other.helpers")
			local node = self.current_expression
			local start, stop = node:GetStartStop()

			do
				local node = self.current_statement
				local start2, stop2 = node:GetStartStop()

				if start2 > start then
					start = start2
					stop = stop2
				end
			end

			local str = {}

			for i = 1, select("#", ...) do
				str[i] = tostring(select(i, ...))
			end

			print(helpers.FormatError(node.Code, table.concat(str, ", "), start, stop, 1))
		end

		function META:PushConditionalScope(statement, truthy, falsy)
			local scope = self:CreateAndPushScope()
			scope:SetConditionalScope(true)
			scope:SetStatement(statement)
			scope:SetTruthy(truthy)
			scope:SetFalsy(falsy)
			return scope
		end

		function META:ErrorAndCloneCurrentScope(node, err)
			self:Error(node, err)
			self:CloneCurrentScope()
			self:GetScope():SetConditionalScope(true)
		end

		function META:PopConditionalScope()
			self:PopScope()
		end
	end	
end)("./nattlua/analyzer/control_flow.lua");
package.loaded["nattlua.analyzer.mutations"] = (function(...)
	local ipairs = ipairs
	local Nil = require("nattlua.types.symbol").Nil
	local Table = require("nattlua.types.table").Table
	local print = print
	local tostring = tostring
	local ipairs = ipairs
	local table = require("table")
	local Union = require("nattlua.types.union").Union

	local function get_value_from_scope(self, mutations, scope, obj, key)
		do
			do
				local last_scope

				for i = #mutations, 1, -1 do
					local mut = mutations[i]

					if last_scope and mut.scope == last_scope then
						-- "redudant mutation"
						table.remove(mutations, i)
					end

					last_scope = mut.scope
				end
			end

			for i = #mutations, 1, -1 do
				local mut = mutations[i]

				if
					(
						scope:IsPartOfTestStatementAs(mut.scope) or
						(
							self.current_if_statement and
							mut.scope.statement == self.current_if_statement
						)
						or
						(
							mut.from_tracking and
							not mut.scope:IsCertainFromScope(scope)
						)
						or
						(
							obj.Type == "table" and
							obj:GetContract() ~= mut.contract
						)
					)
					and
					scope ~= mut.scope
				then
					-- not inside the same if statement"
					table.remove(mutations, i)
				end
			end

			do
				for i = #mutations, 1, -1 do
					local mut = mutations[i]

					if mut.scope:IsElseConditionalScope() then
						while true do
							local mut = mutations[i]

							if not mut then break end

							if
								not mut.scope:IsPartOfTestStatementAs(scope) and
								not mut.scope:IsCertainFromScope(scope)
							then
								for i = i, 1, -1 do
									if mutations[i].scope:IsCertainFromScope(scope) then
										-- redudant mutation before else part of if statement
										table.remove(mutations, i)
									end
								end

								break
							end

							i = i - 1
						end

						break
					end
				end
			end

			do
				local test_scope_a = scope:FindFirstConditionalScope()

				if test_scope_a then
					for _, mut in ipairs(mutations) do
						if mut.scope ~= scope then
							local test_scope_b = mut.scope:FindFirstConditionalScope()

							if test_scope_b then
								if test_scope_a:TracksSameAs(test_scope_b) then
									-- forcing scope certainty because this scope is using the same test condition
									mut.certain_override = true
								end
							end
						end
					end
				end
			end
		end

		if not mutations[1] then return end

		local union = Union({})

		if obj.Type == "upvalue" then union:SetUpvalue(obj) end

		for _, mut in ipairs(mutations) do
			local value = mut.value

			if value.Type == "union" and #value:GetData() == 1 then
				value = value:GetData()[1]
			end

			do
				local upvalues = mut.scope:GetTrackedUpvalues()

				if upvalues then
					for _, data in ipairs(upvalues) do
						local stack = data.stack

						if stack then
							local val

							if mut.scope:IsElseConditionalScope() then
								val = stack[#stack].falsy
							else
								val = stack[#stack].truthy
							end

							if val and (val.Type ~= "union" or not val:IsEmpty()) then
								union:RemoveType(val)
							end
						end
					end
				end
			end

			-- IsCertain isn't really accurate and seems to be used as a last resort in case the above logic doesn't work
			if mut.certain_override or mut.scope:IsCertainFromScope(scope) then
				union:Clear()
			end

			if
				union:Get(value) and
				value.Type ~= "any" and
				mutations[1].value.Type ~= "union" and
				mutations[1].value.Type ~= "function" and
				mutations[1].value.Type ~= "any"
			then
				union:RemoveType(mutations[1].value)
			end

			if _ == 1 and value.Type == "union" then
				union = value:Copy()

				if obj.Type == "upvalue" then union:SetUpvalue(obj) end
			else
				-- check if we have to infer the function, otherwise adding it to the union can cause collisions
				if
					value.Type == "function" and
					not value.called and
					not value.explicit_return and
					union:HasType("function")
				then
					self:Assert(value:GetNode() or self.current_expression, self:Call(value, value:GetArguments():Copy()))
				end

				union:AddType(value)
			end
		end

		local value = union

		if #union:GetData() == 1 then
			value = union:GetData()[1]

			if obj.Type == "upvalue" then value:SetUpvalue(obj) end
		end

		if value.Type == "union" then
			local found_scope, data = scope:FindResponsibleConditionalScopeFromUpvalue(obj)

			if found_scope then
				local stack = data.stack

				if stack then
					if
						found_scope:IsElseConditionalScope() or
						(
							found_scope ~= scope and
							scope:IsPartOfTestStatementAs(found_scope)
						)
					then
						local union = stack[#stack].falsy --:Copy()
						if obj.Type == "upvalue" then union:SetUpvalue(obj) end

						return union
					else
						local union = Union()

						for _, val in ipairs(stack) do
							union:AddType(val.truthy)
						end

						if obj.Type == "upvalue" then union:SetUpvalue(obj) end

						return union
					end
				end
			end
		end

		return value
	end

	local function initialize_mutation_tracker(obj, scope, key, hash, node)
		obj.mutations = obj.mutations or {}
		obj.mutations[hash] = obj.mutations[hash] or {}

		if obj.mutations[hash][1] == nil then
			if obj.Type == "table" then
				-- initialize the table mutations with an existing value or nil
				local val = (obj:GetContract() or obj):Get(key) or Nil():SetNode(node)
				table.insert(
					obj.mutations[hash],
					{scope = obj.scope or scope:GetRoot(), value = val, contract = obj:GetContract()}
				)
			end
		end
	end

	local function copy(tbl)
		local copy = {}

		for i, val in ipairs(tbl) do
			copy[i] = val
		end

		return copy
	end

	return function(META)
		function META:GetMutatedTableLength(obj)
			local mutations = obj.mutations

			if not mutations then return obj:GetLength() end

			local temp = Table()

			for key in pairs(mutations) do
				local realkey

				for _, kv in ipairs(obj:GetData()) do
					if kv.key:GetHash() == key then
						realkey = kv.key

						break
					end
				end

				local val = self:GetMutatedTableValue(obj, realkey, obj:Get(realkey))
				temp:Set(realkey, val)
			end

			return temp:GetLength()
		end

		function META:GetMutatedTableValue(tbl, key, value)
			if self:IsTypesystem() then return value end

			local hash = key:GetHash() or key:GetUpvalue() and key:GetUpvalue()

			if not hash then return end

			local scope = self:GetScope()
			local node = key:GetNode()
			initialize_mutation_tracker(tbl, scope, key, hash, node)
			return get_value_from_scope(self, copy(tbl.mutations[hash]), scope, tbl, hash)
		end

		function META:MutateTable(tbl, key, val, scope_override, from_tracking)
			if self:IsTypesystem() then return end

			local hash = key:GetHash() or key:GetUpvalue() and key:GetUpvalue()

			if not hash then return end

			local scope = scope_override or self:GetScope()
			local node = key:GetNode()
			initialize_mutation_tracker(tbl, scope, key, hash, node)

			if self:IsInUncertainLoop(scope) then
				if val.dont_widen then
					val = val:Copy()
				else
					val = val:Copy():Widen()
				end
			end

			table.insert(tbl.mutations[hash], {scope = scope, value = val, from_tracking = from_tracking})

			if from_tracking then scope:AddTrackedObject(tbl) end
		end

		function META:GetMutatedUpvalue(upvalue)
			if self:IsTypesystem() then return end

			local scope = self:GetScope()
			local hash = upvalue:GetKey()
			upvalue.mutations = upvalue.mutations or {}
			upvalue.mutations[hash] = upvalue.mutations[hash] or {}
			return get_value_from_scope(self, copy(upvalue.mutations[hash]), scope, upvalue, hash)
		end

		function META:MutateUpvalue(upvalue, val, scope_override, from_tracking)
			if self:IsTypesystem() then return end

			local scope = scope_override or self:GetScope()
			local hash = upvalue:GetKey()
			val:SetUpvalue(upvalue)
			upvalue.mutations = upvalue.mutations or {}
			upvalue.mutations[hash] = upvalue.mutations[hash] or {}

			if self:IsInUncertainLoop(scope) then
				if val.dont_widen then
					val = val:Copy()
				else
					val = val:Copy():Widen()
				end
			end

			table.insert(upvalue.mutations[hash], {scope = scope, value = val, from_tracking = from_tracking})

			if from_tracking then scope:AddTrackedObject(upvalue) end
		end

		do
			function META:PushTruthyExpressionContext()
				self.truthy_expression_context = (self.truthy_expression_context or 0) + 1
			end

			function META:PopTruthyExpressionContext()
				self.truthy_expression_context = self.truthy_expression_context - 1
			end

			function META:IsTruthyExpressionContext()
				return self.truthy_expression_context and
					self.truthy_expression_context > 0 and
					true or
					false
			end

			function META:PushFalsyExpressionContext()
				self.falsy_expression_context = (self.falsy_expression_context or 0) + 1
			end

			function META:PopFalsyExpressionContext()
				self.falsy_expression_context = self.falsy_expression_context - 1
			end

			function META:IsFalsyExpressionContext()
				return self.falsy_expression_context and
					self.falsy_expression_context > 0 and
					true or
					false
			end
		end

		do
			function META:ClearTracked()
				if self.tracked_upvalues then
					for _, upvalue in ipairs(self.tracked_upvalues) do
						upvalue.tracked_stack = nil
					end

					self.tracked_upvalues_done = nil
					self.tracked_upvalues = nil
				end

				if self.tracked_tables then
					for _, tbl in ipairs(self.tracked_tables) do
						tbl.tracked_stack = nil
					end

					self.tracked_tables_done = nil
					self.tracked_tables = nil
				end
			end

			function META:TrackUpvalue(obj, truthy_union, falsy_union, inverted)
				if self:IsTypesystem() then return end

				local upvalue = obj:GetUpvalue()

				if not upvalue then return end

				if obj.Type == "union" then
					if not truthy_union then truthy_union = obj:GetTruthy() end

					if not falsy_union then falsy_union = obj:GetFalsy() end

					upvalue.tracked_stack = upvalue.tracked_stack or {}
					table.insert(
						upvalue.tracked_stack,
						{
							truthy = truthy_union,
							falsy = falsy_union,
							inverted = inverted,
						}
					)
				end

				self.tracked_upvalues = self.tracked_upvalues or {}
				self.tracked_upvalues_done = self.tracked_upvalues_done or {}

				if not self.tracked_upvalues_done[upvalue] then
					table.insert(self.tracked_upvalues, upvalue)
					self.tracked_upvalues_done[upvalue] = true
				end
			end

			function META:TrackUpvalueNonUnion(obj)
				if self:IsTypesystem() then return end

				local upvalue = obj:GetUpvalue()

				if not upvalue then return end

				self.tracked_upvalues = self.tracked_upvalues or {}
				self.tracked_upvalues_done = self.tracked_upvalues_done or {}

				if not self.tracked_upvalues_done[upvalue] then
					table.insert(self.tracked_upvalues, upvalue)
					self.tracked_upvalues_done[upvalue] = true
				end
			end

			function META:GetTrackedUpvalue(obj)
				if self:IsTypesystem() then return end

				local upvalue = obj:GetUpvalue()
				local stack = upvalue and upvalue.tracked_stack

				if not stack then return end

				if self:IsTruthyExpressionContext() then
					return stack[#stack].truthy:SetUpvalue(upvalue)
				elseif self:IsFalsyExpressionContext() then
					return stack[#stack].falsy:SetUpvalue(upvalue)
				end
			end

			function META:TrackTableIndex(obj, key, val)
				if self:IsTypesystem() then return end

				local hash = key:GetHash()

				if not hash then return end

				val.parent_table = obj
				val.parent_key = key
				local truthy_union = val:GetTruthy()
				local falsy_union = val:GetFalsy()
				self:TrackTableIndexUnion(obj, key, truthy_union, falsy_union, self.inverted_index_tracking, true)
			end

			function META:TrackTableIndexUnion(obj, key, truthy_union, falsy_union, inverted, truthy_falsy)
				if self:IsTypesystem() then return end

				local hash = key:GetHash()

				if not hash then return end

				obj.tracked_stack = obj.tracked_stack or {}
				obj.tracked_stack[hash] = obj.tracked_stack[hash] or {}

				if falsy_union then
					falsy_union.parent_table = obj
					falsy_union.parent_key = key
				end

				if truthy_union then
					truthy_union.parent_table = obj
					truthy_union.parent_key = key
				end

				for i = #obj.tracked_stack[hash], 1, -1 do
					local tracked = obj.tracked_stack[hash][i]

					if tracked.truthy_falsy then
						table.remove(obj.tracked_stack[hash], i)
					end
				end

				table.insert(
					obj.tracked_stack[hash],
					{
						contract = obj:GetContract(),
						key = key,
						truthy = truthy_union,
						falsy = falsy_union,
						inverted = inverted,
						truthy_falsy = truthy_falsy,
					}
				)
				self.tracked_tables = self.tracked_tables or {}
				self.tracked_tables_done = self.tracked_tables_done or {}

				if not self.tracked_tables_done[obj] then
					table.insert(self.tracked_tables, obj)
					self.tracked_tables_done[obj] = true
				end
			end

			function META:GetTrackedObjectWithKey(obj, key)
				if not obj.tracked_stack or obj.tracked_stack[1] then return end

				local hash = key:GetHash()

				if not hash then return end

				local stack = obj.tracked_stack[hash]

				if not stack then return end

				if self:IsTruthyExpressionContext() then
					return stack[#stack].truthy
				elseif self:IsFalsyExpressionContext() then
					return stack[#stack].falsy
				end
			end

			function META:GetTrackedTables()
				local tables = {}

				if self.tracked_tables then
					for _, tbl in ipairs(self.tracked_tables) do
						if tbl.tracked_stack then
							for _, stack in pairs(tbl.tracked_stack) do
								table.insert(
									tables,
									{
										obj = tbl,
										key = stack[#stack].key,
										stack = copy(stack),
									}
								)
							end
						end
					end
				end

				return tables
			end

			function META:GetTrackedUpvalues(old_upvalues)
				local upvalues = {}
				local translate = {}

				if old_upvalues then
					for i, upvalue in ipairs(self:GetScope().upvalues.runtime.list) do
						local old = old_upvalues[i]
						translate[old] = upvalue
						upvalue.tracked_stack = old.tracked_stack
					end
				end

				if self.tracked_upvalues then
					for _, upvalue in ipairs(self.tracked_upvalues) do
						local stack = upvalue.tracked_stack

						if old_upvalues then upvalue = translate[upvalue] end

						table.insert(upvalues, {upvalue = upvalue, stack = stack and copy(stack)})
					end
				end

				return upvalues
			end

			--[[
			local x: 1 | 2 | 3

			if x == 1 then
				assert(x == 1)
			end
		]] function META:ApplyMutationsInIf(upvalues, tables)
				if upvalues then
					for _, data in ipairs(upvalues) do
						if data.stack then
							local union = Union()

							for _, v in ipairs(data.stack) do
								if v.truthy then union:AddType(v.truthy) end
							end

							if not union:IsEmpty() then
								union:SetUpvalue(data.upvalue)
								self:MutateUpvalue(data.upvalue, union, nil, true)
							end
						end
					end
				end

				if tables then
					for _, data in ipairs(tables) do
						local union = Union()

						for _, v in ipairs(data.stack) do
							if v.truthy then union:AddType(v.truthy) end
						end

						if not union:IsEmpty() then
							self:MutateTable(data.obj, data.key, union, nil, true)
						end
					end
				end
			end

			--[[
			local x: 1 | 2 | 3

			if x == 1 then
			else
				-- we get the original value and remove the truthy values (x == 1) and end up with 2 | 3
				assert(x == 2 | 3)
			end
		]] function META:ApplyMutationsInIfElse(blocks)
				for i, block in ipairs(blocks) do
					if block.upvalues then
						for _, data in ipairs(block.upvalues) do
							if data.stack then
								local union = self:GetMutatedUpvalue(data.upvalue)

								if union.Type == "union" then
									for _, v in ipairs(data.stack) do
										union:RemoveType(v.truthy)
									end

									union:SetUpvalue(data.upvalue)
								end

								self:MutateUpvalue(data.upvalue, union, nil, true)
							end
						end
					end

					if block.tables then
						for _, data in ipairs(block.tables) do
							local union = self:GetMutatedTableValue(data.obj, data.key)

							if union then
								if union.Type == "union" then
									for _, v in ipairs(data.stack) do
										union:RemoveType(v.truthy)
									end
								end

								self:MutateTable(data.obj, data.key, union, nil, true)
							end
						end
					end
				end
			end

			--[[
			local x: 1 | 2 | 3

			if x == 1 then return end

			assert(x == 2 | 3)
		]] --[[
			local x: 1 | 2 | 3

			if x == 1 then else return end

			assert(x == 1)
		]] --[[
			local x: 1 | 2 | 3

			if x == 1 then error("!") end

			assert(x == 2 | 3)
		]] local function solve(data, scope, negate)
				local stack = data.stack

				if stack then
					local val

					if negate and not (scope:IsElseConditionalScope() or stack[#stack].inverted) then
						val = stack[#stack].falsy
					else
						val = stack[#stack].truthy
					end

					if val and (val.Type ~= "union" or not val:IsEmpty()) then
						if val.Type == "union" and #val:GetData() == 1 then
							val = val:GetData()[1]
						end

						return val
					end
				end
			end

			function META:ApplyMutationsAfterReturn(scope, scope_override, negate, upvalues, tables)
				if upvalues then
					for _, data in ipairs(upvalues) do
						local val = solve(data, scope, negate)

						if val then
							val:SetUpvalue(data.upvalue)
							self:MutateUpvalue(data.upvalue, val, scope_override, true)
						end
					end
				end

				if tables then
					for _, data in ipairs(tables) do
						local val = solve(data, scope, negate)

						if val then
							self:MutateTable(data.obj, data.key, val, scope_override, true)
						end
					end
				end
			end
		end
	end	
end)("./nattlua/analyzer/mutations.lua");
package.loaded["nattlua.analyzer.operators.index"] = (function(...)
	local LString = require("nattlua.types.string").LString
	local Nil = require("nattlua.types.symbol").Nil
	local Tuple = require("nattlua.types.tuple").Tuple
	local Union = require("nattlua.types.union").Union
	local type_errors = require("nattlua.types.error_messages")
	return {
		Index = function(META)
			function META:IndexOperator(node, obj, key)
				if obj.Type == "union" then
					local union = Union({})

					for _, obj in ipairs(obj.Data) do
						if obj.Type == "tuple" and obj:GetLength() == 1 then
							obj = obj:Get(1)
						end

						-- if we have a union with an empty table, don't do anything
						-- ie {[number] = string} | {}
						if obj.Type == "table" and obj:IsEmpty() then

						else
							local val, err = obj:Get(key)

							if not val then return val, err end

							union:AddType(val)
						end
					end

					union:SetNode(node)
					return union
				end

				if obj.Type ~= "table" and obj.Type ~= "tuple" and (obj.Type ~= "string") then
					return obj:Get(key)
				end

				if obj:GetMetaTable() and (obj.Type ~= "table" or not obj:Contains(key)) then
					local index = obj:GetMetaTable():Get(LString("__index"))

					if index then
						if index == obj then return obj:Get(key) end

						if
							index.Type == "table" and
							(
								(
									index:GetContract() or
									index
								):Contains(key) or
								(
									index:GetMetaTable() and
									index:GetMetaTable():Contains(LString("__index"))
								)
							)
						then
							return self:IndexOperator(node, index:GetContract() or index, key)
						end

						if index.Type == "function" then
							local obj, err = self:Call(index, Tuple({obj, key}), key:GetNode())

							if not obj then return obj, err end

							return obj:Get(1)
						end
					end
				end

				if self:IsRuntime() then
					if obj.Type == "tuple" and obj:GetLength() == 1 then
						return self:IndexOperator(node, obj:Get(1), key)
					end
				end

				if self:IsTypesystem() then return obj:Get(key) end

				if obj.Type == "string" then
					return type_errors.other("attempt to index a string value")
				end

				local tracked = self:GetTrackedObjectWithKey(obj, key)

				if tracked then return tracked end

				local contract = obj:GetContract()

				if contract then
					local val, err = contract:Get(key)

					if not val then return val, err end

					if not obj.argument_index or contract.ref_argument then
						local val = self:GetMutatedTableValue(obj, key, val)

						if val then
							if val.Type == "union" then val = val:Copy(nil, true) end

							if not val:GetContract() then val:SetContract(val) end

							self:TrackTableIndex(obj, key, val)
							return val
						end
					end

					if val.Type == "union" then val = val:Copy(nil, true) end

					--TODO: this seems wrong, but it's for deferred analysis maybe not clearing up muations?
					if obj.mutations then
						local tracked = self:GetMutatedTableValue(obj, key, val)

						if tracked then return tracked end
					end

					self:TrackTableIndex(obj, key, val)
					return val
				end

				local val = self:GetMutatedTableValue(obj, key, obj:Get(key))

				if key:IsLiteral() then
					local found_key = obj:FindKeyValReverse(key)

					if found_key and not found_key.key:IsLiteral() then
						val = Union({Nil(), val})
					end
				end

				self:TrackTableIndex(obj, key, val)
				return val or Nil()
			end
		end,
	}	
end)("./nattlua/analyzer/operators/index.lua");
package.loaded["nattlua.analyzer.operators.newindex"] = (function(...)
	local ipairs = ipairs
	local tostring = tostring
	local LString = require("nattlua.types.string").LString
	local Any = require("nattlua.types.any").Any
	local Union = require("nattlua.types.union").Union
	local Tuple = require("nattlua.types.tuple").Tuple
	return {
		NewIndex = function(META)
			function META:NewIndexOperator(node, obj, key, val)
				if obj.Type == "union" then
					-- local x: nil | {foo = true}
					-- log(x.foo) << error because nil cannot be indexed, to continue we have to remove nil from the union
					-- log(x.foo) << no error, because now x has no field nil
					local new_union = Union()
					local truthy_union = Union()
					local falsy_union = Union()

					for _, v in ipairs(obj:GetData()) do
						local ok, err = self:NewIndexOperator(node, v, key, val)

						if not ok then
							self:ErrorAndCloneCurrentScope(node, err or "invalid set error", obj)
							falsy_union:AddType(v)
						else
							truthy_union:AddType(v)
							new_union:AddType(v)
						end
					end

					truthy_union:SetUpvalue(obj:GetUpvalue())
					falsy_union:SetUpvalue(obj:GetUpvalue())
					return new_union:SetNode(node)
				end

				if val.Type == "function" and val:GetNode().self_call then
					local arg = val:GetArguments():Get(1)

					if arg and not arg:GetContract() and not arg.Self then
						val.called = true
						val = val:Copy()
						val.called = nil
						val:GetArguments():Set(1, Union({Any(), obj}))
						self:CallMeLater(val, val:GetArguments(), val:GetNode(), true)
					end
				end

				if obj:GetMetaTable() then
					local func = obj:GetMetaTable():Get(LString("__newindex"))

					if func then
						if func.Type == "table" then return func:Set(key, val) end

						if func.Type == "function" then
							return self:Assert(node, self:Call(func, Tuple({obj, key, val}), key:GetNode()))
						end
					end
				end

				if
					obj.Type == "table" and
					obj.argument_index and
					(
						not obj:GetContract() or
						not obj:GetContract().mutable
					)
					and
					not obj.mutable
				then
					if not obj:GetContract() then
						self:Warning(
							node,
							{
								"mutating function argument ",
								obj,
								" #",
								obj.argument_index,
								" without a contract",
							}
						)
					else
						self:Error(
							node,
							{
								"mutating function argument ",
								obj,
								" #",
								obj.argument_index,
								" with an immutable contract",
							}
						)
					end
				end

				local contract = obj:GetContract()

				if contract then
					if self:IsRuntime() then
						local existing
						local err

						if obj == contract then
							if obj.mutable and obj:GetMetaTable() and obj:GetMetaTable().Self == obj then
								return obj:SetExplicit(key, val)
							else
								existing, err = contract:Get(key)

								if existing then
									existing = self:GetMutatedTableValue(obj, key, existing)
								end
							end
						else
							existing, err = contract:Get(key)
						end

						if existing then
							if val.Type == "function" and existing.Type == "function" then
								for i, v in ipairs(val:GetNode().identifiers) do
									if not existing:GetNode().identifiers[i] then
										self:Error(v, "too many arguments")

										break
									end
								end

								val:SetArguments(existing:GetArguments())
								val:SetReturnTypes(existing:GetReturnTypes())
								val.explicit_arguments = true
							end

							local ok, err = val:IsSubsetOf(existing)

							if ok then
								if obj == contract then
									self:MutateTable(obj, key, val)
									return true
								end
							else
								self:Error(node, err)
							end
						else
							self:Error(node, err)
						end
					elseif self:IsTypesystem() then
						return obj:GetContract():SetExplicit(key, val)
					end
				end

				if self:IsTypesystem() then
					if obj.Type == "table" and (val.Type ~= "symbol" or val.Data ~= nil) then
						return obj:SetExplicit(key, val)
					else
						return obj:Set(key, val)
					end
				end

				self:MutateTable(obj, key, val)

				if not obj:GetContract() then return obj:Set(key, val, self:IsRuntime()) end

				return true
			end
		end,
	}	
end)("./nattlua/analyzer/operators/newindex.lua");
package.loaded["nattlua.analyzer.operators.call"] = (function(...)
	local ipairs = ipairs
	local type = type
	local math = math
	local table = require("table")
	local tostring = tostring
	local debug = debug
	local print = print
	local string = require("string")
	local VarArg = require("nattlua.types.tuple").VarArg
	local Tuple = require("nattlua.types.tuple").Tuple
	local Table = require("nattlua.types.table").Table
	local Union = require("nattlua.types.union").Union
	local Nil = require("nattlua.types.symbol").Nil
	local Any = require("nattlua.types.any").Any
	local Function = require("nattlua.types.function").Function
	local LString = require("nattlua.types.string").LString
	local LNumber = require("nattlua.types.number").LNumber
	local Symbol = require("nattlua.types.symbol").Symbol
	local type_errors = require("nattlua.types.error_messages")

	local function lua_types_to_tuple(self, node, tps)
		local tbl = {}

		for i, v in ipairs(tps) do
			if type(v) == "table" and v.Type ~= nil then
				tbl[i] = v

				if not v:GetNode() then v:SetNode(node) end
			else
				if type(v) == "function" then
					tbl[i] = Function(
						{
							lua_function = v,
							arg = Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge)),
							ret = Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge)),
						}
					):SetNode(node):SetLiteral(true)

					if node.statements then tbl[i].function_body_node = node end
				else
					local t = type(v)

					if t == "number" then
						tbl[i] = LNumber(v):SetNode(node)
					elseif t == "string" then
						tbl[i] = LString(v):SetNode(node)
					elseif t == "boolean" then
						tbl[i] = Symbol(v):SetNode(node)
					elseif t == "table" then
						local tbl = Table()

						for _, val in ipairs(v) do
							tbl:Insert(val)
						end

						tbl:SetContract(tbl)
						return tbl
					else
						if node then print(node:Render(), "!") end

						self:Print(t)
						error(debug.traceback("NYI " .. t))
					end
				end
			end
		end

		if tbl[1] and tbl[1].Type == "tuple" and #tbl == 1 then return tbl[1] end

		return Tuple(tbl)
	end

	local unpack_union_tuples

	do
		local ipairs = ipairs

		local function should_expand(arg, contract)
			local b = arg.Type == "union"

			if contract.Type == "any" then b = false end

			if contract.Type == "union" then b = false end

			if arg.Type == "union" and contract.Type == "union" and contract:CanBeNil() then
				b = true
			end

			return b
		end

		function unpack_union_tuples(func_obj, arguments, function_arguments)
			local out = {}
			local lengths = {}
			local max = 1
			local ys = {}
			local arg_length = #arguments

			for i, obj in ipairs(arguments) do
				if not func_obj.no_expansion and should_expand(obj, function_arguments:Get(i)) then
					lengths[i] = #obj:GetData()
					max = max * lengths[i]
				else
					lengths[i] = 0
				end

				ys[i] = 1
			end

			for i = 1, max do
				local args = {}

				for i, obj in ipairs(arguments) do
					if lengths[i] == 0 then
						args[i] = obj
					else
						args[i] = obj:GetData()[ys[i]]
					end
				end

				out[i] = args

				for i = arg_length, 2, -1 do
					if i == arg_length then ys[i] = ys[i] + 1 end

					if ys[i] > lengths[i] then
						ys[i] = 1
						ys[i - 1] = ys[i - 1] + 1
					end
				end
			end

			return out
		end
	end

	return {
		Call = function(META)
			function META:AnalyzeFunctionBody(obj, function_node, arguments)
				local scope = self:CreateAndPushFunctionScope(obj:GetData().scope, obj:GetData().upvalue_position)
				self:PushGlobalEnvironment(
					function_node,
					self:GetDefaultEnvironment(self:GetCurrentAnalyzerEnvironment()),
					self:GetCurrentAnalyzerEnvironment()
				)

				if function_node.self_call then
					self:CreateLocalValue("self", arguments:Get(1) or Nil():SetNode(function_node))
				end

				for i, identifier in ipairs(function_node.identifiers) do
					local argi = function_node.self_call and (i + 1) or i

					if self:IsTypesystem() then
						self:CreateLocalValue(identifier.value.value, arguments:GetWithoutExpansion(argi))
					end

					if self:IsRuntime() then
						if identifier.value.value == "..." then
							self:CreateLocalValue(identifier.value.value, arguments:Slice(argi))
						else
							self:CreateLocalValue(identifier.value.value, arguments:Get(argi) or Nil():SetNode(identifier))
						end
					end
				end

				if
					function_node.kind == "local_type_function" or
					function_node.kind == "type_function"
				then
					self:PushAnalyzerEnvironment("typesystem")
				end

				local analyzed_return = self:AnalyzeStatementsAndCollectReturnTypes(function_node)

				if
					function_node.kind == "local_type_function" or
					function_node.kind == "type_function"
				then
					self:PopAnalyzerEnvironment()
				end

				self:PopGlobalEnvironment(self:GetCurrentAnalyzerEnvironment())
				local function_scope = self:PopScope()

				if scope.TrackedObjects then
					for _, obj in ipairs(scope.TrackedObjects) do
						if obj.Type == "upvalue" then
							for i = #obj.mutations, 1, -1 do
								local mut = obj.mutations[i]

								if mut.from_tracking then table.remove(obj.mutations, i) end
							end
						else
							for _, mutations in pairs(obj.mutations) do
								for i = #mutations, 1, -1 do
									local mut = mutations[i]

									if mut.from_tracking then table.remove(mutations, i) end
								end
							end
						end
					end
				end

				if analyzed_return.Type ~= "tuple" then
					return Tuple({analyzed_return}):SetNode(analyzed_return:GetNode()), scope
				end

				return analyzed_return, scope
			end

			local function call_analyzer_function(self, obj, function_arguments, arguments)
				do
					local ok, reason, a, b, i = arguments:IsSubsetOfTuple(obj:GetArguments())

					if not ok then
						if b and b:GetNode() then
							return type_errors.subset(a, b, {"function argument #", i, " '", b, "': ", reason})
						end

						return type_errors.subset(a, b, {"argument #", i, " - ", reason})
					end
				end

				local len = function_arguments:GetLength()

				if len == math.huge and arguments:GetLength() == math.huge then
					len = math.max(function_arguments:GetMinimumLength(), arguments:GetMinimumLength())
				end

				if self:IsTypesystem() then
					local ret = lua_types_to_tuple(
						self,
						obj:GetNode(),
						{
							self:CallLuaTypeFunction(
								self:GetActiveNode(),
								obj:GetData().lua_function,
								obj:GetData().scope or self:GetScope(),
								arguments:UnpackWithoutExpansion()
							),
						}
					)
					return ret
				end

				local tuples = {}

				for i, arg in ipairs(unpack_union_tuples(obj, {arguments:Unpack(len)}, function_arguments)) do
					tuples[i] = lua_types_to_tuple(
						self,
						obj:GetNode(),
						{
							self:CallLuaTypeFunction(
								self:GetActiveNode(),
								obj:GetData().lua_function,
								obj:GetData().scope or self:GetScope(),
								table.unpack(arg)
							),
						}
					)
				end

				local ret = Tuple({})

				for _, tuple in ipairs(tuples) do
					if tuple:GetUnpackable() or tuple:GetLength() == math.huge then
						return tuple
					end
				end

				for _, tuple in ipairs(tuples) do
					for i = 1, tuple:GetLength() do
						local v = tuple:Get(i)
						local existing = ret:Get(i)

						if existing then
							if existing.Type == "union" then
								existing:AddType(v)
							else
								ret:Set(i, Union({v, existing}))
							end
						else
							ret:Set(i, v)
						end
					end
				end

				return ret
			end

			local function call_type_signature_without_body(self, obj, arguments)
				do
					local ok, reason, a, b, i = arguments:IsSubsetOfTuple(obj:GetArguments())

					if not ok then
						if b and b:GetNode() then
							return type_errors.subset(a, b, {"function argument #", i, " '", b, "': ", reason})
						end

						return type_errors.subset(a, b, {"argument #", i, " - ", reason})
					end
				end

				for i, arg in ipairs(arguments:GetData()) do
					if arg.Type == "table" and arg:GetAnalyzerEnvironment() == "runtime" then
						if self.config.external_mutation then
							self:Warning(
								self:GetActiveNode(),
								{
									"argument #",
									i,
									" ",
									arg,
									" can be mutated by external call",
								}
							)
						end
					end
				end

				local ret = obj:GetReturnTypes():Copy()

				-- clear any reference id from the returned arguments
				for _, v in ipairs(ret:GetData()) do
					if v.Type == "table" then v:SetReferenceId(nil) end
				end

				return ret
			end

			local call_lua_function_with_body

			do
				local function mutate_type(self, i, arg, contract, arguments)
					local env = self:GetScope():GetNearestFunctionScope()
					env.mutated_types = env.mutated_types or {}
					arg:PushContract(contract)
					arg.argument_index = i
					table.insert(env.mutated_types, arg)
					arguments:Set(i, arg)
				end

				local function restore_mutated_types(self)
					local env = self:GetScope():GetNearestFunctionScope()

					if not env.mutated_types or not env.mutated_types[1] then return end

					for _, arg in ipairs(env.mutated_types) do
						arg:PopContract()
						arg.argument_index = nil
						self:MutateUpvalue(arg:GetUpvalue(), arg)
					end

					env.mutated_types = {}
				end

				local function check_and_setup_arguments(self, arguments, contracts, function_node, obj)
					local len = contracts:GetSafeLength(arguments)
					local contract_override = {}

					do -- analyze the type expressions
						self:CreateAndPushFunctionScope(obj:GetData().scope, obj:GetData().upvalue_position)
						self:PushAnalyzerEnvironment("typesystem")
						local args = {}

						for i, key in ipairs(function_node.identifiers) do
							if function_node.self_call then i = i + 1 end

							-- stem type so that we can allow
							-- function(x: foo<|x|>): nil
							self:CreateLocalValue(key.value.value, Any())
							local arg = arguments:Get(i)
							local contract = contracts:Get(i)

							if not arg then
								arg = Nil()
								arguments:Set(i, arg)
							end

							if contract and contract.ref_argument and arg then
								self:CreateLocalValue(key.value.value, arg)
							end

							if key.type_expression then
								args[i] = self:AnalyzeExpression(key.type_expression):GetFirstValue()
							end

							if contract and contract.ref_argument and arg then
								args[i] = arg
								args[i].ref_argument = true
								local ok, err = args[i]:IsSubsetOf(contract)

								if not ok then
									return type_errors.other({"argument #", i, " ", arg, ": ", err})
								end
							elseif args[i] then
								self:CreateLocalValue(key.value.value, args[i])
							end

							if not self.processing_deferred_calls then
								if contract and contract.literal_argument and arg and not arg:IsLiteral() then
									return type_errors.other({"argument #", i, " ", arg, ": not literal"})
								end
							end
						end

						self:PopAnalyzerEnvironment()
						self:PopScope()
						contract_override = args
					end

					do -- coerce untyped functions to constract callbacks
						for i, arg in ipairs(arguments:GetData()) do
							if arg.Type == "function" then
								if
									contract_override[i] and
									contract_override[i].Type == "union" and
									not contract_override[i].ref_argument
								then
									local merged = contract_override[i]:ShrinkToFunctionSignature()

									if merged then
										arg:SetArguments(merged:GetArguments())
										arg:SetReturnTypes(merged:GetReturnTypes())
									end
								else
									if not arg.explicit_arguments then
										local contract = contract_override[i] or obj:GetArguments():Get(i)

										if contract and not contract.ref_argument then
											if contract.Type == "union" then
												local tup = Tuple({})

												for _, func in ipairs(contract:GetData()) do
													tup:Merge(func:GetArguments())
													arg:SetArguments(tup)
												end
											elseif contract.Type == "function" then
												arg:SetArguments(contract:GetArguments():Copy(nil, true)) -- force copy tables so we don't mutate the contract
											end
										end
									end

									if not arg.explicit_return then
										local contract = contract_override[i] or obj:GetReturnTypes():Get(i)

										if contract and not contract.ref_argument then
											if contract.Type == "union" then
												local tup = Tuple({})

												for _, func in ipairs(contract:GetData()) do
													tup:Merge(func:GetReturnTypes())
												end

												arg:SetReturnTypes(tup)
											elseif contract.Type == "function" then
												arg:SetReturnTypes(contract:GetReturnTypes())
											end
										end
									end
								end
							end
						end
					end

					for i = 1, len do
						local arg = arguments:Get(i)
						local contract = contract_override[i] or contracts:Get(i)
						local ok, reason

						if not arg then
							if contract:IsFalsy() then
								arg = Nil()
								ok = true
							else
								ok, reason = type_errors.other(
									{
										"argument #",
										i,
										" expected ",
										contract,
										" got nil",
									}
								)
							end
						elseif arg.Type == "table" and contract.Type == "table" then
							ok, reason = arg:FollowsContract(contract)
						else
							if contract.Type == "union" then
								local shrunk = contract:ShrinkToFunctionSignature()

								if shrunk then contract = contract:ShrinkToFunctionSignature() end
							end

							if arg.Type == "function" and contract.Type == "function" then
								ok, reason = arg:IsCallbackSubsetOf(contract)
							else
								ok, reason = arg:IsSubsetOf(contract)
							end
						end

						if not ok then
							restore_mutated_types(self)
							return type_errors.other({"argument #", i, " ", arg, ": ", reason})
						end

						if
							arg.Type == "table" and
							contract.Type == "table" and
							arg:GetUpvalue() and
							not contract.ref_argument
						then
							mutate_type(self, i, arg, contract, arguments)
						else
							-- if it's a literal argument we pass the incoming value
							if not contract.ref_argument then
								local t = contract:Copy()
								t:SetContract(contract)
								arguments:Set(i, t)
							end
						end
					end

					return true
				end

				local function check_return_result(self, result, contract)
					if self:IsTypesystem() then
						-- in the typesystem we must not unpack tuples when checking
						local ok, reason, a, b, i = result:IsSubsetOfTupleWithoutExpansion(contract)

						if not ok then
							local _, err = type_errors.subset(a, b, {"return #", i, " '", b, "': ", reason})
							self:Error(b and b:GetNode() or self.current_statement, err)
						end

						return
					end

					local original_contract = contract

					if
						contract:GetLength() == 1 and
						contract:Get(1).Type == "union" and
						contract:Get(1):HasType("tuple")
					then
						contract = contract:Get(1)
					end

					if
						result.Type == "tuple" and
						result:GetLength() == 1 and
						result:Get(1) and
						result:Get(1).Type == "union" and
						result:Get(1):HasType("tuple")
					then
						result = result:Get(1)
					end

					if result.Type == "union" then
						-- typically a function with mutliple uncertain returns
						for _, obj in ipairs(result:GetData()) do
							if obj.Type ~= "tuple" then
								-- if the function returns one value it's not in a tuple
								obj = Tuple({obj}):SetNode(obj:GetNode())
							end

							-- check each tuple in the union
							check_return_result(self, obj, original_contract)
						end
					else
						if contract.Type == "union" then
							local errors = {}

							for _, contract in ipairs(contract:GetData()) do
								local ok, reason = result:IsSubsetOfTuple(contract)

								if ok then
									-- something is ok then just return and don't report any errors found
									return
								else
									table.insert(errors, {contract = contract, reason = reason})
								end
							end

							for _, error in ipairs(errors) do
								self:Error(result:GetNode(), error.reason)
							end
						else
							local ok, reason, a, b, i = result:IsSubsetOfTuple(contract)

							if not ok then self:Error(result:GetNode(), reason) end
						end
					end
				end

				call_lua_function_with_body = function(self, obj, arguments, function_node)
					if obj:HasExplicitArguments() or function_node.identifiers_typesystem then
						if
							function_node.kind == "local_type_function" or
							function_node.kind == "type_function"
						then
							if function_node.identifiers_typesystem then
								local call_expression = self:GetActiveNode()

								for i, key in ipairs(function_node.identifiers) do
									if function_node.self_call then i = i + 1 end

									local arg = arguments:Get(i)
									local generic_upvalue = function_node.identifiers_typesystem and
										function_node.identifiers_typesystem[i] or
										nil
									local generic_type = call_expression.expressions_typesystem and
										call_expression.expressions_typesystem[i] or
										nil

									if generic_upvalue then
										local T = self:AnalyzeExpression(generic_type)
										self:CreateLocalValue(generic_upvalue.value.value, T)
									end
								end

								local ok, err = check_and_setup_arguments(self, arguments, obj:GetArguments(), function_node, obj)

								if not ok then return ok, err end
							end

							-- otherwise if we're a analyzer function we just do a simple check and arguments are passed as is
							-- local type foo(T: any) return T end
							-- T becomes the type that is passed in, and not "any"
							-- it's the equivalent of function foo<T extends any>(val: T) { return val }
							local ok, reason, a, b, i = arguments:IsSubsetOfTupleWithoutExpansion(obj:GetArguments())

							if not ok then
								if b and b:GetNode() then
									return type_errors.subset(a, b, {"function argument #", i, " '", b, "': ", reason})
								end

								return type_errors.subset(a, b, {"argument #", i, " - ", reason})
							end
						elseif self:IsRuntime() then
							-- if we have explicit arguments, we need to do a complex check against the contract
							-- this might mutate the arguments
							local ok, err = check_and_setup_arguments(self, arguments, obj:GetArguments(), function_node, obj)

							if not ok then return ok, err end
						end
					end

					-- crawl the function with the new arguments
					-- return_result is either a union of tuples or a single tuple
					local return_result, scope = self:AnalyzeFunctionBody(obj, function_node, arguments)
					restore_mutated_types(self)
					-- used for analyzing side effects
					obj:AddScope(arguments, return_result, scope)

					if not obj:HasExplicitArguments() then
						if not obj.arguments_inferred and function_node.identifiers then
							for i in ipairs(obj:GetArguments():GetData()) do
								if function_node.self_call then
									-- we don't count the actual self argument
									local node = function_node.identifiers[i + 1]

									if node and not node.type_expression then
										self:Warning(node, "argument is untyped")
									end
								elseif
									function_node.identifiers[i] and
									not function_node.identifiers[i].type_expression
								then
									self:Warning(function_node.identifiers[i], "argument is untyped")
								end
							end
						end

						obj:GetArguments():Merge(arguments:Slice(1, obj:GetArguments():GetMinimumLength()))
					end

					do -- this is for the emitter
						if function_node.identifiers then
							for i, node in ipairs(function_node.identifiers) do
								node:AddType(obj:GetArguments():Get(i))
							end
						end

						function_node:AddType(obj)
					end

					local return_contract = obj:HasExplicitReturnTypes() and obj:GetReturnTypes()

					-- if the function has return type annotations, analyze them and use it as contract
					if not return_contract and function_node.return_types and self:IsRuntime() then
						self:CreateAndPushFunctionScope(obj:GetData().scope, obj:GetData().upvalue_position)
						self:PushAnalyzerEnvironment("typesystem")

						for i, key in ipairs(function_node.identifiers) do
							if function_node.self_call then i = i + 1 end

							self:CreateLocalValue(key.value.value, arguments:Get(i))
						end

						return_contract = Tuple(self:AnalyzeExpressions(function_node.return_types))
						self:PopAnalyzerEnvironment()
						self:PopScope()
					end

					if not return_contract then
						-- if there is no return type 
						if self:IsRuntime() then
							local copy

							for i, v in ipairs(return_result:GetData()) do
								if v.Type == "table" and not v:GetContract() then
									copy = copy or return_result:Copy()
									local tbl = Table()

									for _, kv in ipairs(v:GetData()) do
										tbl:Set(kv.key, self:GetMutatedTableValue(v, kv.key, kv.val))
									end

									copy:Set(i, tbl)
								end
							end

							obj:GetReturnTypes():Merge(copy or return_result)
						end

						return return_result
					end

					-- check against the function's return type
					check_return_result(self, return_result, return_contract)

					if self:IsTypesystem() then return return_result end

					local contract = obj:GetReturnTypes():Copy()

					for _, v in ipairs(contract:GetData()) do
						if v.Type == "table" then v:SetReferenceId(nil) end
					end

					-- if a return type is marked with literal, it will pass the literal value back to the caller
					-- a bit like generics
					for i, v in ipairs(return_contract:GetData()) do
						if v.ref_argument then contract:Set(i, return_result:Get(i)) end
					end

					return contract
				end
			end

			local function make_callable_union(self, obj)
				local new_union = obj.New()
				local truthy_union = obj.New()
				local falsy_union = obj.New()

				for _, v in ipairs(obj.Data) do
					if v.Type ~= "function" and v.Type ~= "table" and v.Type ~= "any" then
						falsy_union:AddType(v)
						self:ErrorAndCloneCurrentScope(
							self:GetActiveNode(),
							{
								"union ",
								obj,
								" contains uncallable object ",
								v,
							},
							obj
						)
					else
						truthy_union:AddType(v)
						new_union:AddType(v)
					end
				end

				truthy_union:SetUpvalue(obj:GetUpvalue())
				falsy_union:SetUpvalue(obj:GetUpvalue())
				return truthy_union:SetNode(self:GetActiveNode())
			end

			local function Call(self, obj, arguments)
				if obj.Type == "union" then
					-- make sure the union is callable, we pass the analyzer and 
					-- it will throw errors if the union contains something that is not callable
					-- however it will continue and just remove those values from the union
					obj = make_callable_union(self, obj)
				end

				-- if obj is a tuple it will return its first value 
				obj = obj:GetFirstValue()
				local function_node = obj.function_body_node

				if obj.Type ~= "function" then
					if obj.Type == "any" then
						-- it's ok to call any types, it will just return any
						-- check arguments that can be mutated
						for _, arg in ipairs(arguments:GetData()) do
							if arg.Type == "table" and arg:GetAnalyzerEnvironment() == "runtime" then
								if arg:GetContract() then
									-- error if we call any with tables that have contracts
									-- since anything might happen to them in an any call
									self:Error(
										self:GetActiveNode(),
										{
											"cannot mutate argument with contract ",
											arg:GetContract(),
										}
									)
								else
									-- if we pass a table without a contract to an any call, we add any to its key values
									for _, keyval in ipairs(arg:GetData()) do
										keyval.key = Union({Any(), keyval.key})
										keyval.val = Union({Any(), keyval.val})
									end
								end
							end
						end
					end

					return obj:Call(self, arguments)
				end

				-- mark the object as called so the unreachable code step won't call it
				-- TODO: obj:Set/GetCalled()?
				obj:SetCalled(true)
				local function_arguments = obj:GetArguments()

				-- infer any uncalled functions in the arguments to get their return type
				for i, b in ipairs(arguments:GetData()) do
					if b.Type == "function" and not b:IsCalled() and not b:HasExplicitReturnTypes() then
						local a = function_arguments:Get(i)

						if
							a and
							(
								a.Type == "function" and
								not a:GetReturnTypes():IsSubsetOf(b:GetReturnTypes())
							)
							or
							not a:IsSubsetOf(b)
						then
							b.arguments_inferred = true
							self:Assert(self:GetActiveNode(), self:Call(b, b:GetArguments():Copy()))
						end
					end
				end

				if obj.expand then self:GetActiveNode().expand = obj end

				if obj:GetData().lua_function then
					return call_analyzer_function(self, obj, function_arguments, arguments)
				elseif function_node then
					return call_lua_function_with_body(self, obj, arguments, function_node)
				end

				return call_type_signature_without_body(self, obj, arguments)
			end

			function META:Call(obj, arguments, call_node)
				-- not sure about this, it's used to access the call_node from deeper calls
				-- without resorting to argument drilling
				local node = call_node or obj:GetNode() or obj
				self.current_call = node

				-- call_node or obj:GetNode() might be nil when called from tests and other places
				if node.recursively_called then return node.recursively_called:Copy() end

				self:PushActiveNode(node)

				-- extra protection, maybe only useful during development
				if debug.getinfo(300) then
					local level = 1
					print("Trace:")

					while true do
						local info = debug.getinfo(level, "Sln")

						if not info then break end

						if info.what == "C" then
							print(string.format("\t%i: C function\t\"%s\"", level, info.name))
						else
							local path = info.source

							if path:sub(1, 1) == "@" then
								path = path:sub(2)
							else
								path = info.short_src
							end

							print(string.format("%i: %s\t%s:%s\t", level, info.name, path, info.currentline))
						end

						level = level + 1
					end

					print("")
					return false, "call stack is too deep"
				end

				local is_runtime = self:IsRuntime()

				if is_runtime then
					-- setup and track the callstack to avoid infinite loops or callstacks that are too big
					self.call_stack = self.call_stack or {}

					for _, v in ipairs(self.call_stack) do
						-- if the callnode is the same, we're doing some infinite recursion
						if v.call_node == self:GetActiveNode() then
							if obj.explicit_return then
								-- so if we have explicit return types, just return those
								node.recursively_called = obj:GetReturnTypes():Copy()
								return node.recursively_called
							else
								-- if not we sadly have to resort to any
								-- TODO: error?
								-- TODO: use VarArg() ?
								node.recursively_called = Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
								return node.recursively_called
							end
						end
					end

					table.insert(
						self.call_stack,
						{
							obj = obj,
							function_node = obj.function_body_node,
							call_node = self:GetActiveNode(),
							scope = self:GetScope(),
						}
					)
				end

				local ok, err = Call(self, obj, arguments)

				if is_runtime then table.remove(self.call_stack) end

				self:PopActiveNode()
				self.current_call = nil
				return ok, err
			end

			function META:IsDefinetlyReachable()
				local scope = self:GetScope()
				local function_scope = scope:GetNearestFunctionScope()

				if not scope:IsCertain() then return false, "scope is uncertain" end

				if function_scope.uncertain_function_return == true then
					return false, "uncertain function return"
				end

				if function_scope.lua_silent_error then
					for _, scope in ipairs(function_scope.lua_silent_error) do
						if not scope:IsCertain() then
							return false, "parent function scope can throw an error"
						end
					end
				end

				if self.call_stack then
					for i = #self.call_stack, 1, -1 do
						local scope = self.call_stack[i].scope

						if not scope:IsCertain() then
							return false, "call stack scope is uncertain"
						end

						if scope.uncertain_function_return == true then
							return false, "call stack scope has uncertain function return"
						end
					end
				end

				return true
			end

			function META:IsMaybeReachable()
				local scope = self:GetScope()
				local function_scope = scope:GetNearestFunctionScope()

				if function_scope.lua_silent_error then
					for _, scope in ipairs(function_scope.lua_silent_error) do
						if not scope:IsCertain() then return false end
					end
				end

				if self.call_stack then
					for i = #self.call_stack, 1, -1 do
						local parent_scope = self.call_stack[i].scope

						if
							not parent_scope:IsCertain() or
							parent_scope.uncertain_function_return == true
						then
							if parent_scope:IsCertainFromScope(scope) then return false end
						end
					end
				end

				return true
			end

			function META:UncertainReturn()
				self.call_stack[#self.call_stack].scope:UncertainReturn()
			end
		end,
	}	
end)("./nattlua/analyzer/operators/call.lua");
package.loaded["nattlua.analyzer.statements.assignment"] = (function(...)
	local ipairs = ipairs
	local tostring = tostring
	local table = require("table")
	local NodeToString = require("nattlua.types.string").NodeToString
	local Union = require("nattlua.types.union").Union
	local Nil = require("nattlua.types.symbol").Nil

	local function check_type_against_contract(val, contract)
		-- if the contract is unique / nominal, ie
		-- local a: Person = {name = "harald"}
		-- Person is not a subset of {name = "harald"} because
		-- Person is only equal to Person
		-- so we need to disable this check during assignment
		local skip_uniqueness = contract:IsUnique() and not val:IsUnique()

		if skip_uniqueness then contract:DisableUniqueness() end

		local ok, reason = val:IsSubsetOf(contract)

		if skip_uniqueness then
			contract:EnableUniqueness()
			val:SetUniqueID(contract:GetUniqueID())
		end

		if not ok then return ok, reason end

		-- make sure the table contains all the keys in the contract as well
		-- since {foo = true, bar = "harald"} 
		-- is technically a subset of 
		-- {foo = true, bar = "harald", baz = "jane"}
		if contract.Type == "table" and val.Type == "table" then
			return val:ContainsAllKeysIn(contract)
		end

		return true
	end

	return {
		AnalyzeAssignment = function(self, statement)
			local left = {}
			local right = {}

			for left_pos, exp_key in ipairs(statement.left) do
				if exp_key.kind == "value" then
					-- local foo, bar = *
					left[left_pos] = NodeToString(exp_key)
				elseif exp_key.kind == "postfix_expression_index" then
					-- foo[bar] = *
					left[left_pos] = self:AnalyzeExpression(exp_key.expression)
				elseif exp_key.kind == "binary_operator" then
					-- foo.bar = *
					left[left_pos] = self:AnalyzeExpression(exp_key.right)
				else
					self:FatalError("unhandled assignment expression " .. tostring(exp_key:Render()))
				end
			end

			if statement.right then
				for right_pos, exp_val in ipairs(statement.right) do
					-- when "self" is looked up in the typesystem in analyzer:AnalyzeExpression, we refer left[right_pos]
					-- use context?
					self.left_assigned = left[right_pos]
					local obj, err = self:AnalyzeExpression(exp_val)
					self:ClearTracked()

					if obj.Type == "tuple" and obj:GetLength() == 1 then
						obj = obj:Get(1)
					end

					if obj.Type == "tuple" then
						if self:IsRuntime() then
							-- at runtime unpack the tuple
							for i = 1, #statement.left do
								local index = right_pos + i - 1
								right[index] = obj:Get(i)
							end
						end

						if self:IsTypesystem() then
							if obj:HasTuples() then
								-- if we have a tuple with, plainly unpack the tuple while preserving the tuples inside
								for i = 1, #statement.left do
									local index = right_pos + i - 1
									right[index] = obj:GetWithoutExpansion(i)
								end
							else
								-- otherwise plainly assign it
								right[right_pos] = obj
							end
						end
					elseif obj.Type == "union" then
						for i = 1, #statement.left do
							-- if the union is empty or has no tuples, just assign it
							if obj:IsEmpty() or not obj:HasTuples() then
								right[right_pos] = obj
							else
								-- unpack unions with tuples
								-- ⦗false, string, 2⦘ | ⦗true, 1⦘ at first index would be true | false
								local index = right_pos + i - 1
								right[index] = obj:GetAtIndex(index)
							end
						end
					else
						right[right_pos] = obj

						-- when the right side has a type expression, it's invoked using the as operator
						if exp_val.type_expression then obj:Seal() end
					end
				end

				-- cuts the last arguments
				-- local funciton test() return 1,2,3 end
				-- local a,b,c = test(), 1337
				-- a should be 1
				-- b should be 1337
				-- c should be nil
				local last = statement.right[#statement.right]

				if last.kind == "value" and last.value.value ~= "..." then
					for _ = 1, #right - #statement.right do
						table.remove(right, #right)
					end
				end
			end

			-- here we check the types
			for left_pos, exp_key in ipairs(statement.left) do
				local val = right[left_pos] or Nil():SetNode(exp_key)

				-- do we have a type expression? 
				-- local a: >>number<< = 1
				if exp_key.type_expression then
					self:PushAnalyzerEnvironment("typesystem")
					local contract = self:AnalyzeExpression(exp_key.type_expression)
					self:PopAnalyzerEnvironment()

					if right[left_pos] then
						local contract = contract

						if contract.Type == "tuple" and contract:GetLength() == 1 then
							contract = contract:Get(1)
						end

						-- we copy the literalness of the contract so that
						-- local a: number = 1
						-- becomes
						-- local a: number = number
						val:CopyLiteralness(contract)

						if val.Type == "table" then
							-- coerce any untyped functions based on contract
							val:CoerceUntypedFunctions(contract)
						end

						self:Assert(statement or val:GetNode() or exp_key.type_expression, check_type_against_contract(val, contract))
					else
						if contract.Type == "tuple" and contract:GetLength() == 1 then
							contract = contract:Get(1)
						end
					end

					-- we set a's contract to be number
					val:SetContract(contract)

					-- this is for "local a: number" without the right side being assigned
					if not right[left_pos] then
						-- make a copy of the contract and use it
						-- so the value can change independently from the contract
						val = contract:Copy()
						val:SetContract(contract)
					end
				end

				-- used by the emitter
				exp_key:AddType(val)
				val:SetTokenLabelSource(exp_key)
				val:SetAnalyzerEnvironment(self:GetCurrentAnalyzerEnvironment())

				-- if all is well, create or mutate the value
				if statement.kind == "local_assignment" then
					local immutable = false

					if exp_key.attribute then
						if exp_key.attribute.value == "const" then immutable = true end
					end

					-- local assignment: local a = 1
					self:CreateLocalValue(exp_key.value.value, val, immutable)
				elseif statement.kind == "assignment" then
					local key = left[left_pos]

					-- plain assignment: a = 1
					if exp_key.kind == "value" then
						if self:IsRuntime() then -- check for any previous upvalues
							local existing_value = self:GetLocalOrGlobalValue(key)
							local contract = existing_value and existing_value:GetContract()

							if contract then
								if contract.Type == "tuple" then
									contract = contract:GetFirstValue()
								end

								val:CopyLiteralness(contract)
								self:Assert(statement or val:GetNode() or exp_key.type_expression, check_type_against_contract(val, contract))
								val:SetContract(contract)
							end
						end

						local val = self:SetLocalOrGlobalValue(key, val)

						if val then
							-- this is used for tracking function dependencies
							if val.Type == "upvalue" then
								self:GetScope():AddDependency(val)
							else
								self:GetScope():AddDependency({key = key, val = val})
							end
						end
					else
						-- TODO: refactor out to mutation assignment?
						-- index assignment: foo[a] = 1
						local obj = self:AnalyzeExpression(exp_key.left)
						self:ClearTracked()

						if self:IsRuntime() then key = key:GetFirstValue() end

						self:Assert(exp_key, self:NewIndexOperator(exp_key, obj, key, val))
					end
				end
			end
		end,
	}	
end)("./nattlua/analyzer/statements/assignment.lua");
package.loaded["nattlua.analyzer.statements.destructure_assignment"] = (function(...)
	local tostring = tostring
	local ipairs = ipairs
	local NodeToString = require("nattlua.types.string").NodeToString
	local Nil = require("nattlua.types.symbol").Nil
	return {
		AnalyzeDestructureAssignment = function(self, statement)
			local obj = self:AnalyzeExpression(statement.right)

			if obj.Type == "union" then obj = obj:GetData()[1] end

			if obj.Type == "tuple" then obj = obj:Get(1) end

			if obj.Type ~= "table" then
				self:Error(statement.right, "expected a table on the right hand side, got " .. tostring(obj.Type))
			end

			if statement.default then
				if statement.kind == "local_destructure_assignment" then
					self:CreateLocalValue(statement.default.value.value, obj)
				elseif statement.kind == "destructure_assignment" then
					self:SetLocalOrGlobalValue(NodeToString(statement.default), obj)
				end
			end

			for _, node in ipairs(statement.left) do
				local obj = node.value and obj:Get(NodeToString(node))

				if not obj then
					if self:IsRuntime() then
						obj = Nil():SetNode(node)
					else
						self:Error(node, "field " .. tostring(node.value.value) .. " does not exist")
					end
				end

				if statement.kind == "local_destructure_assignment" then
					self:CreateLocalValue(node.value.value, obj)
				elseif statement.kind == "destructure_assignment" then
					self:SetLocalOrGlobalValue(NodeToString(node), obj)
				end
			end
		end,
	}	
end)("./nattlua/analyzer/statements/destructure_assignment.lua");
package.loaded["nattlua.analyzer.expressions.function"] = (function(...)
	local tostring = tostring
	local table = require("table")
	local Union = require("nattlua.types.union").Union
	local Any = require("nattlua.types.any").Any
	local Tuple = require("nattlua.types.tuple").Tuple
	local Function = require("nattlua.types.function").Function
	local Any = require("nattlua.types.any").Any
	local VarArg = require("nattlua.types.tuple").VarArg
	local ipairs = _G.ipairs
	local locals = ""
	locals = locals .. "local nl=require(\"nattlua\");"
	locals = locals .. "local types=require(\"nattlua.types.types\");"

	for k, v in pairs(_G) do
		locals = locals .. "local " .. tostring(k) .. "=_G." .. k .. ";"
	end

	local function analyze_function_signature(self, node, current_function)
		local explicit_arguments = false
		local explicit_return = false
		local args = {}
		local argument_tuple_override
		local return_tuple_override
		self:CreateAndPushFunctionScope(current_function:GetData().scope, current_function:GetData().upvalue_position)
		self:PushAnalyzerEnvironment("typesystem")

		if node.kind == "function" or node.kind == "local_function" then
			for i, key in ipairs(node.identifiers) do
				-- stem type so that we can allow
				-- function(x: foo<|x|>): nil
				self:CreateLocalValue(key.value.value, Any())

				if key.type_expression then
					args[i] = self:AnalyzeExpression(key.type_expression)
					explicit_arguments = true
				elseif key.value.value == "..." then
					args[i] = VarArg(Any())
				else
					args[i] = Any():SetNode(key)
				end

				self:CreateLocalValue(key.value.value, args[i])
			end
		elseif
			node.kind == "analyzer_function" or
			node.kind == "local_analyzer_function" or
			node.kind == "local_type_function" or
			node.kind == "type_function" or
			node.kind == "function_signature"
		then
			explicit_arguments = true

			for i, key in ipairs(node.identifiers) do
				local generic_type = node.identifiers_typesystem and node.identifiers_typesystem[i]

				if generic_type then
					if generic_type.identifier and generic_type.identifier.value ~= "..." then
						self:CreateLocalValue(generic_type.identifier.value, self:AnalyzeExpression(key):GetFirstValue())
					elseif generic_type.type_expression then
						self:CreateLocalValue(generic_type.value.value, Any(), i)
					end
				end

				if key.identifier and key.identifier.value ~= "..." then
					args[i] = self:AnalyzeExpression(key):GetFirstValue()
					self:CreateLocalValue(key.identifier.value, args[i])
				elseif key.kind == "vararg" then
					args[i] = self:AnalyzeExpression(key)
				elseif key.type_expression then
					self:CreateLocalValue(key.value.value, Any(), i)
					args[i] = self:AnalyzeExpression(key.type_expression)
				elseif key.kind == "value" then
					if not node.statements then
						local obj = self:AnalyzeExpression(key)

						if i == 1 and obj.Type == "tuple" and #node.identifiers == 1 then
							-- if we pass in a tuple we override the argument type
							-- function(mytuple): string
							argument_tuple_override = obj

							break
						else
							local val = self:Assert(node, obj:GetFirstValue())

							-- in case the tuple is empty
							if val then args[i] = val end
						end
					else
						args[i] = Any():SetNode(key)
					end
				else
					local obj = self:AnalyzeExpression(key)

					if i == 1 and obj.Type == "tuple" and #node.identifiers == 1 then
						-- if we pass in a tuple we override the argument type
						-- function(mytuple): string
						argument_tuple_override = obj

						break
					else
						local val = self:Assert(node, obj:GetFirstValue())

						-- in case the tuple is empty
						if val then args[i] = val end
					end
				end
			end
		else
			self:FatalError("unhandled statement " .. tostring(node))
		end

		if node.self_call and node.expression then
			self:PushAnalyzerEnvironment("runtime")
			local val = self:AnalyzeExpression(node.expression.left):GetFirstValue()
			self:PopAnalyzerEnvironment()

			if val then
				if val:GetContract() or val.Self then
					table.insert(args, 1, val.Self or val)
				else
					table.insert(args, 1, Union({Any(), val}))
				end
			end
		end

		local ret = {}

		if node.return_types then
			explicit_return = true

			-- TODO:
			-- somethings up with function(): (a,b,c)
			-- when doing this vesrus function(): a,b,c
			-- the return tuple becomes a tuple inside a tuple
			for i, type_exp in ipairs(node.return_types) do
				local obj = self:AnalyzeExpression(type_exp)

				if i == 1 and obj.Type == "tuple" and #node.identifiers == 1 and not obj.Repeat then
					-- if we pass in a tuple, we want to override the return type
					-- function(): mytuple
					return_tuple_override = obj

					break
				else
					ret[i] = obj
				end
			end
		end

		self:PopAnalyzerEnvironment()
		self:PopScope()
		return argument_tuple_override or Tuple(args),
		return_tuple_override or Tuple(ret),
		explicit_arguments,
		explicit_return
	end

	return {
		AnalyzeFunction = function(self, node)
			if
				node.type == "statement" and
				(
					node.kind == "local_analyzer_function" or
					node.kind == "analyzer_function"
				)
			then
				node.type = "expression"
				node.kind = "analyzer_function"
			end

			local obj = Function(
				{
					scope = self:GetScope(),
					upvalue_position = #self:GetScope():GetUpvalues("runtime"),
				}
			):SetNode(node)
			self:PushCurrentType(obj, "function")
			local args, ret, explicit_arguments, explicit_return = analyze_function_signature(self, node, obj)
			local func
			self:PopCurrentType("function")

			if
				node.statements and
				(
					node.kind == "analyzer_function" or
					node.kind == "local_analyzer_function"
				)
			then
				node.analyzer_function = true
				--'local analyzer = self;local env = self:GetScopeHelper(scope);'
				func = self:CompileLuaAnalyzerDebugCode("return  " .. node:Render({uncomment_types = true, analyzer_function = true}), node)()
			end

			obj.Data.arg = args
			obj.Data.ret = ret
			obj.Data.lua_function = func

			if node.statements then obj.function_body_node = node end

			obj.explicit_arguments = explicit_arguments
			obj.explicit_return = explicit_return

			if self:IsRuntime() then self:CallMeLater(obj, args, node, true) end

			return obj
		end,
	}	
end)("./nattlua/analyzer/expressions/function.lua");
package.loaded["nattlua.analyzer.statements.function"] = (function(...)
	local AnalyzeFunction = require("nattlua.analyzer.expressions.function").AnalyzeFunction
	local NodeToString = require("nattlua.types.string").NodeToString
	return {
		AnalyzeFunction = function(self, statement)
			if
				statement.kind == "local_function" or
				statement.kind == "local_analyzer_function" or
				statement.kind == "local_type_function"
			then
				self:PushAnalyzerEnvironment(statement.kind == "local_function" and "runtime" or "typesystem")
				self:CreateLocalValue(statement.tokens["identifier"].value, AnalyzeFunction(self, statement))
				self:PopAnalyzerEnvironment()
			elseif
				statement.kind == "function" or
				statement.kind == "analyzer_function" or
				statement.kind == "type_function"
			then
				local key = statement.expression
				self:PushAnalyzerEnvironment(statement.kind == "function" and "runtime" or "typesystem")

				if key.kind == "binary_operator" then
					local obj = self:AnalyzeExpression(key.left)
					local key = self:AnalyzeExpression(key.right)
					local val = AnalyzeFunction(self, statement)
					self:NewIndexOperator(statement, obj, key, val)
				else
					local key = NodeToString(key)
					local val = AnalyzeFunction(self, statement)
					self:SetLocalOrGlobalValue(key, val)
				end

				self:PopAnalyzerEnvironment()
			else
				self:FatalError("unhandled statement: " .. statement.kind)
			end
		end,
	}	
end)("./nattlua/analyzer/statements/function.lua");
package.loaded["nattlua.analyzer.statements.if"] = (function(...)
	local ipairs = ipairs
	local Union = require("nattlua.types.union").Union

	local function contains_ref_argument(upvalues)
		for _, v in pairs(upvalues) do
			if v.upvalue:GetValue().ref_argument or v.upvalue:GetValue().from_for_loop then
				return true
			end
		end

		return false
	end

	return {
		AnalyzeIf = function(self, statement)
			local prev_expression
			local blocks = {}

			for i, statements in ipairs(statement.statements) do
				if statement.expressions[i] then
					self.current_if_statement = statement
					local exp = statement.expressions[i]
					local no_operator_expression = exp.kind ~= "binary_operator" and
						exp.kind ~= "prefix_operator" or
						(
							exp.kind == "binary_operator" and
							exp.value.value == "."
						)

					if no_operator_expression then self:PushTruthyExpressionContext() end

					local obj = self:AnalyzeExpression(exp)

					if no_operator_expression then self:PopTruthyExpressionContext() end

					if no_operator_expression then
						-- track "if x then" which has no binary or prefix operators
						self:TrackUpvalue(obj)
					end

					self.current_if_statement = nil
					prev_expression = obj

					if obj:IsTruthy() then
						local upvalues = self:GetTrackedUpvalues()
						local tables = self:GetTrackedTables()
						self:ClearTracked()
						table.insert(
							blocks,
							{
								statements = statements,
								upvalues = upvalues,
								tables = tables,
								expression = obj,
							}
						)

						if obj:IsCertainlyTrue() and self:IsRuntime() then
							if not contains_ref_argument(upvalues) then
								self:Warning(exp, "if condition is always true")
							end
						end

						if not obj:IsFalsy() then break end
					end

					if obj:IsCertainlyFalse() and self:IsRuntime() then
						if not contains_ref_argument(self:GetTrackedUpvalues()) then
							self:Warning(exp, "if condition is always false")
						end
					end
				else
					if prev_expression:IsCertainlyFalse() and self:IsRuntime() then
						if not contains_ref_argument(self:GetTrackedUpvalues()) then
							self:Warning(statement.expressions[i - 1], "else part of if condition is always true")
						end
					end

					if prev_expression:IsFalsy() then
						table.insert(
							blocks,
							{
								statements = statements,
								upvalues = blocks[#blocks] and blocks[#blocks].upvalues,
								tables = blocks[#blocks] and blocks[#blocks].tables,
								expression = prev_expression,
								is_else = true,
							}
						)
					end
				end
			end

			local last_scope

			for i, block in ipairs(blocks) do
				local scope = self:PushConditionalScope(statement, block.expression:IsTruthy(), block.expression:IsFalsy())

				if last_scope then
					last_scope:SetNextConditionalSibling(scope)
					scope:SetPreviousConditionalSibling(last_scope)
				end

				last_scope = scope
				scope:SetTrackedUpvalues(block.upvalues)
				scope:SetTrackedTables(block.tables)

				if block.is_else then
					scope:SetElseConditionalScope(true)
					self:ApplyMutationsInIfElse(blocks)
				else
					self:ApplyMutationsInIf(block.upvalues, block.tables)
				end

				self:AnalyzeStatements(block.statements)
				self:PopConditionalScope()
			end

			self:ClearTracked()
		end,
	}	
end)("./nattlua/analyzer/statements/if.lua");
package.loaded["nattlua.analyzer.statements.do"] = (function(...)
	return {
		AnalyzeDo = function(self, statement)
			self:CreateAndPushScope()
			self:AnalyzeStatements(statement.statements)
			self:PopScope()
		end,
	}	
end)("./nattlua/analyzer/statements/do.lua");
package.loaded["nattlua.analyzer.statements.generic_for"] = (function(...)
	local table = require("table")
	local ipairs = ipairs
	local Tuple = require("nattlua.types.tuple").Tuple
	local Union = require("nattlua.types.union").Union
	local Nil = require("nattlua.types.symbol").Nil
	return {
		AnalyzeGenericFor = function(self, statement)
			local args = self:AnalyzeExpressions(statement.expressions)
			local callable_iterator = table.remove(args, 1)

			if not callable_iterator then return end

			if callable_iterator.Type == "tuple" then
				callable_iterator = callable_iterator:Get(1)
			end

			local returned_key = nil
			local one_loop = callable_iterator and callable_iterator.Type == "any"
			local uncertain_break = nil

			for i = 1, 1000 do
				local values = self:Assert(statement.expressions[1], self:Call(callable_iterator, Tuple(args), statement.expressions[1]))

				if
					not values:Get(1) or
					values:Get(1).Type == "symbol" and
					values:Get(1):GetData() == nil
				then
					break
				end

				if i == 1 then
					returned_key = values:Get(1)

					if not returned_key:IsLiteral() then
						returned_key = Union({Nil(), returned_key})
					end

					self:PushConditionalScope(statement, returned_key:IsTruthy(), returned_key:IsFalsy())
					self:PushUncertainLoop(false)
				end

				local brk = false

				for i, identifier in ipairs(statement.identifiers) do
					local obj = self:Assert(identifier, values:Get(i))

					if uncertain_break then
						obj:SetLiteral(false)
						brk = true
					end

					obj.from_for_loop = true
					self:CreateLocalValue(identifier.value.value, obj)
				end

				self:AnalyzeStatements(statement.statements)

				if self._continue_ then self._continue_ = nil end

				if self.break_out_scope then
					if self.break_out_scope:IsUncertain() then
						uncertain_break = true
					else
						brk = true
					end

					self.break_out_scope = nil
				end

				if i == 1000 then self:Error(statement, "too many iterations") end

				table.insert(values:GetData(), 1, args[1])
				args = values:GetData()

				if one_loop then break end

				if brk then break end
			end

			if returned_key then
				self:PopConditionalScope()
				self:PopUncertainLoop()
			end
		end,
	}	
end)("./nattlua/analyzer/statements/generic_for.lua");
package.loaded["nattlua.analyzer.statements.call_expression"] = (function(...)
	return {
		AnalyzeCall = function(self, statement)
			self:AnalyzeExpression(statement.value)
		end,
	}	
end)("./nattlua/analyzer/statements/call_expression.lua");
package.loaded["nattlua.analyzer.operators.binary"] = (function(...)
	local tostring = tostring
	local ipairs = ipairs
	local table = require("table")
	local LString = require("nattlua.types.string").LString
	local String = require("nattlua.types.string").String
	local Any = require("nattlua.types.any").Any
	local Tuple = require("nattlua.types.tuple").Tuple
	local Union = require("nattlua.types.union").Union
	local True = require("nattlua.types.symbol").True
	local Boolean = require("nattlua.types.symbol").Boolean
	local Symbol = require("nattlua.types.symbol").Symbol
	local False = require("nattlua.types.symbol").False
	local Nil = require("nattlua.types.symbol").Nil
	local type_errors = require("nattlua.types.error_messages")

	local function metatable_function(self, node, meta_method, l, r)
		meta_method = LString(meta_method)

		if r:GetMetaTable() or l:GetMetaTable() then
			local func = (
					l:GetMetaTable() and
					l:GetMetaTable():Get(meta_method)
				) or
				(
					r:GetMetaTable() and
					r:GetMetaTable():Get(meta_method)
				)

			if not func then return end

			if func.Type ~= "function" then return func end

			return self:Assert(node, self:Call(func, Tuple({l, r}))):Get(1)
		end
	end

	local function operator(self, node, l, r, op, meta_method)
		if op == ".." then
			if
				(
					l.Type == "string" and
					r.Type == "string"
				)
				or
				(
					l.Type == "number" and
					r.Type == "string"
				)
				or
				(
					l.Type == "number" and
					r.Type == "number"
				)
				or
				(
					l.Type == "string" and
					r.Type == "number"
				)
			then
				if l:IsLiteral() and r:IsLiteral() then
					return LString(l:GetData() .. r:GetData()):SetNode(node)
				end

				return String():SetNode(node)
			end
		end

		if l.Type == "number" and r.Type == "number" then
			return l:ArithmeticOperator(r, op):SetNode(node)
		else
			return metatable_function(self, node, meta_method, l, r)
		end

		return type_errors.binary(op, l, r)
	end

	local function logical_cmp_cast(val--[[#: boolean | nil]], err--[[#: string | nil]])
		if err then return val, err end

		if val == nil then
			return Boolean()
		elseif val == true then
			return True()
		elseif val == false then
			return False()
		end
	end

	local function Binary(self, node, l, r, op)
		op = op or node.value.value
		local cur_union

		if op == "|" and self:IsTypesystem() then
			cur_union = Union()
			self:PushCurrentType(cur_union, "union")
		end

		if not l and not r then
			if node.value.value == "and" then
				l = self:AnalyzeExpression(node.left)

				if l:IsCertainlyFalse() then
					r = Nil():SetNode(node.right)
				else
					-- if a and a.foo then
					-- ^ no binary operator means that it was just checked simply if it was truthy
					if node.left.kind ~= "binary_operator" or node.left.value.value ~= "." then
						self:TrackUpvalue(l)
					end

					-- right hand side of and is the "true" part
					self:PushTruthyExpressionContext()
					r = self:AnalyzeExpression(node.right)
					self:PopTruthyExpressionContext()

					if node.right.kind ~= "binary_operator" or node.right.value.value ~= "." then
						self:TrackUpvalue(r)
					end
				end
			elseif node.value.value == "or" then
				self:PushFalsyExpressionContext()
				l = self:AnalyzeExpression(node.left)
				self:PopFalsyExpressionContext()

				if l:IsCertainlyFalse() then
					self:PushFalsyExpressionContext()
					r = self:AnalyzeExpression(node.right)
					self:PopFalsyExpressionContext()
				elseif l:IsCertainlyTrue() then
					r = Nil():SetNode(node.right)
				else
					-- right hand side of or is the "false" part
					self:PushFalsyExpressionContext()
					r = self:AnalyzeExpression(node.right)
					self:PopFalsyExpressionContext()
				end
			else
				l = self:AnalyzeExpression(node.left)
				r = self:AnalyzeExpression(node.right)
			end

			self:TrackUpvalueNonUnion(l)
			self:TrackUpvalueNonUnion(r)

			-- TODO: more elegant way of dealing with self?
			if op == ":" then
				self.self_arg_stack = self.self_arg_stack or {}
				table.insert(self.self_arg_stack, l)
			end
		end

		if cur_union then self:PopCurrentType("union") end

		if self:IsTypesystem() then
			if op == "|" then
				cur_union:AddType(l)
				cur_union:AddType(r)
				return cur_union
			elseif op == "==" then
				return l:Equal(r) and True() or False()
			elseif op == "~" then
				if l.Type == "union" then return l:RemoveType(r) end

				return l
			elseif op == "&" or op == "extends" then
				if l.Type ~= "table" then
					return false, "type " .. tostring(l) .. " cannot be extended"
				end

				return l:Extend(r)
			elseif op == ".." then
				if l.Type == "tuple" and r.Type == "tuple" then
					return l:Copy():Concat(r)
				elseif l.Type == "string" and r.Type == "string" then
					return LString(l:GetData() .. r:GetData())
				else
					return l:Copy():SetMax(r)
				end
			elseif op == "*" then
				if l.Type == "tuple" and r.Type == "number" and r:IsLiteral() then
					return l:Copy():SetRepeat(r:GetData())
				end
			elseif op == ">" or op == "supersetof" then
				return Symbol((r:IsSubsetOf(l)))
			elseif op == "<" or op == "subsetof" then
				return Symbol((l:IsSubsetOf(r)))
			elseif op == "+" then
				if l.Type == "table" and r.Type == "table" then return l:Union(r) end
			end
		end

		-- adding two tuples at runtime in lua will basically do this
		if self:IsRuntime() then
			if l.Type == "tuple" then l = self:Assert(node, l:GetFirstValue()) end

			if r.Type == "tuple" then r = self:Assert(node, r:GetFirstValue()) end
		end

		do -- union unpacking
			-- normalize l and r to be both unions to reduce complexity
			if l.Type ~= "union" and r.Type == "union" then l = Union({l}) end

			if l.Type == "union" and r.Type ~= "union" then r = Union({r}) end

			if l.Type == "union" and r.Type == "union" then
				local new_union = Union()
				local truthy_union = Union():SetUpvalue(l:GetUpvalue())
				local falsy_union = Union():SetUpvalue(l:GetUpvalue())

				if op == "~=" then self.inverted_index_tracking = true end

				local type_checked = self.type_checked

				-- the return value from type(x)
				if type_checked then self.type_checked = nil end

				for _, l in ipairs(l:GetData()) do
					for _, r in ipairs(r:GetData()) do
						local res, err = Binary(self, node, l, r, op)

						if not res then
							self:ErrorAndCloneCurrentScope(node, err, l) -- TODO, only left side?
						else
							if res:IsTruthy() then
								if type_checked then
									for _, t in ipairs(type_checked:GetData()) do
										if t.GetLuaType and t:GetLuaType() == l:GetData() then
											truthy_union:AddType(t)
										end
									end
								else
									truthy_union:AddType(l)
								end
							end

							if res:IsFalsy() then
								if type_checked then
									for _, t in ipairs(type_checked:GetData()) do
										if t.GetLuaType and t:GetLuaType() == l:GetData() then
											falsy_union:AddType(t)
										end
									end
								else
									falsy_union:AddType(l)
								end
							end

							new_union:AddType(res)
						end
					end
				end

				if op == "~=" then self.inverted_index_tracking = nil end

				if op ~= "or" and op ~= "and" then
					local parent_table = l.parent_table or type_checked and type_checked.parent_table
					local parent_key = l.parent_key or type_checked and type_checked.parent_key

					if parent_table then
						self:TrackTableIndexUnion(parent_table, parent_key, truthy_union, falsy_union)
					elseif l.Type == "union" then
						for _, l in ipairs(l:GetData()) do
							if l.parent_table then
								self:TrackTableIndexUnion(l.parent_table, l.parent_key, truthy_union, falsy_union)
							end
						end
					end

					self:TrackUpvalue(l, truthy_union, falsy_union, op == "~=")
					self:TrackUpvalue(r, truthy_union, falsy_union, op == "~=")
				end

				return new_union:SetNode(node)
			end
		end

		if l.Type == "any" or r.Type == "any" then return Any() end

		do -- arithmetic operators
			if op == "." or op == ":" then
				return self:IndexOperator(node, l, r)
			elseif op == "+" then
				local val = operator(self, node, l, r, op, "__add")

				if val then return val end
			elseif op == "-" then
				local val = operator(self, node, l, r, op, "__sub")

				if val then return val end
			elseif op == "*" then
				local val = operator(self, node, l, r, op, "__mul")

				if val then return val end
			elseif op == "/" then
				local val = operator(self, node, l, r, op, "__div")

				if val then return val end
			elseif op == "/idiv/" then
				local val = operator(self, node, l, r, op, "__idiv")

				if val then return val end
			elseif op == "%" then
				local val = operator(self, node, l, r, op, "__mod")

				if val then return val end
			elseif op == "^" then
				local val = operator(self, node, l, r, op, "__pow")

				if val then return val end
			elseif op == "&" then
				local val = operator(self, node, l, r, op, "__band")

				if val then return val end
			elseif op == "|" then
				local val = operator(self, node, l, r, op, "__bor")

				if val then return val end
			elseif op == "~" then
				local val = operator(self, node, l, r, op, "__bxor")

				if val then return val end
			elseif op == "<<" then
				local val = operator(self, node, l, r, op, "__lshift")

				if val then return val end
			elseif op == ">>" then
				local val = operator(self, node, l, r, op, "__rshift")

				if val then return val end
			elseif op == ".." then
				local val = operator(self, node, l, r, op, "__concat")

				if val then return val end
			end
		end

		do -- logical operators
			if op == "==" then
				local res = metatable_function(self, node, "__eq", l, r)

				if res then return res end

				if l:IsLiteral() and l == r then return True() end

				if l.Type ~= r.Type then return False() end

				return logical_cmp_cast(l.LogicalComparison(l, r, op, self:GetCurrentAnalyzerEnvironment()))
			elseif op == "~=" or op == "!=" then
				local res = metatable_function(self, node, "__eq", l, r)

				if res then
					if res:IsLiteral() then res:SetData(not res:GetData()) end

					return res
				end

				if l.Type ~= r.Type then return True() end

				local val, err = l.LogicalComparison(l, r, "==", self:GetCurrentAnalyzerEnvironment())

				if val ~= nil then val = not val end

				return logical_cmp_cast(val, err)
			elseif op == "<" then
				local res = metatable_function(self, node, "__lt", l, r)

				if res then return res end

				return logical_cmp_cast(l.LogicalComparison(l, r, op))
			elseif op == "<=" then
				local res = metatable_function(self, node, "__le", l, r)

				if res then return res end

				return logical_cmp_cast(l.LogicalComparison(l, r, op))
			elseif op == ">" then
				local res = metatable_function(self, node, "__lt", l, r)

				if res then return res end

				return logical_cmp_cast(l.LogicalComparison(l, r, op))
			elseif op == ">=" then
				local res = metatable_function(self, node, "__le", l, r)

				if res then return res end

				return logical_cmp_cast(l.LogicalComparison(l, r, op))
			elseif op == "or" or op == "||" then
				-- boolean or boolean
				if l:IsUncertain() or r:IsUncertain() then return Union({l, r}) end

				-- true or boolean
				if l:IsTruthy() then return l:Copy():SetNode(node) end

				-- false or true
				if r:IsTruthy() then return r:Copy():SetNode(node) end

				return r:Copy():SetNode(node)
			elseif op == "and" or op == "&&" then
				-- true and false
				if l:IsTruthy() and r:IsFalsy() then
					if l:IsFalsy() or r:IsTruthy() then return Union({l, r}) end

					return r:Copy():SetNode(node)
				end

				-- false and true
				if l:IsFalsy() and r:IsTruthy() then
					if l:IsTruthy() or r:IsFalsy() then return Union({l, r}) end

					return l:Copy():SetNode(node)
				end

				-- true and true
				if l:IsTruthy() and r:IsTruthy() then
					if l:IsFalsy() and r:IsFalsy() then return Union({l, r}) end

					return r:Copy():SetNode(node)
				else
					-- false and false
					if l:IsTruthy() and r:IsTruthy() then return Union({l, r}) end

					return l:Copy():SetNode(node)
				end
			end
		end

		return type_errors.binary(op, l, r)
	end

	return {Binary = Binary}	
end)("./nattlua/analyzer/operators/binary.lua");
package.loaded["nattlua.analyzer.statements.numeric_for"] = (function(...)
	local ipairs = ipairs
	local math = math
	local assert = assert
	local True = require("nattlua.types.symbol").True
	local LNumber = require("nattlua.types.number").LNumber
	local False = require("nattlua.types.symbol").False
	local Union = require("nattlua.types.union").Union
	local Binary = require("nattlua.analyzer.operators.binary").Binary

	local function get_largest_number(obj)
		if obj:IsLiteral() then
			if obj.Type == "union" then
				local max = -math.huge

				for _, v in ipairs(obj:GetData()) do
					max = math.max(max, v:GetData())
				end

				return max
			end

			return obj:GetData()
		end
	end

	return {
		AnalyzeNumericFor = function(self, statement)
			local init = self:AnalyzeExpression(statement.expressions[1]):GetFirstValue()
			local max = self:AnalyzeExpression(statement.expressions[2]):GetFirstValue()
			local step = statement.expressions[3] and
				self:AnalyzeExpression(statement.expressions[3]):GetFirstValue() or
				nil

			if step then assert(step.Type == "number") end

			local literal_init = get_largest_number(init)
			local literal_max = get_largest_number(max)
			local literal_step = not step and 1 or get_largest_number(step)
			local condition = Union()

			if literal_init and literal_max then
				-- also check step
				condition:AddType(Binary(self, statement, init, max, "<="))
			else
				condition:AddType(True())
				condition:AddType(False())
			end

			self:PushConditionalScope(statement, condition:IsTruthy(), condition:IsFalsy())

			if literal_init and literal_max and literal_step and literal_max < 1000 then
				local uncertain_break = false

				for i = literal_init, literal_max, literal_step do
					self:PushConditionalScope(statement, condition:IsTruthy(), condition:IsFalsy())
					local i = LNumber(i):SetNode(statement.expressions[1])
					local brk = false

					if uncertain_break then
						i:SetLiteral(false)
						brk = true
					end

					i.from_for_loop = true
					self:CreateLocalValue(statement.identifiers[1].value.value, i)
					self:AnalyzeStatements(statement.statements)

					if self._continue_ then self._continue_ = nil end

					if self.break_out_scope then
						if self.break_out_scope:IsUncertain() then
							uncertain_break = true
						else
							brk = true
						end

						self.break_out_scope = nil
					end

					self:PopConditionalScope()

					if brk then break end
				end
			else
				if literal_init then
					init = LNumber(literal_init)
					init.dont_widen = true

					if max.Type == "number" or (max.Type == "union" and max:IsType("number")) then
						if not max:IsLiteral() then
							init:SetMax(LNumber(math.huge))
						else
							init:SetMax(max)
						end
					end
				else
					if
						init.Type == "number" and
						(
							max.Type == "number" or
							(
								max.Type == "union" and
								max:IsType("number")
							)
						)
					then
						init = self:Assert(statement.expressions[1], init:SetMax(max))
					end

					if max.Type == "any" then init:SetLiteral(false) end
				end

				self:PushUncertainLoop(true)
				local range = self:Assert(statement.expressions[1], init)
				self:CreateLocalValue(statement.identifiers[1].value.value, range)
				self:AnalyzeStatements(statement.statements)
				self:PopUncertainLoop()
			end

			self.break_out_scope = nil
			self:PopConditionalScope()
		end,
	}	
end)("./nattlua/analyzer/statements/numeric_for.lua");
package.loaded["nattlua.analyzer.statements.break"] = (function(...)
	return {
		AnalyzeBreak = function(self, statement)
			self.break_out_scope = self:GetScope()
			self.break_loop = true
		end,
	}	
end)("./nattlua/analyzer/statements/break.lua");
package.loaded["nattlua.analyzer.statements.continue"] = (function(...)
	return {
		AnalyzeContinue = function(self, statement)
			self._continue_ = true
		end,
	}	
end)("./nattlua/analyzer/statements/continue.lua");
package.loaded["nattlua.analyzer.statements.repeat"] = (function(...)
	return {
		AnalyzeRepeat = function(self, statement)
			self:CreateAndPushScope()
			self:AnalyzeStatements(statement.statements)
			self:PopScope()
		end,
	}	
end)("./nattlua/analyzer/statements/repeat.lua");
package.loaded["nattlua.analyzer.statements.return"] = (function(...)
	local Nil = require("nattlua.types.symbol").Nil
	return {
		AnalyzeReturn = function(self, statement)
			local ret = self:AnalyzeExpressions(statement.expressions)
			self:Return(statement, ret)
		end,
	}	
end)("./nattlua/analyzer/statements/return.lua");
package.loaded["nattlua.analyzer.statements.analyzer_debug_code"] = (function(...)
	return {
		AnalyzeAnalyzerDebugCode = function(self, statement)
			local code = statement.lua_code.value.value:sub(3)
			self:CallLuaTypeFunction(
				statement.lua_code,
				self:CompileLuaAnalyzerDebugCode(code, statement.lua_code),
				self:GetScope()
			)
		end,
	}	
end)("./nattlua/analyzer/statements/analyzer_debug_code.lua");
package.loaded["nattlua.analyzer.statements.while"] = (function(...)
	return {
		AnalyzeWhile = function(self, statement)
			local obj = self:AnalyzeExpression(statement.expression)
			local upvalues = self:GetTrackedUpvalues()
			local tables = self:GetTrackedTables()
			self:ClearTracked()

			if obj:IsCertainlyFalse() then
				self:Warning(statement.expression, "loop expression is always false")
			end

			if obj:IsTruthy() then
				self:ApplyMutationsInIf(upvalues, tables)

				for i = 1, 32 do
					self:PushConditionalScope(statement, obj:IsTruthy(), obj:IsFalsy())
					self:PushUncertainLoop(obj:IsTruthy() and obj:IsFalsy())
					self:AnalyzeStatements(statement.statements)
					self:PopUncertainLoop()
					self:PopConditionalScope()

					if self.break_out_scope then
						self.break_out_scope = nil

						break
					end

					if self:GetScope():DidCertainReturn() then break end

					local obj = self:AnalyzeExpression(statement.expression)

					if obj:IsUncertain() or obj:IsFalsy() then break end

					if i == 32 then self:Error(statement, "too many iterations") end
				end
			end
		end,
	}	
end)("./nattlua/analyzer/statements/while.lua");
package.loaded["nattlua.analyzer.expressions.binary_operator"] = (function(...)
	local table = require("table")
	local Binary = require("nattlua.analyzer.operators.binary").Binary
	local Nil = require("nattlua.types.symbol").Nil
	local assert = _G.assert
	return {
		AnalyzeBinaryOperator = function(self, node)
			return self:Assert(node, Binary(self, node))
		end,
	}	
end)("./nattlua/analyzer/expressions/binary_operator.lua");
package.loaded["nattlua.analyzer.operators.prefix"] = (function(...)
	local ipairs = ipairs
	local error = error
	local tostring = tostring
	local Union = require("nattlua.types.union").Union
	local Nil = require("nattlua.types.symbol").Nil
	local type_errors = require("nattlua.types.error_messages")
	local LString = require("nattlua.types.string").LString
	local Boolean = require("nattlua.types.symbol").Boolean
	local False = require("nattlua.types.symbol").False
	local True = require("nattlua.types.symbol").True
	local Any = require("nattlua.types.any").Any
	local Tuple = require("nattlua.types.tuple").Tuple

	local function metatable_function(self, meta_method, l)
		if l:GetMetaTable() then
			meta_method = LString(meta_method)
			local func = l:GetMetaTable():Get(meta_method)

			if func then
				return self:Assert(l:GetNode(), self:Call(func, Tuple({l})):Get(1))
			end
		end
	end

	local function Prefix(self, node, r)
		local op = node.value.value

		if op == "not" then
			self.inverted_index_tracking = not self.inverted_index_tracking
		end

		if not r then
			r = self:AnalyzeExpression(node.right)

			if node.right.kind ~= "binary_operator" or node.right.value.value ~= "." then
				if r.Type ~= "union" then self:TrackUpvalue(r, nil, nil, op == "not") end
			end
		end

		if op == "not" then self.inverted_index_tracking = nil end

		if op == "literal" then
			r.literal_argument = true
			return r
		end

		if op == "ref" then
			r.ref_argument = true
			return r
		end

		if r.Type == "tuple" then r = r:Get(1) or Nil() end

		if r.Type == "union" then
			local new_union = Union()
			local truthy_union = Union():SetUpvalue(r:GetUpvalue())
			local falsy_union = Union():SetUpvalue(r:GetUpvalue())

			for _, r in ipairs(r:GetData()) do
				local res, err = Prefix(self, node, r)

				if not res then
					self:ErrorAndCloneCurrentScope(node, err, r)
					falsy_union:AddType(r)
				else
					new_union:AddType(res)

					if res:IsTruthy() then truthy_union:AddType(r) end

					if res:IsFalsy() then falsy_union:AddType(r) end
				end
			end

			self:TrackUpvalue(r, truthy_union, falsy_union)
			return new_union:SetNode(node)
		end

		if r.Type == "any" then return Any():SetNode(node) end

		if self:IsTypesystem() then
			if op == "typeof" then
				self:PushAnalyzerEnvironment("runtime")
				local obj = self:AnalyzeExpression(node.right)
				self:PopAnalyzerEnvironment()

				if not obj then
					return type_errors.other("cannot find '" .. node.right:Render() .. "' in the current typesystem scope")
				end

				return obj:GetContract() or obj
			elseif op == "unique" then
				r:MakeUnique(true)
				return r
			elseif op == "mutable" then
				r.mutable = true
				return r
			elseif op == "expand" then
				r.expand = true
				return r
			elseif op == "$" then
				if r.Type ~= "string" then
					return type_errors.other("must evaluate to a string")
				end

				if not r:IsLiteral() then return type_errors.other("must be a literal") end

				r:SetPatternContract(r:GetData())
				return r
			end
		end

		if op == "-" then
			local res = metatable_function(self, "__unm", r)

			if res then return res end
		elseif op == "~" then
			local res = metatable_function(self, "__bxor", r)

			if res then return res end
		elseif op == "#" then
			local res = metatable_function(self, "__len", r)

			if res then return res end
		end

		if op == "not" or op == "!" then
			if r:IsTruthy() and r:IsFalsy() then
				return Boolean():SetNode(node)
			elseif r:IsTruthy() then
				return False():SetNode(node)
			elseif r:IsFalsy() then
				return True():SetNode(node)
			end
		end

		if op == "-" or op == "~" or op == "#" then
			if r.Type == "table" then return r:GetLength() end

			return r:PrefixOperator(op)
		end

		error("unhandled prefix operator in " .. self:GetCurrentAnalyzerEnvironment() .. ": " .. op .. tostring(r))
	end

	return {Prefix = Prefix}	
end)("./nattlua/analyzer/operators/prefix.lua");
package.loaded["nattlua.analyzer.expressions.prefix_operator"] = (function(...)
	local Prefix = require("nattlua.analyzer.operators.prefix").Prefix
	return {
		AnalyzePrefixOperator = function(self, node)
			return self:Assert(node, Prefix(self, node))
		end,
	}	
end)("./nattlua/analyzer/expressions/prefix_operator.lua");
package.loaded["nattlua.analyzer.operators.postfix"] = (function(...)
	local Binary = require("nattlua.analyzer.operators.binary").Binary
	local Node = require("nattlua.parser.node")
	return {
		Postfix = function(self, node, r)
			local op = node.value.value

			if op == "++" then
				return Binary(self, setmetatable({value = {value = "+"}}, Node), r, r)
			end
		end,
	}	
end)("./nattlua/analyzer/operators/postfix.lua");
package.loaded["nattlua.analyzer.expressions.postfix_operator"] = (function(...)
	local Postfix = require("nattlua.analyzer.operators.postfix").Postfix
	return {
		AnalyzePostfixOperator = function(self, node)
			return self:Assert(node, Postfix(self, node, self:AnalyzeExpression(node.left)))
		end,
	}	
end)("./nattlua/analyzer/expressions/postfix_operator.lua");
package.loaded["nattlua.analyzer.expressions.postfix_call"] = (function(...)
	local table = require("table")
	local NormalizeTuples = require("nattlua.types.tuple").NormalizeTuples
	local Tuple = require("nattlua.types.tuple").Tuple
	return {
		AnalyzePostfixCall = function(self, node)
			local is_type_call = node.type_call or
				node.left and
				(
					node.left.kind == "local_generics_type_function" or
					node.left.kind == "generics_type_function"
				)
			self:PushAnalyzerEnvironment(is_type_call and "typesystem" or "runtime")
			local callable = self:AnalyzeExpression(node.left)
			local self_arg

			if
				self.self_arg_stack and
				node.left.kind == "binary_operator" and
				node.left.value.value == ":"
			then
				self_arg = table.remove(self.self_arg_stack)
			end

			local types = self:AnalyzeExpressions(node.expressions)

			if self_arg then table.insert(types, 1, self_arg) end

			local arguments

			if self:IsTypesystem() then
				arguments = Tuple(types)
			else
				arguments = NormalizeTuples(types)
			end

			local returned_tuple = self:Assert(node, self:Call(callable, arguments, node))

			-- TUPLE UNPACK MESS
			if node.tokens["("] and node.tokens[")"] and returned_tuple.Type == "tuple" then
				returned_tuple = returned_tuple:Get(1)
			end

			if self:IsTypesystem() then
				if returned_tuple.Type == "tuple" and returned_tuple:GetLength() == 1 then
					returned_tuple = returned_tuple:Get(1)
				end
			end

			self:PopAnalyzerEnvironment()
			return returned_tuple
		end,
	}	
end)("./nattlua/analyzer/expressions/postfix_call.lua");
package.loaded["nattlua.analyzer.expressions.postfix_index"] = (function(...)
	return {
		AnalyzePostfixIndex = function(self, node)
			return self:Assert(
				node,
				self:IndexOperator(
					node,
					self:AnalyzeExpression(node.left),
					self:AnalyzeExpression(node.expression):GetFirstValue()
				)
			)
		end,
	}	
end)("./nattlua/analyzer/expressions/postfix_index.lua");
package.loaded["nattlua.analyzer.expressions.table"] = (function(...)
	local tostring = tostring
	local ipairs = ipairs
	local LNumber = require("nattlua.types.number").LNumber
	local LString = require("nattlua.types.string").LString
	local Table = require("nattlua.types.table").Table
	local table = require("table")
	return {
		AnalyzeTable = function(self, node)
			local tbl = Table():SetNode(node):SetLiteral(self:IsTypesystem())

			if self:IsRuntime() then tbl:SetReferenceId(tostring(tbl:GetData())) end

			self:PushCurrentType(tbl, "table")
			local tree = node
			tbl.scope = self:GetScope()

			for i, node in ipairs(node.children) do
				if node.kind == "table_key_value" then
					local key = LString(node.tokens["identifier"].value):SetNode(node.tokens["identifier"])
					local val = self:AnalyzeExpression(node.value_expression):GetFirstValue()
					self:NewIndexOperator(node, tbl, key, val)
				elseif node.kind == "table_expression_value" then
					local key = self:AnalyzeExpression(node.key_expression):GetFirstValue()
					local val = self:AnalyzeExpression(node.value_expression):GetFirstValue()
					self:NewIndexOperator(node, tbl, key, val)
				elseif node.kind == "table_index_value" then
					local obj = self:AnalyzeExpression(node.value_expression)

					if
						node.value_expression.kind ~= "value" or
						node.value_expression.value.value ~= "..."
					then
						obj = obj:GetFirstValue()
					end

					if obj.Type == "tuple" then
						if tree.children[i + 1] then
							tbl:Insert(obj:Get(1))
						else
							for i = 1, obj:GetMinimumLength() do
								tbl:Set(LNumber(#tbl:GetData() + 1), obj:Get(i))
							end

							if obj.Remainder then
								local current_index = LNumber(#tbl:GetData() + 1)
								local max = LNumber(obj.Remainder:GetLength())
								tbl:Set(current_index:SetMax(max), obj.Remainder:Get(1))
							end
						end
					else
						if node.i then
							tbl:Insert(LNumber(obj))
						elseif obj then
							tbl:Insert(obj)
						end
					end
				end

				self:ClearTracked()
			end

			self:PopCurrentType("table")
			return tbl
		end,
	}	
end)("./nattlua/analyzer/expressions/table.lua");
package.loaded["nattlua.analyzer.expressions.atomic_value"] = (function(...)
	local runtime_syntax = require("nattlua.syntax.runtime")
	local NodeToString = require("nattlua.types.string").NodeToString
	local LNumber = require("nattlua.types.number").LNumber
	local LNumberFromString = require("nattlua.types.number").LNumberFromString
	local Any = require("nattlua.types.any").Any
	local True = require("nattlua.types.symbol").True
	local False = require("nattlua.types.symbol").False
	local Nil = require("nattlua.types.symbol").Nil
	local LString = require("nattlua.types.string").LString
	local String = require("nattlua.types.string").String
	local Number = require("nattlua.types.number").Number
	local Boolean = require("nattlua.types.symbol").Boolean
	local table = require("table")

	local function lookup_value(self, node)
		local errors = {}
		local key = NodeToString(node)
		local obj, err = self:GetLocalOrGlobalValue(key)

		if self:IsTypesystem() then
			-- we fallback to runtime if we can't find the value in the typesystem
			if not obj then
				table.insert(errors, err)
				self:PushAnalyzerEnvironment("runtime")
				obj, err = self:GetLocalOrGlobalValue(key)
				self:PopAnalyzerEnvironment("runtime")

				-- when in the typesystem we want to see the objects contract, not its runtime value
				if obj and obj:GetContract() then obj = obj:GetContract() end
			end

			if not obj then
				table.insert(errors, err)
				self:Error(node, errors)
				return Nil()
			end
		else
			if not obj or (obj.Type == "symbol" and obj:GetData() == nil) then
				self:PushAnalyzerEnvironment("typesystem")
				local objt, errt = self:GetLocalOrGlobalValue(key)
				self:PopAnalyzerEnvironment()

				if objt then obj, err = objt, errt end
			end

			if not obj then
				self:Warning(node, err)
				obj = Any():SetNode(node)
			end
		end

		return self:GetTrackedUpvalue(obj) or obj
	end

	local function is_primitive(val)
		return val == "string" or
			val == "number" or
			val == "boolean" or
			val == "true" or
			val == "false" or
			val == "nil"
	end

	return {
		AnalyzeAtomicValue = function(self, node)
			local value = node.value.value
			local type = runtime_syntax:GetTokenType(node.value)

			if type == "keyword" then
				if value == "nil" then
					return Nil():SetNode(node)
				elseif value == "true" then
					return True():SetNode(node)
				elseif value == "false" then
					return False():SetNode(node)
				end
			end

			-- this means it's the first part of something, either >true<, >foo<.bar, >foo<()
			local standalone_letter = type == "letter" and node.standalone_letter

			if self:IsTypesystem() and standalone_letter and not node.force_upvalue then
				if value == "current_table" then
					return self:GetCurrentType("table")
				elseif value == "current_tuple" then
					return self:GetCurrentType("tuple")
				elseif value == "current_function" then
					return self:GetCurrentType("function")
				elseif value == "current_union" then
					return self:GetCurrentType("union")
				end

				local current_table = self:GetCurrentType("table")

				if current_table then
					if value == "self" then
						return current_table
					elseif
						self.left_assigned and
						self.left_assigned:GetData() == value and
						not is_primitive(value)
					then
						return current_table
					end
				end

				if value == "any" then
					return Any():SetNode(node)
				elseif value == "inf" then
					return LNumber(math.huge):SetNode(node)
				elseif value == "nan" then
					return LNumber(0 / 0):SetNode(node)
				elseif value == "string" then
					return String():SetNode(node)
				elseif value == "number" then
					return Number():SetNode(node)
				elseif value == "boolean" then
					return Boolean():SetNode(node)
				end
			end

			if standalone_letter or value == "..." or node.force_upvalue then
				local val = lookup_value(self, node)

				if val:GetUpvalue() then
					self:GetScope():AddDependency(val:GetUpvalue())
				end

				return val
			end

			if type == "number" then
				local num = LNumberFromString(value)

				if not num then
					self:Error(node, "unable to convert " .. value .. " to number")
					num = Number()
				end

				num:SetNode(node)
				return num
			elseif type == "string" then
				return LString(node.value.string_value):SetNode(node)
			elseif type == "letter" then
				return LString(value):SetNode(node)
			end

			self:FatalError("unhandled value type " .. type .. " " .. node:Render())
		end,
	}	
end)("./nattlua/analyzer/expressions/atomic_value.lua");
package.loaded["nattlua.analyzer.expressions.import"] = (function(...)
	local table = require("table")
	return {
		AnalyzeImport = function(self, node)
			local args = self:AnalyzeExpressions(node.expressions)
			return self:AnalyzeRootStatement(node.root, table.unpack(args))
		end,
	}	
end)("./nattlua/analyzer/expressions/import.lua");
package.loaded["nattlua.analyzer.expressions.tuple"] = (function(...)
	local Tuple = require("nattlua.types.tuple").Tuple
	return {
		AnalyzeTuple = function(self, node)
			local tup = Tuple():SetNode(node):SetUnpackable(true)
			self:PushCurrentType(tup, "tuple")
			tup:SetTable(self:AnalyzeExpressions(node.expressions))
			self:PopCurrentType("tuple")
			return tup
		end,
	}	
end)("./nattlua/analyzer/expressions/tuple.lua");
package.loaded["nattlua.analyzer.expressions.vararg"] = (function(...)
	local VarArg = require("nattlua.types.tuple").VarArg
	return {
		AnalyzeVararg = function(self, node)
			return VarArg(self:AnalyzeExpression(node.value)):SetNode(node)
		end,
	}	
end)("./nattlua/analyzer/expressions/vararg.lua");
package.loaded["nattlua.analyzer.expressions.function_signature"] = (function(...)
	local Tuple = require("nattlua.types.tuple").Tuple
	local AnalyzeFunction = require("nattlua.analyzer.expressions.function").AnalyzeFunction
	return {
		AnalyzeFunctionSignature = function(self, node)
			return AnalyzeFunction(self, node)
		end,
	}	
end)("./nattlua/analyzer/expressions/function_signature.lua");
package.loaded["nattlua.analyzer.analyzer"] = (function(...)
	local tostring = tostring
	local error = error
	local setmetatable = setmetatable
	local ipairs = ipairs
	require("nattlua.types.types").Initialize()
	local META = {}
	META.__index = META
	META.OnInitialize = {}
	require("nattlua.analyzer.base.base_analyzer")(META)
	require("nattlua.analyzer.control_flow")(META)
	require("nattlua.analyzer.mutations")(META)
	require("nattlua.analyzer.operators.index").Index(META)
	require("nattlua.analyzer.operators.newindex").NewIndex(META)
	require("nattlua.analyzer.operators.call").Call(META)

	do
		local AnalyzeAssignment = require("nattlua.analyzer.statements.assignment").AnalyzeAssignment
		local AnalyzeDestructureAssignment = require("nattlua.analyzer.statements.destructure_assignment").AnalyzeDestructureAssignment
		local AnalyzeFunction = require("nattlua.analyzer.statements.function").AnalyzeFunction
		local AnalyzeIf = require("nattlua.analyzer.statements.if").AnalyzeIf
		local AnalyzeDo = require("nattlua.analyzer.statements.do").AnalyzeDo
		local AnalyzeGenericFor = require("nattlua.analyzer.statements.generic_for").AnalyzeGenericFor
		local AnalyzeCall = require("nattlua.analyzer.statements.call_expression").AnalyzeCall
		local AnalyzeNumericFor = require("nattlua.analyzer.statements.numeric_for").AnalyzeNumericFor
		local AnalyzeBreak = require("nattlua.analyzer.statements.break").AnalyzeBreak
		local AnalyzeContinue = require("nattlua.analyzer.statements.continue").AnalyzeContinue
		local AnalyzeRepeat = require("nattlua.analyzer.statements.repeat").AnalyzeRepeat
		local AnalyzeReturn = require("nattlua.analyzer.statements.return").AnalyzeReturn
		local AnalyzeAnalyzerDebugCode = require("nattlua.analyzer.statements.analyzer_debug_code").AnalyzeAnalyzerDebugCode
		local AnalyzeWhile = require("nattlua.analyzer.statements.while").AnalyzeWhile

		function META:AnalyzeStatement(node)
			self.current_statement = node
			self:PushAnalyzerEnvironment(node.environment or "runtime")

			if node.kind == "assignment" or node.kind == "local_assignment" then
				AnalyzeAssignment(self, node)
			elseif
				node.kind == "destructure_assignment" or
				node.kind == "local_destructure_assignment"
			then
				AnalyzeDestructureAssignment(self, node)
			elseif
				node.kind == "function" or
				node.kind == "type_function" or
				node.kind == "local_function" or
				node.kind == "local_type_function" or
				node.kind == "local_analyzer_function" or
				node.kind == "analyzer_function"
			then
				AnalyzeFunction(self, node)
			elseif node.kind == "if" then
				AnalyzeIf(self, node)
			elseif node.kind == "while" then
				AnalyzeWhile(self, node)
			elseif node.kind == "do" then
				AnalyzeDo(self, node)
			elseif node.kind == "repeat" then
				AnalyzeRepeat(self, node)
			elseif node.kind == "return" then
				AnalyzeReturn(self, node)
			elseif node.kind == "break" then
				AnalyzeBreak(self, node)
			elseif node.kind == "continue" then
				AnalyzeContinue(self, node)
			elseif node.kind == "call_expression" then
				AnalyzeCall(self, node)
			elseif node.kind == "generic_for" then
				AnalyzeGenericFor(self, node)
			elseif node.kind == "numeric_for" then
				AnalyzeNumericFor(self, node)
			elseif node.kind == "analyzer_debug_code" then
				AnalyzeAnalyzerDebugCode(self, node)
			elseif node.kind == "import" then

			elseif
				node.kind ~= "end_of_file" and
				node.kind ~= "semicolon" and
				node.kind ~= "shebang" and
				node.kind ~= "goto_label" and
				node.kind ~= "parser_debug_code" and
				node.kind ~= "goto"
			then
				self:FatalError("unhandled statement: " .. tostring(node))
			end

			self:PopAnalyzerEnvironment()
		end
	end

	do
		local AnalyzeBinaryOperator = require("nattlua.analyzer.expressions.binary_operator").AnalyzeBinaryOperator
		local AnalyzePrefixOperator = require("nattlua.analyzer.expressions.prefix_operator").AnalyzePrefixOperator
		local AnalyzePostfixOperator = require("nattlua.analyzer.expressions.postfix_operator").AnalyzePostfixOperator
		local AnalyzePostfixCall = require("nattlua.analyzer.expressions.postfix_call").AnalyzePostfixCall
		local AnalyzePostfixIndex = require("nattlua.analyzer.expressions.postfix_index").AnalyzePostfixIndex
		local AnalyzeFunction = require("nattlua.analyzer.expressions.function").AnalyzeFunction
		local AnalyzeTable = require("nattlua.analyzer.expressions.table").AnalyzeTable
		local AnalyzeAtomicValue = require("nattlua.analyzer.expressions.atomic_value").AnalyzeAtomicValue
		local AnalyzeImport = require("nattlua.analyzer.expressions.import").AnalyzeImport
		local AnalyzeTuple = require("nattlua.analyzer.expressions.tuple").AnalyzeTuple
		local AnalyzeVararg = require("nattlua.analyzer.expressions.vararg").AnalyzeVararg
		local AnalyzeFunctionSignature = require("nattlua.analyzer.expressions.function_signature").AnalyzeFunctionSignature
		local Union = require("nattlua.types.union").Union

		function META:AnalyzeExpression2(node)
			self.current_expression = node

			if node.type_expression then
				if node.kind == "table" then
					local obj = AnalyzeTable(self, node)
					self:PushAnalyzerEnvironment("typesystem")
					obj:SetContract(self:AnalyzeExpression(node.type_expression))
					self:PopAnalyzerEnvironment()
					return obj
				end

				self:PushAnalyzerEnvironment("typesystem")
				local obj = self:AnalyzeExpression(node.type_expression)
				self:PopAnalyzerEnvironment()
				return obj
			elseif node.kind == "value" then
				return AnalyzeAtomicValue(self, node)
			elseif node.kind == "vararg" then
				return AnalyzeVararg(self, node)
			elseif
				node.kind == "function" or
				node.kind == "analyzer_function" or
				node.kind == "type_function"
			then
				return AnalyzeFunction(self, node)
			elseif node.kind == "table" or node.kind == "type_table" then
				return AnalyzeTable(self, node)
			elseif node.kind == "binary_operator" then
				return AnalyzeBinaryOperator(self, node)
			elseif node.kind == "prefix_operator" then
				return AnalyzePrefixOperator(self, node)
			elseif node.kind == "postfix_operator" then
				return AnalyzePostfixOperator(self, node)
			elseif node.kind == "postfix_expression_index" then
				return AnalyzePostfixIndex(self, node)
			elseif node.kind == "postfix_call" then
				return AnalyzePostfixCall(self, node)
			elseif node.kind == "import" then
				return AnalyzeImport(self, node)
			elseif node.kind == "empty_union" then
				return Union({}):SetNode(node)
			elseif node.kind == "tuple" then
				return AnalyzeTuple(self, node)
			elseif node.kind == "function_signature" then
				return AnalyzeFunctionSignature(self, node)
			else
				self:FatalError("unhandled expression " .. node.kind)
			end
		end

		function META:AnalyzeExpression(node)
			local obj, err = self:AnalyzeExpression2(node)
			node:AddType(obj or err)
			return obj, err
		end
	end

	return function(config)
		config = config or {}
		local self = setmetatable({config = config}, META)

		for _, func in ipairs(META.OnInitialize) do
			func(self)
		end

		return self
	end	
end)("./nattlua/analyzer/analyzer.lua");
package.loaded["nattlua.transpiler.javascript_emitter"] = (function(...)
	local runtime_syntax = require("nattlua.syntax.runtime")
	local ipairs = ipairs
	local assert = assert
	local META = loadfile("nattlua/transpiler/emitter.lua")()

	function META:EmitExpression(node)
		if node.tokens["("] then
			for _, node in ipairs(node.tokens["("]) do
				self:EmitToken(node)
			end
		end

		if node.kind == "binary_operator" then
			self:EmitBinaryOperator(node)
		elseif node.kind == "function" then
			self:EmitAnonymousFunction(node)
		elseif node.kind == "analyzer_function" then
			self:EmitTypeFunction(node)
		elseif node.kind == "table" then
			self:EmitTable(node)
		elseif node.kind == "prefix_operator" then
			self:EmitPrefixOperator(node)
		elseif node.kind == "postfix_operator" then
			self:EmitPostfixOperator(node)
		elseif node.kind == "postfix_call" then
			self:EmitCall(node)
		elseif node.kind == "postfix_expression_index" then
			self:EmitExpressionIndex(node)
		elseif node.kind == "value" then
			if node.value.type == "letter" then
				self:EmitToken(node.value, "")
				node.value.whitespace = nil

				if not node:GetLastType() or not node:GetLastType():GetUpvalue() then
					self:Emit("globalThis.")
				end

				self:EmitToken(node.value)
			elseif node.value.value == "..." then
				self:EmitToken(node.value, "__args")
			else
				if node.tokens["is"] then
					self:EmitToken(node.value, tostring(node.result_is))
				else
					self:EmitToken(node.value)
				end
			end
		elseif node.kind == "import" then
			self:EmitImportExpression(node)
		elseif node.kind == "type_table" then
			self:EmitTableType(node)
		elseif node.kind == "table_expression_value" then
			self:EmitTableExpressionValue(node)
		elseif node.kind == "table_key_value" then
			self:EmitTableKeyValue(node)
		else
			error("unhandled token type " .. node.kind)
		end

		if node.tokens[")"] then
			for _, node in ipairs(node.tokens[")"]) do
				self:EmitToken(node)
			end
		end
	end

	function META:EmitVarargTuple(node)
		self:Emit(tostring(node:GetLastType()))
	end

	function META:EmitExpressionIndex(node)
		self:Emit("OP['.']")
		self:EmitToken(node.tokens["["], "(")
		self:EmitExpression(node.left)
		self:Emit(",")
		self:EmitExpression(node.expression)
		self:EmitToken(node.tokens["]"], ")")
	end

	function META:EmitCall(node)
		self:Emit("OP['call']")
		self:Emit("(")
		self:EmitExpression(node.left)

		if node.expressions[1] then
			self:Emit(",")

			if node.tokens["call("] then self:EmitToken(node.tokens["call("], "") end

			self:EmitExpressionList(node.expressions)

			if node.tokens["call)"] then self:EmitToken(node.tokens["call)"], "") end
		end

		self:Emit(")")
	end

	local translate = {
		["and"] = "&&",
		["or"] = "||",
		[".."] = "+",
		["~="] = "!=",
	}

	function META:EmitBinaryOperator(node)
		local func_chunks = runtime_syntax:GetFunctionForBinaryOperator(node.value)

		if func_chunks then
			self:Emit(func_chunks[1])

			if node.left then self:EmitExpression(node.left) end

			self:Emit(func_chunks[2])

			if node.right then self:EmitExpression(node.right) end

			self:Emit(func_chunks[3])
			self.operator_transformed = true
		else
			-- move whitespace
			if node.left and node.left.value then
				self:EmitToken(node.left.value, "")
				node.left.value.whitespace = nil
			end

			self:Emit("OP['")
			self:Emit(node.value.value)
			self:Emit("'](")

			if node.left then self:EmitExpression(node.left) end

			self:Emit(",")

			if node.right then
				if node.value.value == "." or node.value.value == ":" then
					self:EmitToken(node.right, "")
					self:Emit("'")
					self:EmitToken(node.right.value)
					self:Emit("'")
				else
					self:EmitExpression(node.right)
				end
			end

			self:Emit(")")
		end
	end

	do
		local function emit_function_body(self, node, analyzer_function)
			self:EmitToken(node.tokens["arguments("])

			if node.self_call then
				self:Emit("self")

				if #node.identifiers >= 1 then self:Emit(", ") end
			end

			self:EmitIdentifierList(node.identifiers)
			self:EmitToken(node.tokens["arguments)"])
			self:Emit(" => {")

			if self.config.annotate and node:GetLastType() and not analyzer_function then
				--self:Emit(" --[[ : ")
				local str = {}
				-- this iterates the first return tuple
				local obj = node:GetLastType():GetContract() or node:GetLastType()

				if obj.Type == "function" then
					for i, v in ipairs(obj:GetReturnTypes():GetData()) do
						str[i] = tostring(v)
					end
				else
					str[1] = tostring(obj)
				end

				if str[1] then
					self:Emit(": ")
					self:Emit(table.concat(str, ", "))
				end
			--self:Emit(" ]] ")
			end

			self:Whitespace("\n")
			self:EmitBlock(node.statements)
			self:Whitespace("\t")
			self:EmitToken(node.tokens["end"], "}")
		end

		function META:EmitAnonymousFunction(node)
			emit_function_body(self, node)
		end

		function META:EmitLocalFunction(node)
			self:Whitespace("\t")
			self:EmitToken(node.tokens["function"], "")
			self:EmitToken(node.tokens["local"], "let")
			self:EmitToken(node.tokens["identifier"])
			self:Emit(";")
			self:EmitToken(node.tokens["identifier"])
			self:Emit("=")
			emit_function_body(self, node)
		end

		function META:EmitLocalTypeFunction(node)
			self:Whitespace("\t")
			self:EmitToken(node.tokens["local"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["type"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")
			self:EmitIdentifier(node.identifier)
			emit_function_body(self, node)
		end

		function META:EmitLocalGenericsTypeFunction(node)
			self:Whitespace("\t")
			self:EmitToken(node.tokens["local"])
			self:Whitespace(" ")
			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")
			self:EmitIdentifier(node.identifier)
			emit_function_body(self, node, true)
		end

		function META:EmitFunction(node)
			self:Whitespace("\t")

			if node.tokens["local"] then
				self:EmitToken(node.tokens["local"])
				self:Whitespace(" ")
			end

			self:EmitToken(node.tokens["function"], "")
			self:Whitespace(" ")
			self:EmitToken(node.tokens["function"], "")

			if
				node.expression and
				node.expression.value.value == "." or
				node.expression.value.value == ":"
			then
				self:Emit("OP['='](")
				self:EmitExpression(node.expression.left)
				self:Emit(",")
				self:Emit("'")
				self:EmitExpression(node.expression.right)
				self:Emit("'")
				self:Emit(",")
			else
				self:EmitExpression(node.expression or node.identifier)
				self:Emit(" = ")
			end

			emit_function_body(self, node)
			self:Emit(")")
		end

		function META:EmitTypeFunctionStatement(node)
			self:Whitespace("\t")

			if node.tokens["local"] then
				self:EmitToken(node.tokens["local"])
				self:Whitespace(" ")
			end

			self:EmitToken(node.tokens["function"])
			self:Whitespace(" ")
			self:EmitExpression(node.expression or node.identifier)
			emit_function_body(self, node)
		end
	end

	function META:EmitTableExpressionValue(node)
		self:EmitToken(node.tokens["["])
		self:Whitespace("(")
		self:EmitExpression(node.expressions[1])
		self:Whitespace(")")
		self:EmitToken(node.tokens["]"])
		self:EmitToken(node.tokens["="], ":")
		self:EmitExpression(node.expressions[2])
	end

	function META:EmitTableKeyValue(node)
		self:EmitToken(node.tokens["identifier"])
		self:EmitToken(node.tokens["="], ":")
		self:EmitExpression(node.value_expression)
	end

	function META:EmitTable(tree)
		if tree.spread then self:Emit("table.mergetables") end

		local is_array = tree:GetLastType() and tree:GetLastType():IsNumericallyIndexed()
		local during_spread = false

		if is_array then
			self:EmitToken(tree.tokens["{"], "[")
		else
			self:EmitToken(tree.tokens["{"])
		end

		if tree.children[1] then
			self:Whitespace("\n")
			self:Whitespace("\t+")

			for i, node in ipairs(tree.children) do
				self:Whitespace("\t")

				if node.kind == "table_index_value" then
					if node.spread then
						if during_spread then
							self:Emit("},")
							during_spread = false
						end

						self:EmitExpression(node.spread.expression)
					else
						self:EmitExpression(node.value_expression)
					end
				elseif node.kind == "table_key_value" then
					if tree.spread and not during_spread then
						during_spread = true
						self:Emit("{")
					end

					self:EmitTableKeyValue(node)
				elseif node.kind == "table_expression_value" then
					self:EmitTableExpressionValue(node)
				end

				if tree.tokens["separators"][i] then
					self:EmitToken(tree.tokens["separators"][i])
				else
					self:Whitespace(",")
				end

				self:Whitespace("\n")
			end

			self:Whitespace("\t-")
			self:Whitespace("\t")
		end

		if during_spread then self:Emit("}") end

		if is_array then
			self:EmitToken(tree.tokens["}"], "]")
		else
			self:EmitToken(tree.tokens["}"])
		end
	end

	local translate = {
		["not"] = "!",
	}

	function META:EmitPrefixOperator(node)
		local func_chunks = runtime_syntax:GetFunctionForPrefixOperator(node.value)

		if self.TranslatePrefixOperator then
			func_chunks = self:TranslatePrefixOperator(node) or func_chunks
		end

		if func_chunks then
			self:Emit(func_chunks[1])
			self:EmitExpression(node.right)
			self:Emit(func_chunks[2])
			self.operator_transformed = true
		else
			if runtime_syntax:IsKeyword(node.value) then
				self:Whitespace("?")

				if translate[node.value.value] then
					self:EmitToken(node.value, translate[node.value.value])
				else
					self:EmitToken(node.value)
				end

				self:Whitespace("?")
				self:EmitExpression(node.right)
			else
				if node.value.value == "#" then
					self:Emit("OP['")
					self:Emit(node.value.value)
					self:Emit("'](")
					self:EmitExpression(node.right)
					self:Emit(")")
				else
					if translate[node.value.value] then
						self:EmitToken(node.value, translate[node.value.value])
					else
						self:EmitToken(node.value)
					end

					self:EmitExpression(node.right)
				end
			end
		end
	end

	function META:EmitPostfixOperator(node)
		local func_chunks = runtime_syntax:GetFunctionForPostfixOperator(node.value)
		-- no such thing as postfix operator in lua,
		-- so we have to assume that there's a translation
		assert(func_chunks)
		self:Emit(func_chunks[1])
		self:EmitExpression(node.left)
		self:Emit(func_chunks[2])
		self.operator_transformed = true
	end

	function META:EmitBlock(statements)
		self:Whitespace("\t+")
		self:EmitStatements(statements)
		self:Whitespace("\t-")
	end

	function META:TranslateToken(token)
		if token.type == "line_comment" then
			return "//" .. token.value:sub(3)
		elseif token.type == "multiline_comment" then
			local content = token.value:sub(5, -3):gsub("%*/", "* /"):gsub("/%*", "/ *")
			return "/*" .. content .. "*/"
		end
	end

	function META:EmitIfStatement(node)
		for i = 1, #node.statements do
			self:Whitespace("\t")

			if node.expressions[i] then
				if node.tokens["if/else/elseif"][i].value == "if" then
					self:EmitToken(node.tokens["if/else/elseif"][i], "if")
				elseif node.tokens["if/else/elseif"][i].value == "elseif" then
					self:EmitToken(node.tokens["if/else/elseif"][i], "else if")
				end

				if not node.expressions[i].tokens["("] then self:Emit("(") end

				self:EmitExpression(node.expressions[i])

				if not node.expressions[i].tokens[")"] then self:Emit(")") end

				self:EmitToken(node.tokens["then"][i], "{")
			elseif node.tokens["if/else/elseif"][i] then
				self:EmitToken(node.tokens["if/else/elseif"][i])
				self:Whitespace(" ")
				self:Emit("{")
			end

			self:Whitespace("\n")
			self:Whitespace("\t")
			self:EmitBlock(node.statements[i])
			self:Whitespace("\t")

			if i ~= #node.statements then self:Emit("}") end
		end

		self:Whitespace("\t")
		self:EmitToken(node.tokens["end"], "}")
	end

	function META:EmitGenericForStatement(node)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["for"])
		self:Emit("(")
		self:Emit("let ")
		self:Emit("[")
		self:Whitespace(" ")
		self:EmitIdentifierList(node.identifiers)
		self:Whitespace(" ")
		self:Emit("]")
		self:EmitToken(node.tokens["in"], "of")
		self:Whitespace(" ")
		self:Emit("(")
		self:EmitExpressionList(node.expressions)
		self:Emit(")")
		self:Whitespace(" ")
		self:Emit(")")
		self:EmitToken(node.tokens["do"], "{")
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["end"], "}")
	end

	function META:EmitNumericForStatement(node)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["for"])
		self:Emit("(")
		self:Emit("let")
		self:Whitespace(" ")
		self:EmitIdentifier(node.identifiers[1])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["="])
		self:Whitespace(" ")
		self:EmitExpression(node.expressions[1])
		self:EmitToken(node.expressions[1].tokens[","], ";")
		self:EmitIdentifier(node.identifiers[1])
		self:Emit("<=")
		self:EmitExpression(node.expressions[2])

		if node.expressions[2].tokens[","] then
			self:EmitToken(node.expressions[2].tokens[","], ";")
		else
			self:Emit(";")
		end

		self:EmitIdentifier(node.identifiers[1])

		if node.expressions[3] then
			self:Emit(" ")
			self:Emit("+")
			self:Emit("=")
			self:EmitExpression(node.expressions[3])
		else
			self:Emit("++")
		end

		self:Whitespace(" ")
		self:Emit(")")
		self:EmitToken(node.tokens["do"], "{")
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["end"], "}")
	end

	function META:EmitWhileStatement(node)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["while"])
		self:Whitespace(" ")
		self:Emit("(")
		self:EmitExpression(node.expression)
		self:Emit(")")
		self:Whitespace(" ")
		self:EmitToken(node.tokens["do"], "{")
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["end"], "}")
	end

	function META:EmitRepeatStatement(node)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["repeat"], "while (true) {")
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\t")
		self:Emit(";if (")
		self:EmitExpression(node.expression)
		self:Emit(") break;")
		self:EmitToken(node.tokens["until"], "}")
	end

	function META:EmitLabelStatement(node)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["::"][1])
		self:EmitToken(node.tokens["identifier"])
		self:EmitToken(node.tokens["::"][2])
	end

	function META:EmitGotoStatement(node)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["goto"])
		self:Whitespace(" ")
		self:EmitToken(node.tokens["identifier"])
	end

	function META:EmitBreakStatement(node)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["break"])
	end

	function META:EmitDoStatement(node)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["do"], "{")
		self:Whitespace("\n")
		self:EmitBlock(node.statements)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["end"], "}")
	end

	function META:EmitReturnStatement(node)
		self:Whitespace("\t")
		self:EmitToken(node.tokens["return"])
		self:Whitespace(" ")
		self:EmitExpressionList(node.expressions)
	end

	function META:EmitSemicolonStatement(node)
		self:EmitToken(node.tokens[";"])
	end

	function META:EmitLocalAssignment(node)
		if node.environment == "typesystem" then return end

		self:Whitespace("\t")

		if node.environment == "typesystem" then
			self:EmitToken(node.tokens["type"])
		end

		self:Whitespace(" ")
		self:EmitToken(node.tokens["local"], "let")

		for i, left in ipairs(node.left) do
			local right = node.right and node.right[i]
			self:EmitIdentifier(left)

			if right then
				self:EmitToken(node.tokens["="])
				self:EmitExpression(right)

				if right.tokens[","] then self:EmitToken(right.tokens[","], "") end
			end

			if left.tokens[","] then self:EmitToken(left.tokens[","]) end
		end
	end

	function META:EmitAssignment(node)
		if node.environment == "typesystem" then return end

		self:Whitespace("\t")

		if node.environment == "typesystem" then
			self:EmitToken(node.tokens["type"])
		end

		for i, left in ipairs(node.left) do
			local right = node.right[i]

			if left.kind == "binary_operator" then
				self:Emit("OP['='](")

				if
					left.kind == "binary_operator" and
					(
						left.value.value == "." or
						left.value.value == ":"
					)
				then
					self:EmitExpression(left.left)
					self:Emit(",")
					self:Emit("'")
					self:EmitExpression(left.right)
					self:Emit("'")
				else
					self:EmitExpression(left)
				end

				if right then
					self:Emit(",")
					self:EmitExpression(right)
				end

				self:Emit(");")
			elseif left.kind == "postfix_expression_index" then
				self:Emit("OP['='](")
				self:EmitExpression(left.left)
				self:Emit(",")
				self:EmitExpression(left.expression)

				if right then
					self:Emit(",")
					self:EmitExpression(right)
				end

				self:Emit(");")
			else
				self:EmitExpression(left)
				self:Emit("=")
				self:EmitExpression(right)
			end
		end
	end

	function META:EmitStatement(node)
		if node.kind == "if" then
			self:EmitIfStatement(node)
		elseif node.kind == "goto" then
			self:EmitGotoStatement(node)
		elseif node.kind == "goto_label" then
			self:EmitLabelStatement(node)
		elseif node.kind == "while" then
			self:EmitWhileStatement(node)
		elseif node.kind == "repeat" then
			self:EmitRepeatStatement(node)
		elseif node.kind == "break" then
			self:EmitBreakStatement(node)
		elseif node.kind == "return" then
			self:EmitReturnStatement(node)
		elseif node.kind == "numeric_for" then
			self:EmitNumericForStatement(node)
		elseif node.kind == "generic_for" then
			self:EmitGenericForStatement(node)
		elseif node.kind == "do" then
			self:EmitDoStatement(node)
		elseif node.kind == "analyzer_function" then
			self:EmitTypeFunctionStatement(node)
		elseif node.kind == "function" then
			self:EmitFunction(node)
		elseif node.kind == "local_function" then
			self:EmitLocalFunction(node)
		elseif node.kind == "local_analyzer_function" then
			self:EmitLocalTypeFunction(node)
		elseif node.kind == "destructure_assignment" then
			self:EmitDestructureAssignment(node)
		elseif node.kind == "assignment" then
			self:EmitAssignment(node)
			self:Emit_ENVFromAssignment(node)
		elseif node.kind == "local_assignment" then
			self:EmitLocalAssignment(node)
		elseif node.kind == "local_destructure_assignment" then
			self:EmitLocalDestructureAssignment(node)
		elseif node.kind == "import" then
			self:Emit("local ")
			self:EmitIdentifierList(node.left)
			self:Emit(" = ")
			self:EmitImportExpression(node)
		elseif node.kind == "call_expression" then
			self:Whitespace("\t")
			self:EmitExpression(node.value)
		elseif node.kind == "shebang" then
			self:EmitToken(node.tokens["shebang"])
		elseif node.kind == "semicolon" then
			self:EmitSemicolonStatement(node)

			if self.config.preserve_whitespace == false then
				if self.out[self.i - 2] and self.out[self.i - 2] == "\n" then
					self.out[self.i - 2] = ""
				end
			end
		elseif node.kind == "end_of_file" then
			self:EmitToken(node.tokens["end_of_file"])
		elseif node.kind == "root" then
			self:EmitStatements(node.statements)
		else
			error("unhandled statement: " .. node.kind)
		end

		self:Emit(";")

		if self.OnEmitStatement then
			if node.kind ~= "end_of_file" then self:OnEmitStatement() end
		end
	end

	function META:EmitStatements(tbl)
		for _, node in ipairs(tbl) do
			self:EmitStatement(node)
			self:Whitespace("\n")
		end
	end

	function META:EmitExpressionList(tbl, delimiter)
		for i = 1, #tbl do
			self:EmitExpression(tbl[i])

			if i ~= #tbl then
				self:EmitToken(tbl[i].tokens[","], delimiter)
				self:Whitespace(" ")
			end
		end
	end

	function META:EmitIdentifier(node)
		self:EmitToken(node.value)

		if node.value.value == "..." then self:Emit("__args") end

		if self.config.annotate then
			if node.type_expression then
				self:EmitToken(node.tokens[":"])
				self:EmitTypeExpression(node.type_expression)
			elseif node:GetLastType() then
				self:Emit(": ")
				self:Emit(tostring((node:GetLastType():GetContract() or node:GetLastType())))
			end
		end
	end

	function META:EmitIdentifierList(tbl)
		for i = 1, #tbl do
			self:EmitIdentifier(tbl[i])

			if i ~= #tbl then
				self:EmitToken(tbl[i].tokens[","])
				self:Whitespace(" ")
			end
		end
	end

	do -- types
		function META:EmitTypeBinaryOperator(node)
			if node.left then self:EmitTypeExpression(node.left) end

			if node.value.value == "." or node.value.value == ":" then
				self:EmitToken(node.value)
			else
				self:Whitespace(" ")
				self:EmitToken(node.value)
				self:Whitespace(" ")
			end

			if node.right then self:EmitTypeExpression(node.right) end
		end

		function META:EmitType(node)
			self:EmitToken(node.value)

			if node.type_expression then
				self:EmitToken(node.tokens[":"])
				self:EmitTypeExpression(node.type_expression)
			end
		end

		function META:EmitTypeList(node)
			self:EmitToken(node.tokens["["])

			for i = 1, #node.types do
				self:EmitTypeExpression(node.types[i])

				if i ~= #node.types then
					self:EmitToken(node.types[i].tokens[","])
					self:Whitespace(" ")
				end
			end

			self:EmitToken(node.tokens["]"])
		end

		function META:EmitListType(node)
			self:EmitTypeExpression(node.left)
			self:EmitTypeList(node)
		end

		function META:EmitTableType(node)
			local tree = node
			self:EmitToken(node.tokens["{"])

			if node.children[1] then
				self:Whitespace("\n")
				self:Whitespace("\t+")

				for i, node in ipairs(node.children) do
					self:Whitespace("\t")

					if node.kind == "table_index_value" then
						self:EmitTypeExpression(node.value_expression)
					elseif node.kind == "table_key_value" then
						self:EmitToken(node.tokens["identifier"])
						self:EmitToken(node.tokens["="], ":")
						self:EmitTypeExpression(node.value_expression)
					elseif node.kind == "table_expression_value" then
						self:EmitToken(node.tokens["["])
						self:Whitespace("(")
						self:EmitTypeExpression(node.key_expression)
						self:Whitespace(")")
						self:EmitToken(node.tokens["]"])
						self:EmitToken(node.tokens["="], ":")
						self:EmitTypeExpression(node.value_expression)
					end

					if tree.tokens["separators"][i] then
						self:EmitToken(tree.tokens["separators"][i])
					else
						self:Whitespace(",")
					end

					self:Whitespace("\n")
				end

				self:Whitespace("\t-")
				self:Whitespace("\t")
			end

			self:EmitToken(node.tokens["}"])
		end

		function META:EmitTypeFunction(node)
			self:EmitToken(node.tokens["function"])

			if node.tokens["("] then self:EmitToken(node.tokens["("]) end

			for i, exp in ipairs(node.identifiers) do
				if not self.config.annotate and node.statements then
					if exp.identifier then
						self:EmitToken(exp.identifier)
					else
						self:EmitTypeExpression(exp)
					end
				else
					if exp.identifier then
						self:EmitToken(exp.identifier)
						self:EmitToken(exp.tokens[":"])
					end

					self:EmitTypeExpression(exp)
				end

				if i ~= #node.identifiers then
					if exp.tokens[","] then self:EmitToken(exp.tokens[","]) end
				end
			end

			if node.tokens[")"] then self:EmitToken(node.tokens[")"]) end

			if node.tokens[":"] then
				self:EmitToken(node.tokens[":"])

				for i, exp in ipairs(node.return_types) do
					self:EmitTypeExpression(exp)

					if i ~= #node.return_types then self:EmitToken(exp.tokens[","]) end
				end
			else
				self:Whitespace("\n")
				self:EmitBlock(node.statements)
				self:Whitespace("\t")
				self:EmitToken(node.tokens["end"])
			end
		end

		function META:EmitTypeExpression(node)
			if node.tokens["("] then
				for _, node in ipairs(node.tokens["("]) do
					self:EmitToken(node)
				end
			end

			if node.kind == "binary_operator" then
				self:EmitTypeBinaryOperator(node)
			elseif node.kind == "analyzer_function" then
				self:EmitTypeFunction(node)
			elseif node.kind == "table" then
				self:EmitTable(node)
			elseif node.kind == "prefix_operator" then
				self:EmitPrefixOperator(node)
			elseif node.kind == "postfix_operator" then
				self:EmitPostfixOperator(node)
			elseif node.kind == "postfix_call" then
				self:EmitCall(node)
			elseif node.kind == "postfix_expression_index" then
				self:EmitExpressionIndex(node)
			elseif node.kind == "value" then
				self:EmitToken(node.value)
			elseif node.kind == "type_table" then
				self:EmitTableType(node)
			elseif node.kind == "table_expression_value" then
				self:EmitTableExpressionValue(node)
			elseif node.kind == "table_key_value" then
				self:EmitTableKeyValue(node)
			else
				error("unhandled token type " .. node.kind)
			end

			if node.tokens[")"] then
				for _, node in ipairs(node.tokens[")"]) do
					self:EmitToken(node)
				end
			end
		end
	end

	do -- extra
		function META:EmitDestructureAssignment(node)
			self:Whitespace("\t")
			self:EmitToken(node.tokens["{"], "")

			if node.default then
				self:EmitToken(node.default.value)
				self:EmitToken(node.default_comma)
			end

			self:EmitToken(node.tokens["{"], "")
			self:Whitespace(" ")
			self:EmitIdentifierList(node.left)
			self:EmitToken(node.tokens["}"], "")
			self:Whitespace(" ")
			self:EmitToken(node.tokens["="])
			self:Whitespace(" ")
			self:Emit("table.destructure(")
			self:EmitExpression(node.right)
			self:Emit(", ")
			self:Emit("{")

			for i, v in ipairs(node.left) do
				self:Emit("\"")
				self:Emit(v.value.value)
				self:Emit("\"")

				if i ~= #node.left then self:Emit(", ") end
			end

			self:Emit("}")

			if node.default then self:Emit(", true") end

			self:Emit(")")
		end

		function META:EmitLocalDestructureAssignment(node)
			self:Whitespace("\t")
			self:EmitToken(node.tokens["local"])
			self:EmitDestructureAssignment(node)
		end

		function META:Emit_ENVFromAssignment(node)
			for i, v in ipairs(node.left) do
				if v.kind == "value" and v.value.value == "_ENV" then
					if node.right[i] then
						local key = node.left[i]
						local val = node.right[i]
						self:Emit(";setfenv(1, _ENV);")
					end
				end
			end
		end

		function META:EmitImportExpression(node)
			self:Emit(" IMPORTS['" .. node.path .. "'](")
			self:EmitExpressionList(node.expressions)
			self:Emit(")")
		end
	end

	function META.New(config)
		local self = setmetatable({}, META)
		self.config = config or {}
		self:Initialize()
		return self
	end

	return META	
end)("./nattlua/transpiler/javascript_emitter.lua");
package.loaded["nattlua.compiler"] = (function(...)
	local io = io
	local error = error
	local xpcall = xpcall
	local tostring = tostring
	local table = require("table")
	local assert = assert
	local helpers = require("nattlua.other.helpers")
	local debug = require("debug")
	local BuildBaseEnvironment = require("nattlua.runtime.base_environment").BuildBaseEnvironment
	local setmetatable = _G.setmetatable
	local Code = require("nattlua.code.code")
	local META = {}
	META.__index = META

	function META:GetCode()
		return self.Code
	end

	function META:__tostring()
		local str = ""

		if self.parent_name then
			str = str .. "[" .. self.parent_name .. ":" .. self.parent_line .. "] "
		end

		local lua_code = self.Code:GetString()
		local line = lua_code:match("(.-)\n")

		if line then str = str .. line .. "..." else str = str .. lua_code end

		return str
	end

	local repl = function()
		return "\nbecause "
	end

	function META:OnDiagnostic(code, msg, severity, start, stop, ...)
		local level = 0
		local t = 0
		msg = msg:gsub(" because ", repl)

		if t > 0 then msg = "\n" .. msg end

		if self.analyzer and self.analyzer.processing_deferred_calls then
			msg = "DEFERRED CALL: " .. msg
		end

		local msg = helpers.FormatError(code, msg, start, stop, nil, ...)
		local msg2 = ""

		for line in (msg .. "\n"):gmatch("(.-)\n") do
			msg2 = msg2 .. (" "):rep(4 - level * 2) .. line .. "\n"
		end

		msg = msg2

		if not _G.TEST then io.write(msg) end

		if
			severity == "fatal" or
			(
				_G.TEST and
				severity == "error" and
				not _G.TEST_DISABLE_ERROR_PRINT
			)
			or
			self.debug
		then
			local level = 2

			if _G.TEST then
				for i = 1, math.huge do
					local info = debug.getinfo(i)

					if not info then break end

					if info.source:find("@test/nattlua", nil, true) then
						level = i

						break
					end
				end
			end

			error(msg, level)
		end
	end

	local function stack_trace()
		local s = ""

		for i = 2, 50 do
			local info = debug.getinfo(i)

			if not info then break end

			if info.source:sub(1, 1) == "@" then
				if info.name == "Error" or info.name == "OnDiagnostic" then

				else
					s = s .. info.source:sub(2) .. ":" .. info.currentline .. " - " .. (
							info.name or
							"?"
						) .. "\n"
				end
			end
		end

		return s
	end

	local traceback = function(self, obj, msg)
		if self.debug or _G.TEST then
			local ret = {
				xpcall(function()
					msg = msg or "no error"
					local s = msg .. "\n" .. stack_trace()

					if self.analyzer then s = s .. self.analyzer:DebugStateToString() end

					return s
				end, function(msg)
					return debug.traceback(tostring(msg))
				end),
			}

			if not ret[1] then return "error in error handling: " .. tostring(ret[2]) end

			return table.unpack(ret, 2)
		end

		return msg
	end

	function META:Lex()
		local lexer = self.Lexer(self:GetCode())
		lexer.name = self.name
		self.lexer = lexer
		lexer.OnError = function(lexer, code, msg, start, stop, ...)
			self:OnDiagnostic(code, msg, "fatal", start, stop, ...)
		end
		local ok, tokens = xpcall(function()
			return lexer:GetTokens()
		end, function(msg)
			return traceback(self, lexer, msg)
		end)

		if not ok then return nil, tokens end

		self.Tokens = tokens
		return self
	end

	function META:Parse()
		if not self.Tokens then
			local ok, err = self:Lex()

			if not ok then return ok, err end
		end

		local parser = self.Parser(self.Tokens, self.Code, self.config)
		self.parser = parser
		parser.OnError = function(parser, code, msg, start, stop, ...)
			self:OnDiagnostic(code, msg, "fatal", start, stop, ...)
		end

		if self.OnNode then
			parser.OnNode = function(_, node)
				self:OnNode(node)
			end
		end

		local ok, res = xpcall(function()
			return parser:ReadRootNode()
		end, function(msg)
			return traceback(self, parser, msg)
		end)

		if not ok then return nil, res end

		self.SyntaxTree = res
		return self
	end

	function META:SetEnvironments(runtime, typesystem)
		self.default_environment = {}
		self.default_environment.runtime = runtime
		self.default_environment.typesystem = typesystem
	end

	function META:Analyze(analyzer, ...)
		if not self.SyntaxTree then
			local ok, err = self:Parse()

			if not ok then
				assert(err)
				return ok, err
			end
		end

		local analyzer = analyzer or self.Analyzer()
		self.analyzer = analyzer
		analyzer.compiler = self
		analyzer.OnDiagnostic = function(analyzer, ...)
			self:OnDiagnostic(...)
		end

		if self.default_environment then
			analyzer:SetDefaultEnvironment(self.default_environment["runtime"], "runtime")
			analyzer:SetDefaultEnvironment(self.default_environment["typesystem"], "typesystem")
		elseif self.default_environment ~= false then
			local runtime_env, typesystem_env = BuildBaseEnvironment()
			analyzer:SetDefaultEnvironment(runtime_env, "runtime")
			analyzer:SetDefaultEnvironment(typesystem_env, "typesystem")
		end

		analyzer.ResolvePath = self.OnResolvePath
		local args = {...}
		local ok, res = xpcall(function()
			local res = analyzer:AnalyzeRootStatement(self.SyntaxTree, table.unpack(args))
			analyzer:AnalyzeUnreachableCode()

			if analyzer.OnFinish then analyzer:OnFinish() end

			return res
		end, function(msg)
			return traceback(self, analyzer, msg)
		end)
		self.AnalyzedResult = res

		if not ok then return nil, res end

		return self
	end

	function META:Emit(cfg)
		if not self.SyntaxTree then
			local ok, err = self:Parse()

			if not ok then return ok, err end
		end

		local emitter = self.Emitter(cfg or self.config)
		self.emitter = emitter
		return emitter:BuildCode(self.SyntaxTree)
	end

	return function(
		lua_code--[[#: string]],
		name--[[#: string]],
		config--[[#: {[any] = any}]],
		level--[[#: number | nil]]
	)
		local info = debug.getinfo(level or 2)
		local parent_line = info and info.currentline or "unknown line"
		local parent_name = info and info.source:sub(2) or "unknown name"
		name = name or (parent_name .. ":" .. parent_line)
		return setmetatable(
			{
				Code = Code(lua_code, name),
				parent_line = parent_line,
				parent_name = parent_name,
				config = config,
				Lexer = require("nattlua.lexer.lexer"),
				Parser = require("nattlua.parser.parser"),
				Analyzer = require("nattlua.analyzer.analyzer"),
				Emitter = config and
					config.js and
					require("nattlua.transpiler.javascript_emitter").New or
					require("nattlua.transpiler.emitter").New,
			},
			META
		)
	end	
end)("./nattlua/compiler.lua");
package.loaded["nattlua.init"] = (function(...)
	local nl = {}
	nl.Compiler = require("nattlua.compiler")

	function nl.load(code, name, config)
		local obj = nl.Compiler(code, name, config)
		local code, err = obj:Emit()

		if not code then return nil, err end

		return loadstring(code, name)
	end

	function nl.loadfile(path, config)
		local obj = nl.File(path, config)
		local code, err = obj:Emit()

		if not code then return nil, err end

		return loadstring(code, path)
	end

	function nl.ParseFile(path, config)
		config = config or {}
		local code, err = nl.File(path, config)

		if not code then return nil, err end

		local ok, err = code:Parse()

		if not ok then return nil, err end

		return ok, code
	end

	function nl.File(path, config)
		config = config or {}
		config.path = config.path or path
		config.name = config.name or path
		local f, err = io.open(path, "rb")

		if not f then return nil, err end

		local code = f:read("*all")
		f:close()

		if not code then return nil, path .. " empty file" end

		return nl.Compiler(code, "@" .. path, config)
	end

	return nl	
end)("./nattlua/init.lua");
if not table.unpack and _G.unpack then table.unpack = _G.unpack end

if not _G.loadstring and _G.load then _G.loadstring = _G.load end

do -- these are just helpers for print debugging
	table.print = require("nattlua.other.table_print")
	debug.trace = function(...)
		print(debug.traceback(...))
	end
-- local old = print; function print(...) old(debug.traceback()) end
end

local helpers = require("nattlua.other.helpers")
helpers.JITOptimize()
--helpers.EnableJITDumper()
return require("nattlua.init")