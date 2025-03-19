local math = _G.math
local setmetatable = _G.setmetatable
local ipairs = _G.ipairs
local table = _G.table
local type = _G.type
local assert = _G.assert
local tonumber = _G.tonumber
local class = require("nattlua.other.class")
local META = class.CreateTemplate("analyzer")
local Table = require("nattlua.types.table").Table
local Tuple = require("nattlua.types.tuple").Tuple
local Function = require("nattlua.types.function").Function
local Number = require("nattlua.types.number").Number
local String = require("nattlua.types.string").String
local LString = require("nattlua.types.string").LString
local LNumber = require("nattlua.types.number").LNumber
local Nil = require("nattlua.types.symbol").Nil
local Boolean = require("nattlua.types.union").Boolean
local Union = require("nattlua.types.union").Union
local Any = require("nattlua.types.any").Any
local walk_cdeclarations = require("nattlua.c_declarations.ast_walker")
META.OnInitialize = {}
require("nattlua.other.context_mixin")(META)
local valid_qualifiers = {
	["double"] = true,
	["float"] = true,
	["int8_t"] = true,
	["uint8_t"] = true,
	["int16_t"] = true,
	["uint16_t"] = true,
	["int32_t"] = true,
	["uint32_t"] = true,
	["char"] = true,
	["signed char"] = true,
	["unsigned char"] = true,
	["short"] = true,
	["short int"] = true,
	["signed short"] = true,
	["signed short int"] = true,
	["unsigned short"] = true,
	["unsigned short int"] = true,
	["int"] = true,
	["signed"] = true,
	["signed int"] = true,
	["unsigned"] = true,
	["unsigned int"] = true,
	["long"] = true,
	["long int"] = true,
	["signed long"] = true,
	["signed long int"] = true,
	["unsigned long"] = true,
	["unsigned long int"] = true,
	["float"] = true,
	["double"] = true,
	["long double"] = true,
	["size_t"] = true,
	["intptr_t"] = true,
	["uintptr_t"] = true,
	["int64_t"] = true,
	["uint64_t"] = true,
	["long long"] = true,
	["long long int"] = true,
	["signed long long"] = true,
	["signed long long int"] = true,
	["unsigned long long"] = true,
	["unsigned long long int"] = true,
}

