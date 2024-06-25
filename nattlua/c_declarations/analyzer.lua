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

local function cast(self, node, out)
	local env = self.env
	local analyzer = self.analyzer
	local typs = self.typs
	local vars = self.vars

	if node.type == "array" then
		local size

		if node.size == "?" then
			size = table.remove(self.dollar_signs_vars, 1)
		else
			size = LNumber(tonumber(node.size) or math.huge)
		end

		return (
			env.FFIArray:Call(analyzer, Tuple({size, cast(self, assert(node.of), out)})):Unpack()
		)
	elseif node.type == "pointer" then
		if
			node.of.type == "type" and
			#node.of.modifiers == 1 and
			node.of.modifiers[1] == "void"
		then
			return Any() -- TODO: is this true?
		end

		local res = (env.FFIPointer:Call(analyzer, Tuple({cast(self, assert(node.of), out)})):Unpack())

		if self:GetContextValue("function_argument") == true then
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

						if not ident and #node.modifiers > 0 then
							ident = node.modifiers[#node.modifiers].identifier or "anon"
						end

						self.current_nodes = self.current_nodes or {}
						table.insert(self.current_nodes, 1, {ident = ident, tbl = tbl})

						--tbl:Set(LString("__id"), LString(("%p"):format({})))
						for _, v in ipairs(v.fields) do
							tbl:Set(LString(v.identifier), cast(self, v, out))
						end

						table.remove(self.current_nodes, 1)

						local existing = self.typs_write:Get(LString(ident))

						if existing and not existing:Equal(tbl) and not existing:IsEmpty() then
							error("attempt to redeclare type " .. ident .. " = " .. tostring(existing) .. " as " .. tostring(tbl) )
						end

						table.insert(out, {identifier = ident, obj = tbl})
						self.typs_write:Set(LString(ident), tbl)
					else
						local current = self.current_nodes and self.current_nodes[1]

						if current and current.ident == v.identifier then
							-- recursion
							tbl = current.tbl
						else
							-- previously defined type or new type {}
							tbl = typs:Get(LString(ident)) or self.typs_write:Get(LString(ident)) or Table()
						end

						table.insert(out, {identifier = ident, obj = tbl})
						
						self.typs_write:Set(LString(ident), tbl)
					end

					return tbl
				elseif v.type == "enum" then
					local ident = v.identifier 

					if not ident and #node.modifiers > 0 then
						ident = node.modifiers[#node.modifiers].identifier or "anon"
					end
					
					local tbl = Table()
					local i = 0

					for _, v in ipairs(v.fields) do
						tbl:Set(LString(v.identifier), LNumber(i))
						i = i + 1
					end

					table.insert(out, {identifier = ident, obj = tbl})
					self.typs_write:Set(LString(ident), tbl)

					return Number()
				end
			end
		end

		local t = node.modifiers[1]

		if
			t == "double" or
			t == "float" or
			t == "int8_t" or
			t == "uint8_t" or
			t == "int16_t" or
			t == "uint16_t" or
			t == "int32_t" or
			t == "uint32_t" or
			t == "char" or
			t == "signed char" or
			t == "unsigned char" or
			t == "short" or
			t == "short int" or
			t == "signed short" or
			t == "signed short int" or
			t == "unsigned short" or
			t == "unsigned short int" or
			t == "int" or
			t == "signed" or
			t == "signed int" or
			t == "unsigned" or
			t == "unsigned int" or
			t == "long" or
			t == "long int" or
			t == "signed long" or
			t == "signed long int" or
			t == "unsigned long" or
			t == "unsigned long int" or
			t == "float" or
			t == "double" or
			t == "long double" or
			t == "size_t" or
			t == "intptr_t" or
			t == "uintptr_t"
		then
			return Number()
		elseif
			t == "int64_t" or
			t == "uint64_t" or
			t == "long long" or
			t == "long long int" or
			t == "signed long long" or
			t == "signed long long int" or
			t == "unsigned long long" or
			t == "unsigned long long int"
		then
			return Number()
		elseif t == "bool" or t == "_Bool" then
			return Boolean()
		elseif t == "void" then
			return Nil()
		elseif t == "$" or t == "?" then
			return table.remove(self.dollar_signs_vars, 1)
		elseif t == "va_list" then
			return Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
		end

		local tbl = typs:Get(LString(t)) or self.typs_write:Get(LString(t))

		if tbl then return (tbl) end

		return (Number())
	elseif node.type == "va_list" then
		return Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
	elseif node.type == "function" then
		local args = {}
		local rets = {}

		if not self.super_hack then
			self:PushContextValue("function_argument", true)
		end
		for i, v in ipairs(node.args) do
			table.insert(args, cast(self, v, out))
		end
		if not self.super_hack then
			self:PopContextValue("function_argument")
		end

		return (Function(Tuple(args), Tuple({cast(self, assert(node.rets), out)})))
	elseif node.type == "root" then
		return (cast(self, assert(node.of), out))
	else
		error("unknown type " .. node.type)
	end
end

function META:AnalyzeRoot(ast, vars, typs)
	-- new output
	self.typs = typs or Table()
	self.vars = vars or Table()
	local typs = Table()
	local vars = Table()
	self.typs_write = typs
	self.vars_write = vars
	local function callback(node, real_node, typedef)
		local out = {}

		local ident = nil 
		
		if node.modifiers and node.modifiers[#node.modifiers] and type(node.modifiers[#node.modifiers]) == "string" then
			ident = node.modifiers[#node.modifiers]
		end
		
		if not ident and real_node.tokens["potential_identifier"] then 
			ident = real_node.tokens["potential_identifier"].value
		end

		if ident == "TYPEOF_CDECL" then
			self.super_hack = true -- TODO
		end
		local obj = cast(self, node, out)
		if ident == "TYPEOF_CDECL" then
			self.super_hack = false -- TODO
		end

		if not ident then ident = "uhhoh" end
		
		if ident then
			if typedef then
				typs:Set(LString(ident), obj)
			else
				vars:Set(LString(ident), obj)
			end
		end

		for _, typedef in ipairs(out) do
			local ident = typedef.identifier
			typs:Set(LString(ident), typedef.obj)
		end
	end
	walk_cdeclarations(ast, callback)
	
	return vars, typs
end

function META.New()
	local self = setmetatable({context_values = {}}, META)
	return self
end

return META