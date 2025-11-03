--[[HOTRELOAD
    run_lua(path)
]]
local Lexer = require("nattlua.definitions.lua.ffi.preprocessor.lexer").New
local Code = require("nattlua.code").New

local function strip_numeric_suffix(value_str)
	-- Strip U, L, F suffixes but keep ULL and LL
	-- Need to be careful with hex numbers like 0xFFU where F is both a hex digit and a suffix
	-- Check for ULL or LL first (keep these)
	if value_str:match("[Uu][Ll][Ll]$") then
		return value_str:gsub("[Uu]([Ll][Ll])$", "%1") -- Remove U from ULL -> LL
	elseif value_str:match("[Ll][Ll]$") then
		return value_str -- Keep LL
	end

	-- For hex numbers, be more careful about what we strip
	if value_str:match("^0[xX]") then
		-- Strip UL, LU, U, L suffixes (but not F since F is a hex digit)
		-- We need to check that F is actually a suffix, not part of the hex number
		-- Strategy: strip from right to left, checking each suffix type
		local result = value_str
		result = result:gsub("[Uu][Ll]$", "") -- UL or ul
		result = result:gsub("[Ll][Uu]$", "") -- LU or lu
		result = result:gsub("[Uu]$", "") -- U or u
		result = result:gsub("[Ll]$", "") -- L or l
		-- For F, only strip if it's clearly a suffix (comes after another hex digit)
		-- This is tricky - 0xFFU has F as hex, 0x1FU has F as hex, 0x12FU has F as hex
		-- So we should NOT strip F from hex numbers
		return result
	else
		-- Decimal or float - strip U, L, or F
		return value_str:gsub("[ULFulf]+$", "")
	end
end

