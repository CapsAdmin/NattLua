local LString = require("nattlua.types.string").LString
return {
	AnalyzeImport = function(self, node)
		if node.RootStatement then
			return self:AnalyzeRootStatement(node.RootStatement)
		elseif node.data then
			return LString(node.data)
		end
	end,
}
