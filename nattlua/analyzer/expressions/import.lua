local types = require("nattlua.types.types")

return function(META)
    function META:AnalyzeImportExpression(node, env)        
        local args = self:AnalyzeExpressions(node.expressions, env)

        return self:AnalyzeRootStatement(node.root, table.unpack(args))
    end
end