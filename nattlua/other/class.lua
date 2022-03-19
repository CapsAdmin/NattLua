local class = {}

function class.CreateTemplate(type_name--[[#: ref string]])--[[#: ref Table]]
    local meta = {}
    meta.Type = type_name
    meta.__index = meta

    --[[# type meta.@Self = {}]]
    
    function meta.GetSet(tbl--[[#: ref tbl]], name--[[#: ref string]], default--[[#: ref any]])
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
        tbl[name] = default--[[# as NonLiteral<|default|>]]
        --[[#
            type tbl.@Self[name] = tbl[name] 
    
        ]]
        tbl["Set" .. name] = function(self--[[#: tbl.@Self]], val--[[#: tbl[name] ]])
            self[name] = val
            return self
        end
        tbl["Is" .. name] = function(self--[[#: tbl.@Self]])--[[#: tbl[name] ]]
            return self[name]
        end
    end

    return meta
end

return class