local preprocess = require("nattlua.definitions.lua.ffi.preprocessor.preprocessor")
local Lexer = require("nattlua.lexer.lexer").New
local Parser = require("nattlua.definitions.lua.ffi.parser").New
local Code = require("nattlua.code").New
local Compiler = require("nattlua.compiler")
local Emitter = require("nattlua.definitions.lua.ffi.emitter").New
local walk_cdeclarations = require("nattlua.definitions.lua.ffi.ast_walker")
local buffer = require("string.buffer")

local function build_lua(c_header, expanded_defines, extra_lua)
	local code = Code(c_header, "test.c")
	local lex = Lexer(code)
	local tokens = lex:GetTokens()
	local parser = Parser(tokens, code)
	parser.OnError = function(parser, code, msg, start, stop, ...)
		Compiler.OnDiagnostic({}, code, msg, "error", start, stop, nil, ...)
	end
	local ast = parser:ParseRootNode()
	local buf = buffer.new()
	local typedefs = {}
	local valid_qualifiers = {
		["void"] = true,
		["double"] = true,
		["float"] = true,
		["int8_t"] = true,
		["uint8_t"] = true,
		["int16__t"] = true,
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
		["const"] = true,
		["volatile"] = true,
		["restrict"] = true,
	}
	local lua_keywords = {
		["and"] = true,
		["break"] = true,
		["do"] = true,
		["else"] = true,
		["elseif"] = true,
		["end"] = true,
		["false"] = true,
		["for"] = true,
		["function"] = true,
		["if"] = true,
		["in"] = true,
		["local"] = true,
		["nil"] = true,
		["not"] = true,
		["or"] = true,
		["repeat"] = true,
		["return"] = true,
		["then"] = true,
		["true"] = true,
		["until"] = true,
		["while"] = true,
	}
	local typedefss = {}
	-- Track function pointer typedefs
	local function_ptr_typedefs = {}

	-- Helper to check if a type is a Vulkan/custom type that needs parameterization
	local function is_custom_type(type_name)
		return typedefss[type_name]
	end

	-- Track which struct/union types have been fully defined (not just forward declared)
	local defined_structs = {}

	-- Emit a type reference, either as-is or as $ with parameterization
	-- skip_identifier: if true, don't emit the identifier part (for struct fields)
	-- self_struct: name of the struct being defined (for self-referential structs)
	local function emit_type_ref(decl, parameterized, skip_name, skip_identifier, self_struct)
		if decl.type == "root" then
			return emit_type_ref(decl.of, parameterized, skip_name, skip_identifier, self_struct)
		end

		if decl.type == "type" then
			local buf = buffer.new()

			for i, mod in ipairs(decl.modifiers) do
				if type(mod) == "string" then
					if skip_name and skip_name == mod then

					-- Skip this modifier (it's the typedef name itself)
					elseif
						skip_identifier and
						i == #decl.modifiers and
						not valid_qualifiers[mod] and
						not is_custom_type(mod)
					then

					-- Skip the last modifier if it's likely an identifier (not a type keyword)
					-- This handles cases where the parser puts the identifier as the last modifier
					elseif self_struct and mod == self_struct then
						-- Self-referential struct: use struct tag name for forward reference
						-- Don't parameterize it
						buf:put("struct ", mod, " ")
					elseif is_custom_type(mod) and parameterized then
						buf:put("$ ")
						table.insert(parameterized, mod)
					elseif is_custom_type(mod) then
						buf:put("$ ")
					else
						buf:put(mod, " ")
					end
				elseif type(mod) == "table" and (mod.type == "struct" or mod.type == "union") then
					-- Handle anonymous or named struct/union in type position
					-- If it's a self-reference, use the tag name directly
					if self_struct and mod.identifier == self_struct then
						buf:put(mod.type, " ", mod.identifier, " ")
					else
						buf:put(mod.type, " ")

						if mod.identifier then buf:put(mod.identifier, " ") end
					end
				end
			end

			return tostring(buf)
		elseif decl.type == "pointer" then
			local buf = buffer.new()
			-- Pass skip_identifier through for pointer types
			local base = emit_type_ref(decl.of, parameterized, skip_name, skip_identifier, self_struct)
			-- Trim trailing whitespace from base
			base = base:gsub("%s+$", "")
			buf:put(base)
			buf:put("*")

			for _, mod in ipairs(decl.modifiers or {}) do
				if type(mod) == "string" then
					-- Skip the typedef name if it matches
					if skip_name and skip_name == mod then

					-- Skip it
					elseif skip_identifier and not valid_qualifiers[mod] then

					-- Skip it (likely an identifier)
					else
						buf:put(" ", mod)
					end
				end
			end

			return tostring(buf)
		elseif decl.type == "array" then
			local base = emit_type_ref(decl.of, parameterized, skip_name, skip_identifier, self_struct)
			base = base:gsub("%s+$", "")
			local size_str = decl.size or ""
			return base .. "[" .. size_str .. "]"
		end

		return ""
	end

	-- Emit a complete declaration
	local function emit(decl, ident, is_typedef)
		if decl.type == "root" then return emit(decl.of, ident, is_typedef) end

		-- Handle function pointer typedefs (e.g., typedef void (*PFN_foo)(...))
		if decl.type == "pointer" and decl.of and decl.of.type == "function" then
			-- Function pointer typedef - use ffi.typeof
			local buf = buffer.new()
			local params = {}
			local func = decl.of
			buf:put("mod.", ident, " = ffi.typeof([[")
			buf:put(emit_type_ref(func.rets, params, nil, true))
			buf:put("(*)(")

			for i, arg in ipairs(func.args) do
				buf:put(emit_type_ref(arg, params, nil, true))

				if arg.identifier then buf:put(" ", arg.identifier) end

				if i < #func.args then buf:put(", ") end
			end

			buf:put(")]]")

			for _, param in ipairs(params) do
				buf:put(", mod.", param)
			end

			buf:put(")")
			typedefss[ident] = true
			function_ptr_typedefs[ident] = true
			return tostring(buf)
		end

		-- Handle pointer/array typedefs (e.g., typedef struct Foo* VkBuffer)
		if decl.type == "pointer" or decl.type == "array" then
			-- Check if this is an opaque handle (struct without definition)
			local is_opaque = false

			if decl.type == "pointer" and decl.of and decl.of.type == "type" then
				for _, mod in ipairs(decl.of.modifiers) do
					if type(mod) == "table" and (mod.type == "struct" or mod.type == "union") then
						-- Opaque handle: struct/union mentioned but not defined (no fields)
						if not mod.fields then
							is_opaque = true

							break
						end
					end
				end
			end

			local buf = buffer.new()
			local params = {}
			buf:put("mod.", ident, " = ffi.typeof([[")

			if is_opaque then
				-- Use void* for opaque handles
				buf:put("void*")
			else
				buf:put(emit_type_ref(decl, params, ident))
			end

			buf:put("]]")

			for _, param in ipairs(params) do
				buf:put(", mod.", param)
			end

			buf:put(")")
			typedefss[ident] = true
			return tostring(buf)
		end

		if decl.type == "type" then
			-- Check if this is a struct/union/enum definition
			for _, v in ipairs(decl.modifiers) do
				if type(v) == "table" then
					if v.type == "enum" then
						local buf = buffer.new()
						buf:put("mod.", ident, " = ffi.typeof([[enum")

						if v.fields then
							buf:put(" {\n")

							for i, field in ipairs(v.fields) do
								buf:put("\t", field.identifier)

								if field.expression then buf:put(" = ", field.expression:Render()) end

								buf:put(",\n")
							end

							buf:put("}]])")
						else
							buf:put("]])")
						end

						typedefss[ident] = true
						return tostring(buf)
					elseif v.type == "struct" or v.type == "union" then
						local buf = buffer.new()
						local params = {}
						local struct_name = ident or v.identifier
						-- Mark this struct as being defined (not just declared)
						typedefss[struct_name] = true
						buf:put("mod.", struct_name, " = ffi.typeof([[", v.type)

						if v.fields then
							buf:put(" {\n")

							for _, field in ipairs(v.fields) do
								buf:put("\t")
								-- Check if this field is self-referential
								local is_self_ref = false

								local function check_self_ref(decl)
									if decl.type == "root" then
										return check_self_ref(decl.of)
									elseif decl.type == "pointer" or decl.type == "array" then
										-- Only replace if it's a pointer to self
										if decl.type == "pointer" then
											return check_self_ref(decl.of)
										end
									elseif decl.type == "type" then
										for _, mod in ipairs(decl.modifiers) do
											if mod == struct_name then
												return true
											elseif type(mod) == "table" and mod.identifier == struct_name then
												return true
											end
										end
									end

									return false
								end

								is_self_ref = check_self_ref(field)
								-- Extract array dimensions if present
								local array_dims = {}
								local base_decl = field

								while base_decl do
									if base_decl.type == "root" then
										base_decl = base_decl.of
									elseif base_decl.type == "array" then
										table.insert(array_dims, 1, base_decl.size or "")
										base_decl = base_decl.of
									else
										break
									end
								end

								local field_type

								if is_self_ref then
									-- Use void* for self-referential pointers
									-- Navigate to the pointer declaration
									local ptr_decl = field

									if field.type == "root" then ptr_decl = field.of end

									if ptr_decl.type == "pointer" then
										-- Collect all const/volatile modifiers
										local quals = {}

										-- Check for const in the pointed-to type
										if ptr_decl.of and ptr_decl.of.type == "type" then
											for _, mod in ipairs(ptr_decl.of.modifiers or {}) do
												if mod == "const" or mod == "volatile" then
													table.insert(quals, mod)
												end
											end
										end

										-- Build the type string
										if #quals > 0 then
											field_type = table.concat(quals, " ") .. " void*"
										else
											field_type = "void*"
										end
									else
										field_type = emit_type_ref(field, params, nil, true, struct_name)
									end
								else
									-- Get base type without array dimensions
									local base_type_decl = field

									while base_type_decl.type == "root" or base_type_decl.type == "array" do
										if base_type_decl.type == "root" then
											base_type_decl = base_type_decl.of
										elseif base_type_decl.type == "array" then
											base_type_decl = base_type_decl.of
										end
									end

									field_type = emit_type_ref(base_type_decl, params, nil, true, struct_name)
								end

								-- Trim whitespace
								field_type = field_type:gsub("%s+$", "")
								buf:put(field_type)

								if field.identifier then buf:put(" ", field.identifier) end

								-- Add array dimensions after identifier
								for _, dim in ipairs(array_dims) do
									buf:put("[", dim, "]")
								end

								buf:put(";\n")
							end

							buf:put("}]]")
						else
							buf:put("]]")
						end

						-- Add parameterized types
						for _, param in ipairs(params) do
							buf:put(", mod.", param)
						end

						if v.fields then
							buf:put(")\n")
							buf:put(
								"ffi.metatype(mod.",
								struct_name,
								", {__tostring = function(s) return ('struct " .. struct_name .. "[%p]'):format(s) end,__new = function(T, t) if not t then return N(T) end \n"
							)

							if v.type == "union" then
								-- For unions: create object, then assign whichever field is provided
								buf:put("local obj = N(T)\n")

								for i, field in ipairs(v.fields) do
									if field.identifier then
										if lua_keywords[field.identifier] then
											buf:put(
												"if t['",
												field.identifier,
												"'] ~= nil then obj.",
												field.identifier,
												" = t['",
												field.identifier,
												"'] end\n"
											)
										else
											buf:put(
												"if t.",
												field.identifier,
												" ~= nil then obj.",
												field.identifier,
												" = t.",
												field.identifier,
												" end\n"
											)
										end
									end
								end

								buf:put("return obj\n")
							else
								-- For structs: use the original N(T, ...) pattern
								buf:put("return N(\n\tT,\n")

								for i, field in ipairs(v.fields) do
									if field.identifier then
										if lua_keywords[field.identifier] then
											buf:put("\tt['", field.identifier, "']")
										else
											buf:put("\tt.", field.identifier)
										end

										if i ~= #v.fields then buf:put(",") end

										buf:put("\n")
									end
								end

								buf:put(")\n")
							end

							buf:put("end,\n})")
						end

						return tostring(buf)
					end
				end
			end

			-- Simple typedef
			local buf = buffer.new()
			local params = {}
			buf:put("mod.", ident, " = ffi.typeof([[")
			buf:put(emit_type_ref(decl, params, ident))
			buf:put("]]")

			-- Add parameterized types
			for _, param in ipairs(params) do
				buf:put(", mod.", param)
			end

			buf:put(")")
			typedefss[ident] = true
			return tostring(buf)
		elseif decl.type == "function" then
			local buf = buffer.new()
			local params = {}
			buf:put("ffi.cdef([[")
			buf:put(emit_type_ref(decl.rets, params, nil, true))
			buf:put(" ", ident, "(")

			for i, arg in ipairs(decl.args) do
				buf:put(emit_type_ref(arg, params, nil, true))

				if arg.identifier then buf:put(" ", arg.identifier) end

				if i < #decl.args then buf:put(", ") end
			end

			buf:put(");]]")

			-- Add parameterized types
			for _, param in ipairs(params) do
				buf:put(", mod.", param)
			end

			buf:put(")")
			return tostring(buf)
		end

		error(
			"Unhandled declaration type: " .. tostring(decl.type) .. " for identifier: " .. tostring(ident)
		)
	end

	-- Initialize output buffer with header
	buf:put("local ffi = require(\"ffi\")\n")
	buf:put("local N = ffi.new\n")
	buf:put("local mod = {}\n\n")

	if extra_lua then buf:put(extra_lua, "\n\n") end

	if expanded_defines then
		buf:put("do -- Preprocessor Definitions\n")
		local sorted = {}

		for k, v in pairs(expanded_defines) do
			table.insert(sorted, {key = v.key, val = v.val})
		end

		table.sort(sorted, function(a, b)
			return a.key < b.key
		end)

		for _, def in ipairs(sorted) do
			buf:put("\tmod.", def.key, " = ", def.val, "\n")
		end

		buf:put("end\n")
	end

	-- Helper to get the statement node from real_node
	local function get_statement_node(node)
		-- Walk up the parent chain to find the statement (expression_c_declaration)
		while node do
			if node.Type == "expression_c_declaration" then return node end

			node = node.parent
		end

		return nil
	end

	-- Single pass: emit all declarations in order
	walk_cdeclarations(ast, function(decl, ident, is_typedef, real_node)
		-- Handle non-typedef declarations
		if not is_typedef then
			-- Check if this is a static const variable (a constant)
			if decl.type ~= "function" then
				-- This is a variable - check if it has an initializer
				local has_static = false
				local has_const = false
				-- Check modifiers in the declaration
				local check_decl = decl

				while check_decl do
					if check_decl.type == "type" then
						for _, mod in ipairs(check_decl.modifiers or {}) do
							if mod == "static" then has_static = true end

							if mod == "const" then has_const = true end
						end

						break
					elseif check_decl.type == "root" then
						check_decl = check_decl.of
					else
						break
					end
				end

				-- Check if real_node has an expression (initializer)
				if has_static and has_const then
					-- Try to find the value in the statement node
					local stmt = get_statement_node(real_node)
					local value = nil

					if stmt and stmt.default_expression then
						local ok, result = pcall(function()
							return stmt.default_expression:Render()
						end)

						if ok then value = result end
					end

					if value then
						-- Clean up the value (remove ULL suffix for Lua, convert to proper format)
						value = value:gsub("ULL$", "ULL") -- Keep ULL for now
						buf:put("mod.", ident, " = ", value, "\n")
						return
					end
				end

				-- Skip non-function, non-constant variables
				return
			end
		end

		local result = emit(decl, ident, is_typedef)

		if result and result ~= "" then buf:put(result, "\n") end
	end)

	-- Add return statement
	buf:put("\nreturn mod\n")
	return tostring(buf)
end

return build_lua
