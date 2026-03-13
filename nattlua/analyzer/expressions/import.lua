local LString = require("nattlua.types.string").LString
local Nil = require("nattlua.types.symbol").Nil

local function analyze_import_value(self, node, root)
	if root then
		return self:AnalyzeRootStatement(root)
	elseif node.data then
		return LString(node.data)
	end

	return Nil()
end

return {
	AnalyzeImport = function(self, node, cache)
		-- ugly way of dealing with recursive import
		local root = node.RootStatement

		if root and root.Type ~= "statement_root" then root = root.RootStatement end

		if cache then
			if cache:sub(1, 2) == "./" then cache = cache:sub(3) end

			self.parsed_paths[cache] = true
			if self.loaded_modules[cache] then return self.loaded_modules[cache] end
			self.loaded_modules[cache] = Nil()

			local result = analyze_import_value(self, node, root)
			self.loaded_modules[cache] = result
			return self.loaded_modules[cache]
		else
			return analyze_import_value(self, node, root)
		end

		return Nil()
	end,
}
