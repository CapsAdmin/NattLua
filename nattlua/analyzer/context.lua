local table_insert = _G.table.insert
local table_remove = _G.table.remove
local current_analyzer--[[#: List<|any|>]] = {}
local CONTEXT = {}

function CONTEXT:GetCurrentAnalyzer()
	return current_analyzer[1]
end

function CONTEXT:PushCurrentAnalyzer(b)
	table_insert(current_analyzer, 1, b)
end

function CONTEXT:PopCurrentAnalyzer()
	table_remove(current_analyzer, 1)
end

return CONTEXT