local function cast(self, node)
	if node.type == "array" then
		local size

		if node.size == "?" then
			size = table.remove(self.dollar_signs_vars)
		else
			size = LNumber(tonumber(node.size) or math.huge)
		end

		local tup = self.analyzer:Call(self.env.FFIArray, Tuple({size, cast(self, assert(node.of))}))
		return tup:Unpack()
	elseif node.type == "pointer" then
		if
			node.of.type == "type" and
			#node.of.modifiers == 1 and
			node.of.modifiers[1] == "void"
		then
			return Any() -- TODO: is this true?
		end

		local res = (
			self.analyzer:Call(self.env.FFIPointer, Tuple({cast(self, assert(node.of))})):Unpack()
		)

		if self:GetContextRef("function_argument") == true then
			if
				node.of.type == "type" and
				node.of.modifiers[1] == "const" and
				node.of.modifiers[2] == "char"
			then
				return Union({res, String(), Nil()})
			end
		end

		return Union({res, Nil()})
	elseif node.type == "type" then
		for _, v in ipairs(node.modifiers) do
			if type(v) == "table" then
				-- only catch struct, union and enum TYPE declarations
				if v.type == "struct" or v.type == "union" then
					local ident = v.identifier
					local tbl

					if v.fields then
						tbl = Table()

						if ident then
							self.current_nodes = self.current_nodes or {}
							table.insert(self.current_nodes, {ident = ident, tbl = tbl})
						end

						for _, v in ipairs(v.fields) do
							local obj = cast(self, v)

							if not v.identifier then
								for _, kv in ipairs(obj:GetData()) do
									tbl:Set(kv.key, kv.val)
								end
							else
								tbl:Set(LString(v.identifier), obj)
							end
						end

						if ident then table.remove(self.current_nodes) end
					elseif ident then
						local current = self.current_nodes and self.current_nodes[#self.current_nodes]

						if current and current.ident == v.identifier then
							-- recursion
							tbl = current.tbl
						else
							-- previously defined type or new type {}
							tbl = self.type_table:Get(LString(ident)) or
								self.type_table:Get(LString(ident)) or
								Table()
						end
					else
						error("what")
					end

					if ident then self.type_table:Set(LString(ident), tbl) end

					return tbl
				elseif v.type == "enum" then
					local ident = v.identifier
					local tbl = Table()
					local i = 0

					for _, v in ipairs(v.fields) do
						tbl:Set(LString(v.identifier), LNumber(i))
						i = i + 1
					end

					if ident then
						if ERROR_REDECLARE then
							local existing = self.type_table:Get(LString(ident))

							if existing and not existing:Equal(tbl) and not existing:IsEmpty() then
								error(
									"attempt to redeclare type " .. ident .. " = " .. tostring(existing) .. " as " .. tostring(tbl)
								)
							end
						end

						self.type_table:Set(LString(ident), tbl)
					end

					return Number()
				end
			end
		end

		local t = node.modifiers[1]

		if t == "const" then t = assert(node.modifiers[2]) end

		if valid_qualifiers[t] then
			return Number()
		elseif t == "bool" or t == "_Bool" then
			return Boolean()
		elseif t == "void" then
			return Nil()
		elseif t == "$" or t == "?" then
			return table.remove(self.dollar_signs_vars)
		elseif t == "va_list" then
			return Tuple():AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
		else
			local s = LString(t)
			local obj, err = self.type_table:Get(s)

			if not obj then error(tostring(s) .. " is not a declared type") end

			if obj then return obj end
		end

		return Number()
	elseif node.type == "va_list" then
		return Tuple():AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
	elseif node.type == "function" then
		local args = {}
		local rets = {}

		if not self.super_hack then self:PushContextRef("function_argument") end

		for i, v in ipairs(node.args) do
			table.insert(args, cast(self, v))
		end

		if not self.super_hack then self:PopContextRef("function_argument") end

		return (Function(Tuple(args), Tuple({cast(self, assert(node.rets))})))
	elseif node.type == "root" then
		return (cast(self, assert(node.of)))
	end

	error("unknown type " .. node.type)
end

function META:AnalyzeRoot(ast, vars, typs)
	self.type_table = typs or Table()
	self.vars_table = vars or Table()

	local function callback(node, real_node, typedef)
		local ident = nil

		if
			node.modifiers and
			node.modifiers[#node.modifiers] and
			type(node.modifiers[#node.modifiers]) == "string"
		then
			ident = node.modifiers[#node.modifiers]
		end

		if not ident and real_node.tokens["potential_identifier"] then
			ident = real_node.tokens["potential_identifier"].value
		end

		if ident == "TYPEOF_CDECL" then self.super_hack = true -- TODO
		end

		local obj = cast(self, node)

		if type(ident) == "string" then
			if typedef then
				self.type_table:Set(LString(ident), obj)
			else
				self.vars_table:Set(LString(ident), obj)
			end
		end

		if ident == "TYPEOF_CDECL" then self.super_hack = false -- TODO
		end
	end

	walk_cdeclarations(ast, callback)
	return self.vars_table, self.type_table
end

function META.New()
	local self = setmetatable(
		{
			context_values = {},
			type_table = false,
			vars_table = false,
			analyzer = false,
			context_ref = false,
			super_hack = false,
			env = false,
			curent_nodes = false,
			dollar_signs_vars = false,
			dollar_signs_typs = false,
			current_nodes = false,
		},
		META
	)

	for i, v in ipairs(META.OnInitialize) do
		v(self)
	end

	return self
end

return META
