--ANALYZE
return function(META--[[#: ref any]])
	--[[#type META.@Self.context_values = Map<|string, List<|any|>|>]]
	--[[#type META.@Self.context_ref = Map<|string, number|>]]

	table.insert(META.OnInitialize, function(self--[[#: ref any]])
		self.context_values = {}--[[# as META.@Self.context_values]]
		self.context_ref = {}--[[# as META.@Self.context_ref]]
	end)

	do
		local table_insert = table.insert
		local table_remove = table.remove

		function META:PushContextValue(key--[[#: string]], value--[[#: any]])
			self.context_values[key] = self.context_values[key] or {}
			table_insert(self.context_values[key], 1, value)
		end

		function META:GetContextValue(key--[[#: string]], level--[[#: number | nil]])
			return self.context_values[key] and self.context_values[key][level or 1]
		end

		function META:PopContextValue(key--[[#: string]])
			-- typesystem doesn't know that a value is always inserted before it's popped
			return (table_remove--[[# as any]])(self.context_values[key], 1)
		end
	end

	do
		function META:PushContextRef(key--[[#: string]])
			self.context_ref[key] = (self.context_ref[key] or 0) + 1
		end

		function META:GetContextRef(key--[[#: string]])
			return self.context_ref[key] and self.context_ref[key] > 0
		end

		function META:PopContextRef(key--[[#: string]])
			self.context_ref[key] = (self.context_ref[key] or 0) - 1
		end
	end
end