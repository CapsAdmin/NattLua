return function(META) 
    function META:AnalyzeTypeCodeStatement(statement)
        local code = statement.lua_code.value.value:sub(3)
        self:CallLuaTypeFunction(statement.lua_code, self:CompileLuaTypeCode(code, statement.lua_code))
    end
end