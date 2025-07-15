--ANALYZE
return function(META--[[#: ref any]])
	--[[#type META.@Self.context_values = Map<|string, {i = number, [number] = any}|>]]
	--[[#type META.@Self.context_ref = Map<|string, number|>]]

	table.insert(META.OnInitialize, function(self--[[#: ref any]])
		self.context_values = {}--[[# as META.@Self.context_values]]
		self.context_ref = {}--[[# as META.@Self.context_ref]]
	end)

	do
		local NIL = {}

		function META:PushContextValue(key--[[#: string]], value--[[#: any]])
			if value == nil then value = NIL end

			self.context_values[key] = self.context_values[key] or {i = 0}
			self.context_values[key].i = self.context_values[key].i + 1
			self.context_values[key][self.context_values[key].i] = value
		end

		function META:GetContextValue(key--[[#: string]], level--[[#: number | nil]])
			local val = self.context_values[key] and
				self.context_values[key][self.context_values[key].i - (
					level or
					1
				) + 1]

			if val == NIL then val = nil end

			return val
		end

		function META:PopContextValue(key--[[#: string]])
			-- typesystem doesn't know that a value is always inserted before it's popped
			if false--[[# as true]] then return end

			self.context_values[key][self.context_values[key].i] = nil
			self.context_values[key].i = self.context_values[key].i - 1
		end

		function META:GetContextStack(key)
			return self.context_values[key]
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
