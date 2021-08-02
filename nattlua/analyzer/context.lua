local current_analyzer = {}

local CONTEXT = {}

function CONTEXT:GetCurrentAnalyzer()
    return current_analyzer[1]
end

function CONTEXT:PushCurrentAnalyzer(b)
    table.insert(current_analyzer, 1, b)
end

function CONTEXT:PopCurrentAnalyzer()
    table.remove(current_analyzer, 1)
end

return CONTEXT