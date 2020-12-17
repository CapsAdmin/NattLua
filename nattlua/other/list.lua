local list = {}
list.__index = list

for key, func in pairs(table) do
    list[key] = func
end

function list.new(...)
    return setmetatable({...}, list)
end

function list.fromtable(tbl --[[#: {[number] = any} ]] )
    return setmetatable(tbl, list)
end

list.pairs = ipairs

return list