local function convert_c_expr_to_lua(tokens)
	-- Convert C expression tokens to Lua, handling:
	-- - C casts (type)(expr)
	-- - Left shift <<
	-- - Bitwise OR |
	-- - Numeric suffixes
	-- First pass: identify and convert casts and handle numbers
	local i = 1
	local processed = {}

	while i <= #tokens do
		local tk = tokens[i]
		local val = tk:GetValueString()

		-- Handle numbers with C suffixes (decimal, hex, octal, float)
		if
			tk.type == "number" or
			(
				tk.type == "letter" and
				val:match("^0[xX][%da-fA-F]+[ULFulf]*$")
			)
			or
			(
				tk.type == "letter" and
				val:match("^[%d%.]+[ULFulf]*$")
			)
		then
			processed[#processed + 1] = strip_numeric_suffix(val)
			i = i + 1
		-- Check for C cast pattern: (type)(expr)
		elseif
			tk:ValueEquals("(") and
			i + 3 <= #tokens and
			tokens[i + 1].type == "letter" and
			tokens[i + 2]:ValueEquals(")") and
			tokens[i + 3]:ValueEquals("(")
		then
			local type_name = tokens[i + 1]:GetValueString()
			-- Find the matching ) for the expression
			local depth = 1
			local expr_start = i + 4
			local expr_end = nil

			for j = expr_start, #tokens do
				if tokens[j]:ValueEquals("(") then
					depth = depth + 1
				elseif tokens[j]:ValueEquals(")") then
					depth = depth - 1

					if depth == 0 then
						expr_end = j - 1

						break
					end
				end
			end

			-- Extract and recursively process the cast expression
			local expr_tokens = {}

			for j = expr_start, expr_end do
				expr_tokens[#expr_tokens + 1] = tokens[j]
			end

			local inner_expr = convert_c_expr_to_lua(expr_tokens)
			processed[#processed + 1] = string.format("ffi.cast(\"%s\", %s)", type_name, inner_expr)
			i = expr_end + 2
		else
			-- Regular token
			processed[#processed + 1] = val
			i = i + 1
		end
	end

	-- Build the processed string
	local expr = table.concat(processed, " ")
	-- Second pass: handle bitwise NOT operator ~
	expr = expr:gsub("~%s*([%w_]+)", function(operand)
		return string.format("bit.bnot(%s)", operand)
	end)
	expr = expr:gsub("~%s*(%b())", function(operand)
		-- Remove outer parens from operand
		local inner = operand:sub(2, -2)
		return string.format("bit.bnot(%s)", inner)
	end)
	-- Third pass: handle << operator (string-based since it's already processed)
	expr = expr:gsub("(%b())%s*<<%s*([%w_]+)", function(left, right)
		-- Remove outer parens from left operand
		local inner = left:sub(2, -2)
		return string.format("bit.lshift(%s, %s)", inner, right)
	end)
	-- Remove outermost wrapper parens if the whole expression is wrapped
	expr = expr:gsub("^%s+", ""):gsub("%s+$", "")

	while expr:match("^%((.+)%)$") do
		local inner = expr:match("^%((.+)%)$")
		-- Check if entire content is balanced
		local depth = 0
		local all_wrapped = true

		for i = 1, #inner do
			local c = inner:sub(i, i)

			if c == "(" then
				depth = depth + 1
			elseif c == ")" then
				depth = depth - 1

				if depth < 0 then
					all_wrapped = false

					break
				end
			end
		end

		if all_wrapped and depth == 0 then expr = inner else break end
	end

	-- Third pass: handle | operator at the top level
	-- We need to split by | while respecting parentheses
	if expr:find("|", 1, true) then
		local terms = {}
		local current = ""
		local depth = 0

		for i = 1, #expr do
			local char = expr:sub(i, i)

			if char == "(" then
				depth = depth + 1
				current = current .. char
			elseif char == ")" then
				depth = depth - 1
				current = current .. char
			elseif char == "|" and depth == 0 then
				-- Found top-level OR
				local term = current:match("^%s*(.-)%s*$")

				-- Strip outer parens if present
				while term:match("^%(.+%)$") do
					local inner = term:match("^%((.+)%)$")
					-- Check if inner is fully balanced
					local d = 0
					local balanced = true

					for j = 1, #inner do
						if inner:sub(j, j) == "(" then
							d = d + 1
						elseif inner:sub(j, j) == ")" then
							d = d - 1

							if d < 0 then
								balanced = false

								break
							end
						end
					end

					if balanced and d == 0 then term = inner else break end
				end

				terms[#terms + 1] = term
				current = ""
			else
				current = current .. char
			end
		end

		-- Add the last term
		if current ~= "" then
			local term = current:match("^%s*(.-)%s*$")

			-- Strip outer parens if present
			while term:match("^%(.+%)$") do
				local inner = term:match("^%((.+)%)$")
				-- Check if inner is fully balanced
				local d = 0
				local balanced = true

				for j = 1, #inner do
					if inner:sub(j, j) == "(" then
						d = d + 1
					elseif inner:sub(j, j) == ")" then
						d = d - 1

						if d < 0 then
							balanced = false

							break
						end
					end
				end

				if balanced and d == 0 then term = inner else break end
			end

			terms[#terms + 1] = term
		end

		if #terms > 1 then return "bit.bor(" .. table.concat(terms, ", ") .. ")" end
	end

	return expr
end

local function parse_define(define_str)
	-- Split on the first '=' to get key and value
	local key, value = define_str:match("^(.-)%s*=%s*(.*)$")

	if not key or not value then return nil end

	key = key:match("^%s*(.-)%s*$")
	value = value:match("^%s*(.-)%s*$")
	-- Check if it's a function-like macro
	local func_name, params_str = key:match("^([%w_]+)%s*%((.-)%)$")

	if func_name then
		-- Parse parameters
		local param_list = {}

		if params_str and params_str ~= "" then
			for param in params_str:gmatch("[^,]+") do
				param_list[#param_list + 1] = param:match("^%s*(.-)%s*$")
			end
		end

		-- Tokenize the body
		local code_obj = Code(value, "define_body")
		local tokens = Lexer(code_obj):GetTokens()

		-- Remove end_of_file token
		if tokens[#tokens] and tokens[#tokens].type == "end_of_file" then
			table.remove(tokens)
		end

		-- Convert to Lua
		local lua_expr = convert_c_expr_to_lua(tokens)
		local func_str = string.format("function(%s) return %s end", table.concat(param_list, ", "), lua_expr)
		return {key = func_name, val = func_str}
	else
		-- Value macro
		-- Check if it's a string literal
		if value:match("^\".*\"$") then return {key = key, val = value} end

		-- Tokenize the value
		local code_obj = Code(value, "define_value")
		local tokens = Lexer(code_obj):GetTokens()

		-- Remove end_of_file token
		if tokens[#tokens] and tokens[#tokens].type == "end_of_file" then
			table.remove(tokens)
		end

		-- Convert to Lua
		local lua_value = convert_c_expr_to_lua(tokens)
		local ok, err = loadstring("local ffi = require('ffi') local x = " .. lua_value)

		if not ok then
			return {key = key, val = "nil -- " .. value .. " -- Failed to parse: " .. err}
		end

		local ok, err = pcall(ok)

		if not ok then
			return {key = key, val = "nil -- " .. value .. " -- Failed to evaluate: " .. err}
		end

		return {key = key, val = lua_value}
	end
end

return parse_define
