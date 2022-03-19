local class = {}

function class.GetSet(tbl--[[#: ref any]], name--[[#: ref string]], default--[[#: ref any]])
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

function class.IsSet(tbl--[[#: ref any]], name--[[#: ref string]], default--[[#: ref any]])
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

function class.CreateTemplate(type_name--[[#: ref string]])
    local meta = {}
    meta.Type = type_name
    meta.__index = meta
    meta.GetSet = class.GetSet
    meta.IsSet = class.IsSet
    return meta
end

return class