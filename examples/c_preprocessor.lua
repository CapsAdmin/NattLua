local preprocess = require("nattlua.definitions.lua.ffi.preprocessor.preprocessor")
local Lexer = require("nattlua.lexer.lexer").New
local Parser = require("nattlua.definitions.lua.ffi.parser").New
local Code = require("nattlua.code").New
local Compiler = require("nattlua.compiler")
local Emitter = require("nattlua.definitions.lua.ffi.emitter").New
local walk_cdeclarations = require("nattlua.definitions.lua.ffi.ast_walker")
local buffer = require("string.buffer")

local function build_lua(c_header)
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
	local struct_names = {}

	local function emit(decl, ident, collect_structs, skip_identifier)
		if decl.type == "type" then
			local has_inline_def = false

			for _, v in ipairs(decl.modifiers) do
				if type(v) == "table" then
					has_inline_def = true

					if v.type == "enum" then
						if v.identifier and collect_structs then
							struct_names[v.identifier] = true
						end

						local buf = buffer.new()
						buf:put("enum")

						-- Only include enum name when NOT collecting for typeof
						-- ffi.typeof doesn't support named enums
						if v.identifier and not collect_structs then
							buf:put(" ", v.identifier)
						end

						buf:put(" {\n")
						local i = 0

						for _, field in ipairs(v.fields) do
							buf:put("\t", field.identifier, " = ", i, ",\n")
							i = i + 1
						end

						buf:put("}")
						return tostring(buf)
					elseif v.type == "struct" or v.type == "union" then
						if v.identifier and collect_structs then
							struct_names[v.identifier] = true
						end

						local buf = buffer.new()
						buf:put(v.type)

						-- Only include struct name when NOT collecting for typeof
						-- ffi.typeof doesn't support named structs
						if v.identifier and not collect_structs then
							buf:put(" ", v.identifier)
						end

						if v.fields then
							buf:put(" {\n")

							for _, field in ipairs(v.fields) do
								-- For arrays/pointers, we need to emit: type identifier[size];
								-- The identifier is on field.identifier, not in the type
								-- Pass field.identifier as skip_identifier to prevent it from being included in the type
								local field_type, array_suffix = emit(field, nil, collect_structs, field.identifier)

								if field.identifier then
									buf:put("\t", field_type, " ", field.identifier)

									if array_suffix then buf:put(array_suffix) end

									buf:put(";\n")
								else
									buf:put("\t", field_type, ";\n")
								end
							end

							buf:put("}")
						end

						return tostring(buf)
					else
						error("Unhandled type: " .. v.type)
					end
				end
			end

			-- If we didn't find an inline definition, build the type from modifiers
			if not has_inline_def then
				local buf = buffer.new()
				local parts = {}

				for i, v in ipairs(decl.modifiers) do
					if type(v) == "string" then
						-- Skip the last modifier if it matches skip_identifier or decl.identifier
						-- (ast_walker places field names as the last modifier)
						if
							i == #decl.modifiers and
							(
								(
									skip_identifier and
									v == skip_identifier
								)
								or
								(
									decl.identifier and
									v == decl.identifier
								)
							)
						then

						-- Skip - this is the field name, not part of the type
						elseif typedefs[v] or struct_names[v] then
							table.insert(parts, "$")
						elseif collect_structs then
							-- When collecting for struct definitions (typedef), include all type names
							-- This ensures field types like VkDeviceAddress are preserved
							table.insert(parts, v)
						elseif
							valid_qualifiers[v] or
							v == "void" or
							v == "const" or
							v == "volatile" or
							v == "restrict"
						then
							-- Only include actual type qualifiers, not identifiers
							table.insert(parts, v)
						end
					-- Skip unknown strings (they might be function/variable names)
					end
				end

				for i, part in ipairs(parts) do
					buf:put(part)

					if i < #parts then buf:put(" ") end
				end

				return tostring(buf)
			end
		elseif decl.type == "root" then
			-- Pass ident through only for function nodes at the top level
			-- If ident is provided AND this is a function, pass it through
			-- Otherwise, don't pass ident to avoid it appearing in return types, etc.
			-- IMPORTANT: Never pass ident through root nodes, even for functions
			-- The function case will handle adding the identifier itself
			-- But DO pass skip_identifier through so nested nodes can filter it out
			return emit(decl.of, nil, collect_structs, skip_identifier)
		elseif decl.type == "pointer" then
			local buf = buffer.new()
			-- Pass skip_identifier to avoid including field names in the type
			buf:put(emit(decl.of, nil, collect_structs, skip_identifier))
			buf:put(" *")

			for _, mod in ipairs(decl.modifiers or {}) do
				-- Skip the identifier if it matches skip_identifier
				if not (skip_identifier and mod == skip_identifier) then
					buf:put(" ", mod)
				end
			end

			return tostring(buf)
		elseif decl.type == "array" then
			-- For arrays, if the innermost type has an identifier (field name),
			-- we return the type and array suffix separately
			-- This allows the caller to emit: type identifier[size];
			-- Pass decl.identifier OR skip_identifier to skip it from the type's modifiers
			local skip_id = decl.identifier or skip_identifier
			local inner_type, inner_suffix = emit(decl.of, nil, collect_structs, skip_id)
			local array_suffix = "[" .. decl.size .. "]"

			-- If there's already a suffix from nested arrays, combine them
			if inner_suffix then array_suffix = inner_suffix .. array_suffix end

			-- Only return suffix separately if we're the outermost array (skip_identifier is nil)
			-- Inner arrays should just combine with their children
			if not skip_identifier then
				-- Check if there's an identifier anywhere in the tree
				local function has_identifier(node)
					if node.identifier then return true end

					if node.of then return has_identifier(node.of) end

					return false
				end

				-- If any node has an identifier, return type and suffix separately
				if has_identifier(decl) then return inner_type, array_suffix end
			end

			-- No identifier or we're a nested array - combine type and array
			return inner_type .. array_suffix
		end

		local t = decl.modifiers and decl.modifiers[1]

		if valid_qualifiers[t] then
			local buf = buffer.new()

			for i, mod in ipairs(decl.modifiers) do
				buf:put(mod)

				if i < #decl.modifiers then buf:put(" ") end
			end

			return tostring(buf)
		elseif decl.type == "function" then
			local buf = buffer.new()
			-- Emit return type without any identifier
			local ret_type = emit(decl.rets, nil, collect_structs)

			-- Debug: check if return type contains the function name
			if ident and ret_type:find(ident) then
				print("ERROR: Return type contains function name!")
				print("  ident:", ident)
				print("  ret_type:", ret_type)
				print("  decl.rets.type:", decl.rets.type)
			end

			buf:put(ret_type)
			-- Only add function name if ident is provided
			--if ident then buf:put(" ", ident) end
			buf:put("(")

			for i, param in ipairs(decl.args) do
				buf:put(emit(param, nil, collect_structs))

				if i < #decl.args then buf:put(", ") end
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
	buf:put("local vk = {}\n\n")
	-- First pass: collect all typedefs and categorize them
	local type_definitions = {}
	local simple_typedefs = {}

	walk_cdeclarations(ast, function(decl, ident, typedef, real_node)
		if typedef then
			-- Mark ALL typedefs so they get replaced with $ in emit
			typedefs[ident] = true
			-- Check if this is a struct, union, or enum type that needs ffi.typeof
			local inner = decl

			while inner.type == "root" or inner.type == "pointer" or inner.type == "array" do
				if inner.of then inner = inner.of else break end
			end

			local is_complex_type = false

			if inner.type == "type" then
				for _, v in ipairs(inner.modifiers) do
					if
						type(v) == "table" and
						(
							v.type == "struct" or
							v.type == "union" or
							v.type == "enum"
						)
					then
						is_complex_type = true
						type_definitions[ident] = {decl = decl, ident = ident}

						break
					end
				end
			end

			-- Store simple typedefs separately
			if not is_complex_type then
				simple_typedefs[ident] = {decl = decl, ident = ident}
			end
		end
	end)

	-- Helper function to collect typedef references in a declaration (in order)
	local function collect_all_typedef_refs(decl)
		local refs = {} -- array to preserve order, including duplicates
		local function walk(node)
			if not node then return end

			if node.type == "type" then
				for _, v in ipairs(node.modifiers or {}) do
					if type(v) == "string" and typedefs[v] then
						-- Add every occurrence, even if we've seen it before
						-- Each $ needs its own parameter
						table.insert(refs, v)
					elseif
						type(v) == "table" and
						(
							v.type == "struct" or
							v.type == "union" or
							v.type == "enum"
						)
					then
						-- Walk struct/union/enum fields
						if v.fields then
							for _, field in ipairs(v.fields) do
								walk(field)
							end
						end
					end
				end
			elseif node.type == "pointer" or node.type == "array" or node.type == "root" then
				walk(node.of)
			elseif node.type == "function" then
				walk(node.rets)

				for _, arg in ipairs(node.args or {}) do
					walk(arg)
				end
			end
		end

		walk(decl)
		return refs
	end

	-- Second pass: emit all typedefs
	-- First emit simple typedefs (they have no dependencies on complex types)
	for ident, info in pairs(simple_typedefs) do
		-- Pass ident as skip_identifier to prevent it from being included in the type
		local type_str = emit(info.decl, nil, false, ident)

		-- Skip typedefs that reference other typedefs (contain $) or are empty
		-- These are just aliases and will be resolved through the original typedef
		if type_str == "" or type_str:find("%$") then

		-- Skip - this is just an alias to another typedef
		else
			-- For function pointer typedefs: "return_type(args) *" -> "return_type (*)(args)"
			-- Check if it's a function pointer (has '(' and ends with ' *')
			if type_str:find("%)%s*%*%s*$") then
				-- Remove the trailing " *"
				type_str = type_str:gsub("%s*%*%s*$", "")
				-- Insert (*) before the opening paren of args (no name in typeof!)
				local args_start = type_str:find("%(")

				if args_start then
					type_str = type_str:sub(1, args_start - 1) .. " (*)" .. type_str:sub(args_start)
				end
			-- For regular types, the type is already correct
			end

			buf:put("vk.", ident, " = ffi.typeof([[", type_str, "]])\n")
		end
	end

	-- Then emit complex types (struct/union/enum) in dependency order
	local emitted = {}

	local function emit_typedef(ident, info)
		if emitted[ident] then return end

		local typedef_refs = collect_all_typedef_refs(info.decl)

		-- First emit all dependencies
		for _, ref in ipairs(typedef_refs) do
			if ref ~= ident and type_definitions[ref] and not emitted[ref] then
				emit_typedef(ref, type_definitions[ref])
			end
		end

		-- Now emit this type
		local type_str = emit(info.decl, ident, true)
		local params = {}

		for _, ref in ipairs(typedef_refs) do
			if ref ~= ident then table.insert(params, ref) end
		end

		buf:put("vk.", ident, " = ffi.typeof([[\n\t", type_str, "\n]]")

		for _, ref in ipairs(params) do
			buf:put(", vk.", ref)
		end

		buf:put(")\n")
		emitted[ident] = true
	end

	for ident, info in pairs(type_definitions) do
		emit_typedef(ident, info)
	end

	-- Helper function to collect typedef references in a declaration
	local function collect_typedef_refs(decl)
		local refs = {}

		local function walk(node)
			if not node then return end

			if node.type == "type" then
				for _, v in ipairs(node.modifiers or {}) do
					if type(v) == "string" and typedefs[v] then refs[v] = true end
				end
			elseif node.type == "pointer" or node.type == "array" or node.type == "root" then
				walk(node.of)
			elseif node.type == "function" then
				walk(node.rets)

				for _, arg in ipairs(node.args or {}) do
					walk(arg)
				end
			end
		end

		walk(decl)
		return refs
	end

	-- Third pass: emit function declarations and variables
	walk_cdeclarations(ast, function(decl, ident, typedef, real_node)
		if typedef then
			-- Skip all typedefs as we already handled them
			-- (both complex type_definitions and simple_typedefs)
			return
		else
			-- Check if this is a function by trying to detect function signature
			-- Emit first to see if it has a function signature
			local func_str_no_ident = emit(decl, nil, false)
			local paren_pos = func_str_no_ident:find("%(")

			-- If there's no opening paren, it's a variable/constant declaration, not a function
			if not paren_pos then
				-- This is a variable/constant declaration like: const VkFlags VK_SOMETHING = value
				-- Check if it has an initialization expression
				if real_node and real_node.default_expression then
					-- Emit as: vk.CONSTANT_NAME = value
					local value = real_node.default_expression:Render()
					buf:put("vk.", ident, " = ", value, "\n")
				end

				-- Skip declarations without initialization
				return
			end

			-- This is a function declaration
			-- Insert the function name before the opening paren
			local func_str = func_str_no_ident:sub(1, paren_pos - 1) .. " " .. ident .. func_str_no_ident:sub(paren_pos)

			-- Debug output
			if func_str:find(ident .. ".*" .. ident) then
				print("WARNING: Duplicate function name detected for:", ident)
				print("Output:", func_str)
			end

			-- Check if function uses parameterized types
			local needs_params = func_str:find("%$")

			if needs_params then
				-- Extract only the struct names actually used in this function
				local typedef_refs = collect_typedef_refs(decl)
				local params = {}

				for param_name in pairs(typedef_refs) do
					if type_definitions[param_name] then
						table.insert(params, param_name)
					end
				end

				buf:put("ffi.cdef([[\n\t", func_str, "\n]]")

				for _, param in ipairs(params) do
					buf:put(", vk.", param)
				end

				buf:put(")\n")
			else
				buf:put("ffi.cdef([[\n\t", func_str, "\n]])\n")
			end
		end
	end)

	-- Add return statement
	buf:put("\nreturn vk\n")
	return tostring(buf)
end

local c_header = preprocess(
	[[
	typedef int VkSamplerYcbcrConversion;
	typedef int VkDescriptorUpdateTemplate;

	#include <vulkan/vulkan.h>
	]],
	{
		working_directory = "/Users/caps/github/ffibuild/vulkan/repo/include",
		system_include_paths = {"/Users/caps/github/ffibuild/vulkan/repo/include"},
		defines = {__LP64__ = true},
		on_include = function(filename, full_path)
			print(string.format("Including: %s", filename))
		end,
	}
)
local res = build_lua(c_header)
local vk = assert(loadstring(res))()
table.print(vk)
