local has_clear, table_clear = pcall(require, "table.clear")

if has_clear then
	return table_clear
end

return function(t) 
    for k,v in pairs(t) do
        t[k] = nil
    end
end

