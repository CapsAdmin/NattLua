function table.destructure(tbl, fields, with_default)
    local out = {}
    for i, key in ipairs(fields) do
        out[i] = tbl[key]
    end
    if with_default then
        table.insert(out, 1, tbl)
    end
    return unpack(out)
end

function table.mergetables(tables) 
    local out = {}
    for i, tbl in ipairs(tables) do
        for k,v in pairs(tbl) do
            out[k] = v
        end
    end
    return out
end