local LString = require("nattlua.types.string").LString
return {
	AnalyzeImport = function(self, node)
		-- ugly way of dealing with recursive import
		local root = node.RootStatement

		if root and root.kind ~= "root" then root = root.RootStatement end

		if root then
			return self:AnalyzeRootStatement(root)
		elseif node.data then
			return LString(node.data)
		end
	end,
}
