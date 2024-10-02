local class = {}

function class.CreateTemplate(type_name--[[#: ref string]])--[[#: ref Table]]
	local meta = {}
	meta.Type = type_name
	meta.__index = meta
	--[[#type meta.@Self = {}]]
	local blacklist = {}

	function meta.GetSet(tbl--[[#: ref tbl]], name--[[#: ref string]], default--[[#: ref any]])
		blacklist[name] = true
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

	function meta.IsSet(tbl--[[#: ref tbl]], name--[[#: ref string]], default--[[#: ref any]])
		blacklist[name] = true
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

	local function get_line()
		local info = debug.getinfo(3)

		if not info then return "**unknown line**" end

		return info.source:sub(2) .. ":" .. info.currentline
	end

	local function get_constructor()
		local info = debug.getinfo(meta.New--[[# as any]])

		if not info then return "**unknown line**" end

		return info.source:sub(2) .. ":" .. info.linedefined
	end

	local done = {}

	function meta:DebugPropertyAccess(filter)
		if false--[[# as true]] then return end

		meta.__index = function(self, key)
			if meta[key] ~= nil then return meta[key] end

			if not blacklist[key] then
				if not filter or key:find(filter, nil, true) then
					local line = get_line()
					local hash = key .. "-" .. line

					if not done[hash] then
						print(get_constructor(), "GET " .. key, get_line())
						done[hash] = true
					end
				end
			end

			return rawget(self--[[# as any]], key)
		end
		meta.__newindex = function(self, key, val)
			if meta[key] == nil and not blacklist[key] then
				if not filter or key:find(filter, nil, true) then
					local line = get_line()
					local hash = key .. "-" .. line

					if not done[hash] then
						print(get_constructor(), "SET " .. key, line)
						done[hash] = true
					end
				end
			end

			rawset(self--[[# as any]], key, val)
		end
	end

	meta:DebugPropertyAccess()
	return meta
end

return class
