local setmetatable = _G.setmetatable
local ipairs = _G.ipairs
local class = {}

function class.CreateTemplate(type_name--[[#: ref string]])--[[#: ref Table]]
	local META = {}
	META.Type = type_name
	META.__index = META

	function META.GetSet(META--[[#: ref META]], name--[[#: ref string]], default--[[#: ref any]])
		META[name] = default--[[# as NonLiteral<|default|>]]
		--[[#type META.@SelfArgument[name] = NonLiteral<|default|>]]
		META["Set" .. name] = function(self--[[#: ref META.@SelfArgument]], val--[[#: NonLiteral<|default|>]])
			self[name] = val
			return self
		end
		META["Get" .. name] = function(self--[[#: ref META.@SelfArgument]])--[[#: NonLiteral<|default|>]]
			return self[name]
		end
	end

	function META.IsSet(META--[[#: ref META]], name--[[#: ref string]], default--[[#: ref any]])
		META[name] = default--[[# as NonLiteral<|default|>]]
		--[[#type META.@SelfArgument[name] = NonLiteral<|default|>]]
		META["Set" .. name] = function(self--[[#: META.@SelfArgument]], val--[[#: NonLiteral<|default|>]])
			self[name] = val
			return self
		end
		META["Is" .. name] = function(self--[[#: META.@SelfArgument]])--[[#: NonLiteral<|default|>]]
			return self[name]
		end
	end

	if true--[[# as false]] then
		local function get_line()
			local info = debug.getinfo(3)

			if not info then return "**unknown line**" end

			if info.source:find("class.lua", nil, true) then
				info = debug.getinfo(4)

				if not info then return "**unknown line**" end
			end

			return info.source:sub(2) .. ":" .. info.currentline
		end

		local function get_constructor()
			local info = debug.getinfo(META.New--[[# as any]])

			if not info then return "**unknown line**" end

			return info.source:sub(2) .. ":" .. info.linedefined
		end

		local done--[[#: List<|function=(obj: ref AnyTable)>()|>]] = {}

		function META:DebugPropertyAccess()
			local function tostring_obj(obj)
				if rawget(obj, "Type") then return obj.Type end

				return tostring(obj)
			end

			META.__index = function(self, key)
				if META[key] == nil or type(META[key]) ~= "function" then
					local line = get_line()
					local hash = key .. "-" .. line

					if not done[hash] then
						io.write(tostring_obj(self), " - ", get_constructor(), "\n")
						io.write("\t", line, "\n")
						io.write("\tGET " .. key, "\n")
						done[hash] = true
					end
				end

				return META[key]
			end
			META.__newindex = function(self, key, val)
				if val == nil or META[key] == nil or type(META[key]) ~= "function" then
					local line = get_line()
					local hash = key .. "-" .. line .. "-" .. type(val)

					if not done[hash] then
						io.write(tostring_obj(self), " - ", get_constructor(), "\n")
						io.write("\t", line, "\n")
						io.write("\tSET " .. key .. " = " .. type(val), "\n")
						done[hash] = true
					end
				end

				rawset(self--[[# as any]], key, val)
			end
		end
	end

	local on_initialize = {}
	local unrolled_keys

	function META.NewObject(init--[[#: ref AnyTable]], unroll_functions--[[#: boolean | nil]])
		for _, func in ipairs(on_initialize) do
			func(init)
		end

		if unroll_functions then
			if true--[[# as false]] then
				if not unrolled_keys then
					unrolled_keys = {}

					for k, v in pairs(META) do
						if type(v) == "function" then
							init[k] = v
							table.insert(unrolled_keys, {k, v})
						end
					end
				else
					for k, v in ipairs(unrolled_keys) do
						init[v[1]] = v[2]
					end
				end
			end
		end

		local obj = setmetatable(init, META)
		return obj
	end

	function META.AddInitializer(_, func--[[#: ref function=(obj: ref AnyTable)>()]])
		table.insert(on_initialize, func)

		if false--[[# as true]] then
			--[[#local type res = {}]]
			--[[#func<|res|>]]

			for k, v in pairs(res) do
				--[[#type META.@SelfArgument[k] = v]]
			end
		end
	end

	return META
end

return class
