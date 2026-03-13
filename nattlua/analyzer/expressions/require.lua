local ConstString = require("nattlua.types.string").ConstString
local Nil = require("nattlua.types.symbol").Nil
local True = require("nattlua.types.symbol").True
local Table = require("nattlua.types.table").Table

local function is_nil(obj)
	return obj and obj.Type == "symbol" and obj:IsNil()
end

local function get_package_loaded(self)
	local package_value = self:GetLocalOrGlobalValue(ConstString("package"))

	if not package_value then return end

	package_value = self:GetFirstValue(package_value)

	if not package_value or package_value.Type ~= "table" then return end

	local loaded_key = ConstString("loaded")
	local loaded = self:IndexOperator(package_value, loaded_key)

	if not loaded or loaded.Type ~= "table" then
		loaded = Table()
		self:NewIndexOperator(package_value, loaded_key, loaded)
	end

	return loaded
end

return {
	AnalyzeRequire = function(self, node, cache)
		local root = node.RootStatement

		if root and root.Type ~= "statement_root" then root = root.RootStatement end

		if not cache then
			return self:GetFirstValue(self:AnalyzeRootStatement(root))
		end

		self.parsed_paths[cache] = true
		local package_loaded = get_package_loaded(self)
		local cache_key = ConstString(cache)

		if package_loaded then
			local keyval = package_loaded:FindKeyValExact(cache_key)
			local cached = keyval and keyval.val

			if cached and not is_nil(cached) then
				self.loaded_modules[cache] = self.loaded_modules[cache] or cached
				return self.loaded_modules[cache]
			end
		end

		if self.loaded_modules[cache] then return self.loaded_modules[cache] end
		if self.loading_modules[cache] then return self.loading_modules[cache] end
		self.loading_modules[cache] = Nil()

		local result = self:GetFirstValue(self:AnalyzeRootStatement(root))

		if is_nil(result) then result = True() end

		if package_loaded then
			self:NewIndexOperator(package_loaded, cache_key, result, true)
		end

		self.loaded_modules[cache] = result
		self.loading_modules[cache] = nil
		return self.loaded_modules[cache]
	end,
}
