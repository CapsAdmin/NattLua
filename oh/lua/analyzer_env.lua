-- i think this file shouldn't exist, but i'm not sure how else to deal with this right now

local analyzer_env = {}

do
    analyzer_env.current_analyzer = {}

    function analyzer_env.PushAnalyzer(a)
        table.insert(analyzer_env.current_analyzer, 1, a)
    end

    function analyzer_env.PopAnalyzer()
        table.remove(analyzer_env.current_analyzer, 1)
    end

    function analyzer_env.GetCurrentAnalyzer()
        return analyzer_env.current_analyzer[1]
    end
end

function analyzer_env.GetBaseAnalyzer()

    if not analyzer_env.base_analyzer then
        local code_data = require("oh").File("oh/lua/base_typesystem.oh")
        
        assert(code_data:Lex())
        assert(code_data:Parse())
        

        local meta = require("oh.typesystem.types").Table({})
        analyzer_env.string_meta = meta

        assert(code_data:Analyze())

        local base = code_data.analyzer
        base.IndexNotFound = nil

		local g = base:TypeFromImplicitNode(code_data.SyntaxTree, "table")

		for k, v in pairs(base.env.typesystem) do
			g:Set(k, v)
		end

        g:Set("_G", g)
        
        meta:Set("__index", g:Get("string"))

        base:SetValue("_G", g, "typesystem")

        analyzer_env.base_analyzer = base
    end

    return analyzer_env.base_analyzer
end

return analyzer_env