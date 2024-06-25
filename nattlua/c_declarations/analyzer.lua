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

local function cast(self, node)
	if node.type == "array" then
		local size

		if node.size == "?" then
			size = table.remove(self.dollar_signs_vars, 1)
		else
			size = LNumber(tonumber(node.size) or math.huge)
		end

		local obj = self.env.FFIArray:Call(self.analyzer, Tuple({size, cast(self, assert(node.of))})):Unpack()
		
		return obj
	elseif node.type == "pointer" then
		if
			node.of.type == "type" and
			#node.of.modifiers == 1 and
			node.of.modifiers[1] == "void"
		then
			return Any() -- TODO: is this true?
		end

		local res = (self.env.FFIPointer:Call(self.analyzer, Tuple({cast(self, assert(node.of))})):Unpack())

		local obj

		if self:GetContextValue("function_argument") == true then
			if
				node.of.type == "type" and
				node.of.modifiers[1] == "const" and
				node.of.modifiers[2] == "char"
			then
				obj = Union({res, String(), Nil()})
			end
		end

		obj = obj or Union({res, Nil()})

		return obj

	elseif node.type == "type" then
		local obj
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
							table.insert(self.current_nodes, 1, {ident = ident, tbl = tbl})
						end

						for _, v in ipairs(v.fields) do
							tbl:Set(LString(v.identifier), cast(self, v))
						end						

						if ident then
							table.remove(self.current_nodes, 1)
						end
					elseif ident then
						local current = self.current_nodes and self.current_nodes[1]

						if current and current.ident == v.identifier then
							-- recursion
							tbl = current.tbl
						else
							-- previously defined type or new type {}
							tbl = self.type_table:Get(LString(ident)) or self.type_table:Get(LString(ident)) or Table()
						end
					else
						error("what")
					end

					if ident then

						if ERROR_REDECLARE then
							local existing = self.type_table:Get(LString(ident))

							if existing and not existing:Equal(tbl) and not existing:IsEmpty() then
								error("attempt to redeclare type " .. ident .. " = " .. tostring(existing) .. " as " .. tostring(tbl) )
							end
						end
						
						self.type_table:Set(LString(ident), tbl)
					end

					obj = tbl
					break
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
								error("attempt to redeclare type " .. ident .. " = " .. tostring(existing) .. " as " .. tostring(tbl) )
							end
						end

						self.type_table:Set(LString(ident), tbl)
					end

					obj = Number()
					break
				end
			end
		end

		if obj then


			return obj
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
			obj = Number()
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
			obj = Number()
		elseif t == "bool" or t == "_Bool" then
			obj = Boolean()
		elseif t == "void" then
			obj = Nil()
		elseif t == "$" or t == "?" then
			obj = table.remove(self.dollar_signs_vars, 1)
		elseif t == "va_list" then
			obj = Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))
		else
			obj = self.type_table:Get(LString(t))
		end

		obj = obj or Number()
		
		return obj
	elseif node.type == "va_list" then
		local obj = Tuple({}):AddRemainder(Tuple({Any()}):SetRepeat(math.huge))

		return obj
	elseif node.type == "function" then
		local args = {}
		local rets = {}

		if not self.super_hack then
			self:PushContextValue("function_argument", true)
		end
		for i, v in ipairs(node.args) do
			table.insert(args, cast(self, v))
		end
		if not self.super_hack then
			self:PopContextValue("function_argument")
		end

		local obj = (Function(Tuple(args), Tuple({cast(self, assert(node.rets))})))

		return obj
	elseif node.type == "root" then
		return (cast(self, assert(node.of)))
	else
		error("unknown type " .. node.type)
	end
end

function META:AnalyzeRoot(ast, vars, typs)
	self.type_table = typs or Table()
	self.vars_table = vars or Table()
	local function callback(node, real_node, typedef)
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
		local obj = cast(self, node)

		if type(ident) == "string" then
			if typedef then
				self.type_table:Set(LString(ident), obj)
			else
				self.vars_table:Set(LString(ident), obj)
			end
		end

		if ident == "TYPEOF_CDECL" then
			self.super_hack = false -- TODO
		end
	end
	walk_cdeclarations(ast, callback)
	
	return self.vars_table, self.type_table
end

function META.New()
	local self = setmetatable({context_values = {}}, META)
	return self
end

return META