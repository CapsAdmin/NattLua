local LString = require("nattlua.types.string").LString
local Nil = require("nattlua.types.symbol").Nil
return {
	AnalyzeImport = function(self, node, cache)
		-- ugly way of dealing with recursive import
		local root = node.RootStatement

		if root and root.kind ~= "root" then root = root.RootStatement end

		if cache then
			if cache:sub(1, 2) == "./" then cache = cache:sub(3) end

			self.parsed_paths[cache] = true

			if self.loaded_modules[cache] then return self.loaded_modules[cache] end

			if root then
				self.loaded_modules[cache] = self:AnalyzeRootStatement(root)
			elseif node.data then
				self.loaded_modules[cache] = LString(node.data)
			end

			return self.loaded_modules[cache]
		else
			if root then
				return self:AnalyzeRootStatement(root)
			elseif node.data then
				return LString(node.data)
			end
		end

		return Nil()
	end,
}
