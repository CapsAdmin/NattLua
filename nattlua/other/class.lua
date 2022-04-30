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

	function meta:DebugPropertyAccess()
		meta.__index = function(self, key)
			if meta[key] ~= nil then return meta[key] end

			if not blacklist[key] then print(key) end

			return rawget(self, key)
		end
		meta.__newindex = function(self, key, val)
			if not blacklist[key] then print(key, val) end

			rawset(self, key, val)
		end
	end

	return meta
end

return class
