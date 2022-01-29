local assert = _G.assert
local tostring = _G.tostring
local setmetatable = _G.setmetatable
local type_errors = require("nattlua.types.error_messages")
local META = {}
META.__index = META
--[[#type META.Type = string]]
--[[#type META.@Self = {}]]
--[[#local type BaseType = META.@Self]]
--[[#type BaseType.@Name = "BaseTypeInstance"]]
--[[#type META.Type = string]]

function META.GetSet(tbl--[[#: ref any]], name--[[#: ref string]], default--[[#: ref any]])
	tbl[name] = default--[[# as NonLiteral<|default|>]]
--[[#	type tbl.@Self[name] = tbl[name] ]]
	tbl["Set" .. name] = function(self--[[#: tbl.@Self]], val--[[#: tbl[name] ]])
		self[name] = val
		return self
	end
	tbl["Get" .. name] = function(self--[[#: tbl.@Self]])--[[#: tbl[name] ]]
		return self[name]
	end
end

function META.IsSet(tbl--[[#: ref any]], name--[[#: ref string]], default--[[#: ref any]])
	tbl[name] = default--[[# as NonLiteral<|default|>]]
--[[#	type tbl.@Self[name] = tbl[name] ]]
	tbl["Set" .. name] = function(self--[[#: tbl.@Self]], val--[[#: tbl[name] ]])
		self[name] = val
		return self
	end
	tbl["Is" .. name] = function(self--[[#: tbl.@Self]])--[[#: tbl[name] ]]
		return self[name]
	end
end

--[[#type BaseType.Data = any | nil]]
--[[#type BaseType.Name = string | nil]]
--[[#type BaseType.parent = BaseType | nil]]
META:GetSet("AnalyzerEnvironment", nil--[[# as nil | "runtime" | "typesystem"]])

function META.Equal(a--[[#: BaseType]], b--[[#: BaseType]])
	--error("nyi " .. a.Type .. " == " .. b.Type)
end

function META:CanBeNil()
	return false
end

META:GetSet("Data", nil--[[# as nil | any]])

function META:GetLuaType()

	if self.Contract and self.Contract.TypeOverride then
		return self.Contract.TypeOverride
	end

	return self.TypeOverride or self.Type
end

do
	function META:IsUncertain()
		return self:IsTruthy() and self:IsFalsy()
	end

	function META:IsCertainlyFalse()
		return self:IsFalsy() and not self:IsTruthy()
	end

	function META:IsCertainlyTrue()
		return self:IsTruthy() and not self:IsFalsy()
	end

	META:IsSet("Falsy", false--[[# as boolean]])
	META:IsSet("Truthy", false--[[# as boolean]])
end

do
	function META:Copy()
		return self
	end

	function META:CopyInternalsFrom(obj --[[#: mutable BaseType]])
		self:SetNode(obj:GetNode())
		self:SetTokenLabelSource(obj:GetTokenLabelSource())
		self:SetLiteral(obj:IsLiteral())
		self:SetContract(obj:GetContract())
		self:SetName(obj:GetName())
		self:SetMetaTable(obj:GetMetaTable())
		self:SetAnalyzerEnvironment(obj:GetAnalyzerEnvironment())
		self:SetTypeOverride(obj:GetTypeOverride())
	end
end

do -- token, expression and statement association
	META:GetSet("Upvalue", nil--[[# as nil | any]])
	META:GetSet("TokenLabelSource", nil--[[# as nil | string]])
	META:GetSet("Node", nil--[[# as nil | any]])

	function META:SetNode(node--[[#: nil | any]])
		self.Node = node

		if node then
			node.inferred_type = self
		end

		return self
	end
end

do -- comes from tbl.@Name = "my name"
	META:GetSet("Name", nil--[[# as nil | BaseType]])

	function META:SetName(name--[[#: BaseType | nil]])
		if name then
			assert(name:IsLiteral())
		end
		
		self.Name = name
	end
end

do -- comes from tbl.@TypeOverride = "my name"
	META:GetSet("TypeOverride", nil--[[# as nil | BaseType]])

	function META:SetTypeOverride(name--[[#: any]])
		if type(name) == "table" and name:IsLiteral() then
			name = name:GetData()
		end

		self.TypeOverride = name
	end
end

do
--[[#	type BaseType.disabled_unique_id = number | nil]]
	META:GetSet("UniqueID", nil--[[# as nil | number]])
	local ref = 0

	function META:MakeUnique(b--[[#: boolean]])
		if b then
			self.UniqueID = ref
			ref = ref + 1
		else
			self.UniqueID = nil
		end

		return self
	end

	function META:IsUnique()
		return self.UniqueID ~= nil
	end

	function META:DisableUniqueness()
		self.disabled_unique_id = self.UniqueID
		self.UniqueID = nil
	end

	function META:EnableUniqueness()
		self.UniqueID = self.disabled_unique_id
	end

	function META:GetHash()
		return self.UniqueID
	end

	function META.IsSameUniqueType(a--[[#: BaseType]], b--[[#: BaseType]])
		if a.UniqueID and not b.UniqueID then return type_errors.other({a, "is a unique type"}) end
		if a.UniqueID ~= b.UniqueID then return type_errors.other({a, "is not the same unique type as ", a}) end
		return true
	end
end

do
	META:IsSet("Literal", false--[[# as boolean]])

	function META:CopyLiteralness(obj--[[#: BaseType]])
		self:SetLiteral(obj:IsLiteral())
	end
end

do -- operators
	function META:Call(...)
		return type_errors.other({
			"type ",
			self.Type,
			": ",
			self,
			" cannot be called",
		})
	end

	function META:Set(key--[[#: BaseType | nil]], val--[[#: BaseType | nil]])
		return type_errors.other(
			{
				"undefined set: ",
				self,
				"[",
				key,
				"] = ",
				val,
				" on type ",
				self.Type,
			}
		)
	end

	function META:Get(key--[[#: boolean]])
		return type_errors.other(
			{
				"undefined get: ",
				self,
				"[",
				key,
				"] on type ",
				self.Type,
			}
		)
	end

	function META:PrefixOperator(op--[[#: string]])
		return type_errors.other({"no operator ", op, " on ", self})
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

do -- contract
	function META:Seal()
		self:SetContract(self:GetContract() or self:Copy())
	end

	META:GetSet("Contract", nil--[[# as BaseType | nil]])
end

do
	META:GetSet("MetaTable", nil--[[# as BaseType | nil]])

	function META:GetMetaTable()
		local contract = self.Contract

		if contract then -- TODO
			if contract.MetaTable then return contract.MetaTable end
		end

		return self.MetaTable
	end
end

function META:Widen()
	self:SetLiteral(false)
	return self
end

function META:GetFirstValue()
	-- for tuples, this would return the first value in the tuple
	return self
end

function META.LogicalComparison(l--[[#: BaseType]], r--[[#: BaseType]], op--[[#: string]])
	if op == "==" then
		if l:IsLiteral() and r:IsLiteral() then
			return l:GetData() == r:GetData()
		end

		return nil
	end

	return type_errors.binary(op, l, r)
end

function META.New()
	return setmetatable({}--[[# as META.@Self]], META)
end

--[[# type META.BaseType = copy<|BaseType|> ]]

return META
