local table_new
local ok

if not _G.gmod then ok, table_new = pcall(require, "table.new") end

if not ok then table_new = function(size, records)
	return {}
end end

return table_new
