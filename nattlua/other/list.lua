local list = {}
list.__index = list

for key, func in pairs(table) do
    list[key] = func
end

function list:last()
    return self[#self]
end

function list.new(...--[[#: any]])
    return setmetatable({...}, list)
end

function list.fromtable(tbl --[[#: {[number] = any} ]] )
    return setmetatable(tbl, list)
end

list.pairs = ipairs

return list