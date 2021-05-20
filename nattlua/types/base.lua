local error = _G.error
local assert = _G.assert
local tostring = _G.tostring
local setmetatable = _G.setmetatable
local type_errors = require("nattlua.types.error_messages")


local META = {}
META.__index = META

function META.GetSet(tbl--[[#: literal any]], name--[[#: literal string]], default--[[#: literal any]])
	tbl[name] = default--[[# as NonLiteral<|default|>]]
	--[[# type tbl.@Self[name] = tbl[name] ]]
	
	tbl["Set" .. name] = function(self--[[#: tbl.@Self]], val--[[#: typeof tbl[name] ]])
		self[name] = val
		return self
	end
	
	tbl["Get" .. name] = function(self--[[#: tbl.@Self]])--[[#: typeof tbl[name] ]]
		return self[name]
	end
end

--[[#
	type META.Type = string

	META.@Self = {}
	type BaseType = META.@Self

	type BaseType.data = any | nil
	type BaseType.Contract = BaseType | nil
	type BaseType.MetaTable = BaseType | nil
	type BaseType.Name = string | nil
	type BaseType.literal = boolean | nil
	type BaseType.source_left = any | nil
	type BaseType.source = any | nil
	type BaseType.source_right = any | nil
	type BaseType.node = any | nil
	type BaseType.name = any | nil
	type BaseType.node_label = any | nil
	type BaseType.upvalue = any | nil
	type BaseType.upvalue_keyref = any | nil
	type BaseType.parent = BaseType | nil
]]

META:GetSet("Environment", nil --[[# as nil | "runtime" | "typesystem" ]])

function META.Equal(a--[[#: BaseType]], b--[[#: BaseType]])
	--error("nyi " .. a.Type .. " == " .. b.Type)
end

function META:CanBeNil()
	return false
end

function META:SetData(data--[[#: any]])
	self.data = data
end

function META:GetData()
	return self.data
end

do
	--[[#
		type BaseType.falsy = boolean | nil
		type BaseType.truthy = boolean | nil
	]]
	function META:IsUncertain()
		return self:IsTruthy() and self:IsFalsy()
	end

	function META:IsFalsy()
		return self.falsy
	end

	function META:IsTruthy()
		return self.truthy
	end

	function META:SetTruthy(b--[[#: boolean]])
		self.truthy = b
	end

	function META:SetFalsy(b--[[#: boolean]])
		self.falsy = b
	end
end

do
	function META:Copy()
		return self
	end

	function META:CopyInternalsFrom(obj)
		self.name = obj.name
		self.node = obj.node
		self.node_label = obj.node_label
		self.source = obj.source
		self.source_left = obj.source_left
		self.source_right = obj.source_right
		self.literal = obj.literal
		self:SetContract(obj:GetContract())
		self:SetName(obj:GetName())
		self.MetaTable = obj.MetaTable
		self.Environment = obj.Environment

		-- what about these?
		--self.truthy_union = obj.truthy_union
		--self.falsy_union = obj.falsy_union
		--self.upvalue_keyref = obj.upvalue_keyref
		--self.upvalue = obj.upvalue
	end
end

do -- token, expression and statement association

	--[[#
		type BaseType.unique_id = number | nil
		type BaseType.disabled_unique_id = number | nil
	]]

	function META:SetUpvalue(obj--[[#: any]], key--[[#: string | nil]])
		self.upvalue = obj
	
		if key then
			self.upvalue_keyref = key
		end
	end
	
	function META:SetSource(source)
		self.source = source
		return self
	end
	
	function META:SetBinarySource(l--[[#: BaseType]], r--[[#: BaseType]])
		self.source_left = l
		self.source_right = r
		return self
	end
	
	function META:SetNode(node)
		self.node = node
		return self
	end
	
	function META:GetNode()
		return self.node
	end
end


do -- comes from tbl.@Name = "my name"
	function META:SetName(name--[[#: BaseType]])
		if name then
			assert(name:IsLiteral())
		end

		self.Name = name
	end

	function META:GetName()
		return self.Name
	end
end

do
	local ref = 0

	function META:MakeUnique(b--[[#: boolean]])
		if b then
			self.unique_id = ref
			ref = ref + 1
		else
			self.unique_id = nil
		end

		return self
	end

	function META:IsUnique()
		return self.unique_id ~= nil
	end

	function META:GetUniqueID()
		return self.unique_id
	end

	function META:DisableUniqueness()
		self.disabled_unique_id = self.unique_id
		self.unique_id = nil
	end

	function META:EnableUniqueness()
		self.unique_id = self.disabled_unique_id
	end

	function META.IsSameUniqueType(a--[[#: BaseType]], b--[[#: BaseType]])
		if a.unique_id and not b.unique_id then return type_errors.other(tostring(a) .. "is a unique type") end
		if b.unique_id and not a.unique_id then return type_errors.other(tostring(b) .. "is a unique type") end
		if a.unique_id ~= b.unique_id then return type_errors.other(tostring(a) .. "is not the same unique type as " .. tostring(a)) end
		return true
	end
end

do
	function META:SetLiteral(b--[[#: boolean]])
		self.literal = b
		return self
	end

	function META:IsLiteral()
		return self.literal or false
	end

	function META:CopyLiteralness(obj--[[#: BaseType]])
		self:SetLiteral(obj:IsLiteral())
	end
end

do -- operators
	function META:Call(...)
		return type_errors.other("type " .. self.Type .. ": " .. tostring(self) .. " cannot be called")
	end

	function META:Set(key--[[#: BaseType | nil]], val--[[#: BaseType | nil]])
		return type_errors.other(
			"undefined set: " .. tostring(self) .. "[" .. tostring(key) .. "] = " .. tostring(val) .. " on type " .. self.Type
		)
	end

	function META:Get(key--[[#: boolean]])
		return type_errors.other(
			"undefined get: " .. tostring(self) .. "[" .. tostring(key) .. "]" .. " on type " .. self.Type
		)
	end

	function META:PrefixOperator(op--[[#: string]])
		return type_errors.other("no operator " .. op .. " on " .. tostring(self))
	end
end

do
	function META:SetParent(parent--[[#: BaseType | nil]])
		if parent then
			if parent ~= self then
				self.parent = parent
			end
		else
			self.parent = nil
		end
	end

	function META:GetRoot()
		local parent = self
		local done = {}

		while true do
			if not parent.parent or done[parent] then break end
			done[parent] = true
			parent = parent.parent
		end

		return parent
	end
end

do
	function META:SetMetaTable(tbl--[[#: BaseType | nil]])
		self.MetaTable = tbl
	end

	function META:GetMetaTable()
		if self.Contract and self.Contract.MetaTable then return self.Contract.MetaTable end
		return self.MetaTable
	end
end

do -- contract
	function META:Seal()
		self:SetContract(self:GetContract() or self:Copy())
	end

	function META:SetContract(val--[[#: BaseType | nil]])
		self.Contract = val
	end

	function META:GetContract()
		return self.Contract
	end
end


function META.New()
	return setmetatable({}, META)
end

return META
