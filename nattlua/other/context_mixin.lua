--ANALYZE
local table_insert = _G.table.insert
return function(META--[[#: ref any]])
	--[[#type META.@Self.context_values = Map<|string, {i = number, [number] = any}|>]]
	--[[#type META.@Self.context_ref = Map<|string, number|>]]

	META:AddInitializer(function(self--[[#: ref any]])
		self.context_values = {}--[[# as META.@Self.context_values]]
		self.context_ref = {}--[[# as META.@Self.context_ref]]
	end)

	do
		local NIL = {}

		function META:PushContextValue(key--[[#: string]], value--[[#: any]])
			if value == nil then value = NIL end

			io.write(key, "\n")
			self.context_values[key] = self.context_values[key] or {i = 0}
			self.context_values[key].i = self.context_values[key].i + 1
			self.context_values[key][self.context_values[key].i] = value
		end

		function META:GetContextValue(key--[[#: string]])
			local val = self.context_values[key] and
				self.context_values[key][self.context_values[key].i]

			if val == NIL then val = nil end

			return val
		end

		function META:GetContextValueOffset(key--[[#: string]], offset--[[#: number]])
			local val = self.context_values[key] and
				self.context_values[key][self.context_values[key].i - (
					offset or
					1
				) + 1]

			if val == NIL then val = nil end

			return val
		end

		function META.SetupContextValue(META--[[#: ref any]], name--[[#: ref string]])
			local key = "context_value_" .. name
			local key_i = key .. "_i"
			--[[#type META.@Self[key] = List<|any|>]]
			--[[#type META.@Self[key_i] = number]]
			local new = require("table.new")

			META:AddInitializer(function(self--[[#: ref any]])
				self[key] = new(100, 0)--[[# as META.@Self[key] ]]
				self[key_i] = 0--[[# as META.@Self[key_i] ]]
			end)

			local function push(self, value)
				if false--[[# as true]] then return end

				self[key_i] = self[key_i] + 1
				self[key][self[key_i]] = value
			end

			local function get(self)
				local val = self[key][self[key_i]]
				return val
			end

			local function get_offset(self, offset--[[#: number]])
				local val = self[key][self[key_i] - (offset or 1) + 1]
				return val
			end

			local function pop(self)
				if false--[[# as true]] then return end

				self[key][self[key_i]] = nil
				self[key_i] = self[key_i] - 1
			end

			local function get_stack(self)
				return self[key]
			end

			return push, get, get_offset, pop, get_stack
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
			return self.context_ref[key] and self.context_ref[key] ~= 0
		end

		function META:PopContextRef(key--[[#: string]])
			self.context_ref[key] = (self.context_ref[key] or 0) - 1
		end

		function META.SetupContextRef(META--[[#: ref any]], name--[[#: ref string]])
			local key = "context_ref_" .. name
			--[[#type META.@Self[key] = number]]

			META:AddInitializer(function(self--[[#: ref any]])
				self[key] = 0--[[# as META.@Self[key] ]]
			end)

			local function push(self)
				self[key] = self[key] + 1
			end

			local function get(self)
				return self[key] > 0
			end

			local function pop(self)
				self[key] = self[key] - 1
			end

			return push, get, pop
		end
	end
end
