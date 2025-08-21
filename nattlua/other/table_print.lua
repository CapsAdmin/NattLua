--[[# --ANALYZE
local type State = {
	depth = 0 .. inf,
	max_depth = 1 .. inf,
	expand_metatables = boolean,
	done = Map<|any, string | nil | true|>,
}]]

local function escape_string(str--[[#: string]], quote--[[#: string]])
	local new_str = {}
	local escape_map = {
		["\n"] = "\\n",
		["\t"] = "\\t",
		["\r"] = "\\r",
		["\b"] = "\\b",
		["\f"] = "\\f",
		["\v"] = "\\v",
		["\a"] = "\\a",
		["\\"] = "\\\\",
		[quote] = "\\" .. quote,
	}
	local i = 1

	while i <= #str do
		local c = str:sub(i, i)

		if c == "\\" and i < #str then
			local next_c = str:sub(i + 1, i + 1)
			new_str[#new_str + 1] = c .. next_c
			i = i + 2
		elseif escape_map[c] then
			new_str[#new_str + 1] = escape_map[c]
			i = i + 1
		elseif string.byte(c) < 32 or string.byte(c) > 126 then
			new_str[#new_str + 1] = string.format("\\x%02X", string.byte(c))
			i = i + 1
		else
			new_str[#new_str + 1] = c
			i = i + 1
		end
	end

	return table.concat(new_str)
end

local tostring_object_

local function sort_keys(a, b)
	local type_a, type_b = type(a.raw_key), type(b.raw_key)

	if type_a ~= type_b then
		local type_order = {number = 1, string = 2, boolean = 3}
		local order_a = type_order[type_a] or 4
		local order_b = type_order[type_b] or 4
		return order_a < order_b
	end

	if type_a == "number" or type_a == "string" then
		return a.raw_key < b.raw_key
	elseif type_a == "boolean" then
		return tostring(a.raw_key) < tostring(b.raw_key)
	else
		return a.k < b.k
	end
end

local function tostring_table_sorted(tbl--[[#: Table]], state--[[#: State]])--[[#: List<|{k = string, v = string, raw_key = any}|>]]
	local sorted = {}

	if state.depth >= state.max_depth then return sorted end

	for k, v in pairs(tbl) do
		local raw_key = k
		local key_str

		if type(k) == "string" then
			if k:match("^[%a_][%w_]*$") then
				key_str = k
			else
				key_str = "[\"" .. escape_string(k, "\"") .. "\"]"
			end
		elseif type(k) == "number" then
			key_str = "[" .. tostring(k) .. "]"
		else
			key_str = "[" .. ((tostring_object_--[[# as any]])(k, state)--[[# as string]]) .. "]"
		end

		local vobj = v

		if type(v) == "number" and v ~= v then
			v = "nan"
		else
			v = ((tostring_object_--[[# as any]])(v, state)--[[# as string]])
		end

		if type(vobj) == "table" then state.done[vobj] = "*" .. key_str .. "*" end

		table.insert(sorted, {k = key_str, v = v, raw_key = raw_key})
	end

	table.sort(sorted, sort_keys)
	return sorted
end

function tostring_object_(obj--[[#: any]], state--[[#: State]])--[[#: string]]
	local T = type(obj)

	if T == "table" then
		if state.done[obj] == true then return "*self*" end

		if state.done[obj] then return state.done[obj]--[[# as string]] end

		state.done[obj] = true
		local meta = getmetatable(obj)

		if meta and meta.__tostring and not state.expand_metatables then
			return (tostring--[[# as any]])(obj)
		end

		if state.depth >= state.max_depth then return "{...}" end

		local s = {"{\n"}
		state.depth = state.depth + 1

		for _, kv in ipairs(tostring_table_sorted(obj, state)) do
			table.insert(s, ("%s%s = %s,\n"):format(("\t"):rep(state.depth), kv.k, kv.v))
		end

		if state.expand_metatables and meta then
			local meta_str = (tostring_object_--[[# as any]])(meta, state)--[[# as string]]
			table.insert(s, ("%s[METATABLE] = %s,\n"):format(("\t"):rep(state.depth), meta_str))
		end

		state.depth = (state.depth - 1)--[[# as 1 .. inf]]
		table.insert(s, ("\t"):rep(state.depth) .. "}")
		return table.concat(s)
	elseif T == "string" then
		return "\"" .. escape_string(obj, "\"") .. "\""
	elseif T == "number" then
		if obj ~= obj then
			return "nan"
		elseif obj == math.huge then
			return "inf"
		elseif obj == -math.huge then
			return "-inf"
		else
			return tostring(obj)
		end
	elseif T == "function" then
		local pretty_source = "unknown"

		if debug and debug.getinfo then
			local info = debug.getinfo(obj)

			if info then
				if info.source:sub(1, 1) == "@" then
					pretty_source = info.source:sub(2)
					local line = info.currentline

					if line == -1 then line = info.linedefined end

					pretty_source = pretty_source .. ":" .. line
				else
					pretty_source = info.source:sub(1, 25)

					if pretty_source ~= info.source then
						pretty_source = pretty_source .. "...(+" .. (#info.source - #pretty_source) .. " chars)"
					end

					if pretty_source == "=[C]" and jit and jit.vmdef then
						local num = tonumber(tostring(obj):match("#(%d+)") or "")

						if num and jit.vmdef.ffnames[num] then
							pretty_source = jit.vmdef.ffnames[num]
						end
					end
				end
			end
		end

		local params = {}

		if debug and debug.getlocal then
			for i = 1, math.huge do
				local key = debug.getlocal(obj, i)

				if key then
					if not key:match("^%(") then table.insert(params, key) end
				else
					break
				end
			end
		end

		local has_varargs = false

		if debug and debug.getinfo then
			local info = debug.getinfo(obj)

			if info and info.isvararg then has_varargs = true end
		end

		local param_str = table.concat(params, ", ")

		if has_varargs then
			if #params > 0 then
				param_str = param_str .. ", ..."
			else
				param_str = "..."
			end
		end

		return string.format("function(%s) --[[ %s @ %p ]]", param_str, pretty_source, obj)
	elseif T == "boolean" or T == "nil" then
		return tostring(obj)
	elseif T == "thread" then
		return string.format("thread: %p", obj)
	elseif T == "userdata" then
		local meta = getmetatable(obj)

		if meta and meta.__tostring then
			return tostring(obj)
		else
			return string.format("userdata: %p", obj)
		end
	else
		return string.format("%s: %s", T, tostring(obj))
	end
end

local function tostring_object(obj--[[#: any]], state--[[#: nil | Partial<|State|>]])--[[#: string]]
	state = state or {}
	state.depth = state.depth or 0
	state.max_depth = state.max_depth or math.huge

	if state.expand_metatables == nil then state.expand_metatables = false end

	state.done = state.done or {}
	return tostring_object_(obj, state)
end

--[[#local type print = function=(any)>()]]
return {
	tostring = tostring_object,
	print = function(
		tbl--[[#: Table]],
		max_depth--[[#: 1 .. inf | nil]],
		expand_metatables--[[#: boolean | nil]]
	)
		print(
			tostring_object(
				tbl,
				{
					max_depth = max_depth,
					expand_metatables = expand_metatables,
				}
			)
		)
	end,
}
