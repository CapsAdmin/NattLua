--[[HOTRELOAD
	run_lua("test/tests/nattlua/c_declarations/preprocessor.lua")
]]
local META = require("nattlua.parser.base")()
local buffer = require("string.buffer")

-- Deep copy tokens to prevent shared state corruption
-- This is CRITICAL because:
-- 1. Macro definitions store tokens that are reused on each expansion
-- 2. During expansion, we modify tokens (whitespace, expanded_from markers)
-- 3. Without copying, modifications would affect the stored definition
-- 4. This would break subsequent expansions and cause test failures
local function copy_tokens(tokens)
	local new_tokens = {}

	for i, token in ipairs(tokens) do
		new_tokens[i] = token:Copy()
	end

	return new_tokens
end

local old = META.New

function META.New(...)
	local obj = old(...)
	obj.defines = {}
	obj.define_stack = {}
	obj.expansion_stack = {}
	obj.conditional_stack = {} -- Track nested #if/#ifdef/#ifndef states
	obj.position_stack = {} -- Track positions for directive token removal
	return obj
end

-- Helper functions for saving/restoring positions when removing directive tokens
function META:PushPosition()
	table.insert(self.position_stack, self:GetPosition())
end

function META:PopPosition()
	local start_pos = table.remove(self.position_stack)

	if not start_pos then error("Position stack underflow") end

	return start_pos
end

-- Remove directive tokens and reset position
function META:RemoveDirectiveTokens()
	local start_pos = self:PopPosition()
	local end_pos = self:GetPosition()

	for i = end_pos - 1, start_pos, -1 do
		self:RemoveToken(i)
	end

	self:SetPosition(start_pos)
end

function META:IsWhitespace(str, offset)
	local tk = self:GetTokenOffset(offset or 0)

	if tk.type ~= "end_of_file" and tk:HasWhitespace() then
		for _, whitespace in ipairs(tk:GetWhitespace()) do
			if whitespace:GetValueString():find(str, nil, true) then return true end
		end
	end

	return false
end

function META:IsMultiWhitespace(str, offset)
	local tk = self:GetTokenOffset(offset or 0)

	if tk.type ~= "end_of_file" and tk:HasWhitespace() then
		for _, whitespace in ipairs(tk:GetWhitespace()) do
			local count = 0

			for i = 1, #whitespace:GetValueString() do
				if whitespace:GetValueString():sub(i, i) == str then count = count + 1 end
			end

			if count and count > 1 then return true end
		end
	end

	return false
end

do -- for normal define, can be overridden
	function META:Define(identifier, args, tokens)
		-- Store a copy because the original tokens may be modified elsewhere
		self.defines[identifier] = {args = args, tokens = copy_tokens(tokens), identifier = identifier}
	end

	function META:Undefine(identifier)
		self.defines[identifier] = nil
	end
end

do -- for parameters (scoped macro definitions during expansion)
	function META:PushDefine(identifier, args, tokens)
		self.define_stack[identifier] = self.define_stack[identifier] or {}
		table.insert(
			self.define_stack[identifier],
			1,
			-- Store copy for same reason as Define()
			{args = args, tokens = copy_tokens(tokens), identifier = identifier}
		)
	end

	function META:PushUndefine(identifier)
		self.define_stack[identifier] = self.define_stack[identifier] or {}
		table.remove(self.define_stack[identifier], 1)

		if not self.define_stack[identifier][1] then
			self.define_stack[identifier] = nil
		end
	end
end

function META:GetDefinition(identifier, offset)
	if not identifier then
		local tk = self:GetTokenOffset(offset)

		if tk.type == "end_of_file" or tk.type ~= "letter" then return false end

		identifier = tk:GetValueString()
	end

	if self.define_stack[identifier] then
		return self.define_stack[identifier][1]
	end

	return self.defines[identifier]
end

function META:CaptureTokens()
	local tks = {}

	for _ = self:GetPosition(), self:GetLength() do
		if
			self:IsWhitespace("\n") and
			not self:IsTokenValueOffset("\\", -1)
			or
			self:IsMultiWhitespace("\n")
		then
			break
		end

		local tk = self:ConsumeToken()

		if not tk then break end

		if tk then if not tk:ValueEquals("\\") then table.insert(tks, tk) end end
	end

	return tks
end

function META:CaptureArgumentDefinition()
	self:ExpectToken("(")
	local args = {}

	for i = 1, self:GetLength() do
		if self:IsToken(")") then break end

		-- Accept either letter (regular parameter) or symbol "..." (variadic)
		local node

		if self:IsToken("...") then
			node = self:ExpectToken("...")
		else
			node = self:ExpectTokenType("letter")
		end

		if not node then break end

		args[i] = node

		if not self:IsToken(",") then break end

		self:ExpectToken(",")
	end

	self:ExpectToken(")")
	return args
end

local function normalize_argument_whitespace(self, args)
	for i, tokens in ipairs(args) do
		-- Copy because we're about to modify whitespace properties
		tokens = copy_tokens(tokens)
		args[i] = tokens

		for _, tk in ipairs(tokens) do
			if tk:HasWhitespace() then
				tk.whitespace = {self:NewToken("space", " ")}
			end

			if tk.parent and tk.parent:HasWhitespace() then
				tk.parent.whitespace = {self:NewToken("space", " ")}
			end
		end

		-- Remove whitespace from first token in first argument
		if i == 1 and tokens[1] then
			tokens[1].whitespace = nil

			if tokens[1].parent then tokens[1].parent.whitespace = nil end
		end
	end

	return args
end

-- Helper to update parenthesis depth based on token value
local function update_paren_depth(token, depth)
	if token:ValueEquals("(") then
		return depth + 1
	elseif token:ValueEquals(")") then
		return depth - 1
	end

	return depth
end

-- Helper to remove a range of tokens (inclusive, in reverse order)
local function remove_token_range(self, start_pos, end_pos)
	for i = end_pos, start_pos, -1 do
		self:RemoveToken(i)
	end
end

-- Helper to check if __VA_ARGS__ is non-empty
local function is_va_args_non_empty(va)
	return va and #va.tokens > 0 and not va.tokens[1]:ValueEquals("")
end

-- Helper to check if token was already expanded from a macro (prevents infinite recursion)
local function is_already_expanded(token, macro_identifier)
	return token.expanded_from and token.expanded_from[macro_identifier]
end

local function capture_single_argument(self, is_va_opt)
	local tokens = {}

	if not is_va_opt and self:IsToken(",") then
		-- Empty argument - leave tokens table empty
		return tokens
	end

	local paren_depth = 0

	for _ = self:GetPosition(), self:GetLength() do
		if paren_depth == 0 then
			if self:IsToken(",") or self:IsToken(")") then break end
		end

		local pos = self:GetPosition()
		local parent = self:GetToken()

		if parent.type == "end_of_file" then break end

		-- Don't call Parse() for __VA_OPT__ arguments to avoid recursive expansion
		if not is_va_opt then self:Parse() end

		self:SetPosition(pos)
		local tk = self:ConsumeToken()
		paren_depth = update_paren_depth(tk, paren_depth)
		tk.parent = parent
		table.insert(tokens, tk)
	end

	return tokens
end

function META:CaptureArgs(def)
	local is_va_opt = def and def.identifier == "__VA_OPT__"
	self:ExpectToken("(")
	local args = {}

	for _ = self:GetPosition(), self:GetLength() do
		if self:IsToken(")") then
			-- Handle empty arguments at end
			if not is_va_opt and self:IsTokenOffset(",", -1) then
				table.insert(args, {})
			elseif not is_va_opt and #args == 0 and def and def.args and #def.args > 0 then
				table.insert(args, {})
			end

			break
		end

		local tokens = capture_single_argument(self, is_va_opt)
		table.insert(args, tokens)

		if self:IsToken(",", -1) then self:ExpectToken(",") end
	end

	self:ExpectToken(")")
	return normalize_argument_whitespace(self, args)
end

function META:PrintState(tokens, pos)
	tokens = tokens or self.tokens
	pos = pos or self:GetPosition()

	if not tokens then return "" end

	local str = ""
	local str_point = ""

	for i, tk in ipairs(tokens) do
		str = str .. " " .. tk:GetValueString()
		str_point = str_point .. " " .. (i == pos and "^" or (" "):rep(#tk:GetValueString()))
	end

	str = str .. "\n" .. str_point
	print("\n" .. str)
end

function META:ReadDefine()
	if not (self:IsToken("#") and self:IsTokenValueOffset("define", 1)) then
		return false
	end

	self:PushPosition()
	local hashtag = self:ExpectToken("#")
	local directive = self:ExpectTokenValue("define")
	local identifier = self:ExpectTokenType("letter")
	local args = self:IsToken("(") and self:CaptureArgumentDefinition() or nil
	self:Define(identifier:GetValueString(), args, self:CaptureTokens())
	self:RemoveDirectiveTokens()
	return true
end

function META:ReadUndefine()
	if not (self:IsToken("#") and self:IsTokenValueOffset("undef", 1)) then
		return false
	end

	self:PushPosition()
	local hashtag = self:ExpectToken("#")
	local directive = self:ExpectTokenValue("undef")
	local identifier = self:ExpectTokenType("letter")
	self:Undefine(identifier:GetValueString())
	self:RemoveDirectiveTokens()
	return true
end

do -- conditional compilation (#if, #ifdef, #ifndef, #else, #elif, #endif)
	-- Implementation of C preprocessor conditional directives
	--
	-- Features:
	--   - #ifdef, #ifndef, #if, #elif, #else, #endif
	--   - Nested conditionals with proper depth tracking
	--   - Token removal for false branches
	--
	-- Known limitations:
	--   - Expression evaluation with macro expansion and > operator has edge cases
	--   - Multi-character operators (>=, ==, etc.) with complex expressions may fail
	--   - See TODO comments in tests for specific failing cases
	-- Helper to evaluate a simple expression (for #if and #elif)
	-- This is a simplified evaluator that handles:
	-- - defined(MACRO) and defined MACRO operators
	-- - Integer literals
	-- - Basic arithmetic and comparison operators
	-- - Logical operators (&&, ||, !)
	local function evaluate_condition(self, tokens)
		-- Simple recursive descent parser for constant expressions
		local pos = 1

		local function peek()
			return tokens[pos]
		end

		local function advance()
			pos = pos + 1
			return tokens[pos - 1]
		end

		local function parse_primary()
			local tk = peek()

			if not tk then return 0 end

			-- Handle defined(X) or defined X
			if tk:ValueEquals("defined") then
				advance() -- consume 'defined'
				local has_paren = peek() and peek():ValueEquals("(")

				if has_paren then advance() end -- consume '('
				local name_tk = advance()

				if not name_tk then return 0 end

				local is_defined = self:GetDefinition(name_tk:GetValueString()) ~= nil

				if has_paren then
					if peek() and peek():ValueEquals(")") then
						advance() -- consume ')'
					end
				end

				return is_defined and 1 or 0
			end

			-- Handle numbers
			if tk.type == "number" then
				advance()
				return tonumber(tk:GetValueString()) or 0
			end

			-- Handle parentheses
			if tk:ValueEquals("(") then
				advance() -- consume '('
				local val = parse_logical_or()

				if peek() and peek():ValueEquals(")") then advance() -- consume ')'
				end

				return val
			end

			-- Handle unary operators
			if tk:ValueEquals("!") then
				advance()
				local val = parse_primary()
				return val == 0 and 1 or 0
			end

			if tk:ValueEquals("-") then
				advance()
				return -parse_primary()
			end

			if tk:ValueEquals("+") then
				advance()
				return parse_primary()
			end

			-- Undefined identifiers evaluate to 0
			if tk.type == "letter" then
				advance()
				local def = self:GetDefinition(tk:GetValueString())

				if def and def.tokens[1] and def.tokens[1].type == "number" then
					return tonumber(def.tokens[1]:GetValueString()) or 0
				end

				return 0
			end

			advance() -- skip unknown token
			return 0
		end

		local function parse_multiplicative()
			local left = parse_primary()

			while peek() do
				local op = peek()

				if op:ValueEquals("*") then
					advance()
					left = left * parse_primary()
				elseif op:ValueEquals("/") then
					advance()
					local right = parse_primary()
					left = right ~= 0 and (left / right) or 0
				elseif op:ValueEquals("%") then
					advance()
					local right = parse_primary()
					left = right ~= 0 and (left % right) or 0
				else
					break
				end
			end

			return left
		end

		local function parse_additive()
			local left = parse_multiplicative()

			while peek() do
				local op = peek()

				if op:ValueEquals("+") then
					advance()
					left = left + parse_multiplicative()
				elseif op:ValueEquals("-") then
					advance()
					left = left - parse_multiplicative()
				else
					break
				end
			end

			return left
		end

		local function parse_relational()
			local left = parse_additive()

			while peek() do
				local op = peek()
				local next_op = tokens[pos + 1]

				if op:ValueEquals("<") and next_op and next_op:ValueEquals("=") then
					advance() -- consume <
					advance() -- consume =
					left = left <= parse_additive() and 1 or 0
				elseif op:ValueEquals(">") and next_op and next_op:ValueEquals("=") then
					advance() -- consume >
					advance() -- consume =
					left = left >= parse_additive() and 1 or 0
				elseif op:ValueEquals("<") then
					advance()
					left = left < parse_additive() and 1 or 0
				elseif op:ValueEquals(">") then
					advance()
					left = left > parse_additive() and 1 or 0
				else
					break
				end
			end

			return left
		end

		local function parse_equality()
			local left = parse_relational()

			while peek() do
				local op = peek()
				local next_op = tokens[pos + 1]

				if op:ValueEquals("=") and next_op and next_op:ValueEquals("=") then
					advance() -- consume =
					advance() -- consume =
					left = left == parse_relational() and 1 or 0
				elseif op:ValueEquals("!") and next_op and next_op:ValueEquals("=") then
					advance() -- consume !
					advance() -- consume =
					left = left ~= parse_relational() and 1 or 0
				else
					break
				end
			end

			return left
		end

		local function parse_logical_and()
			local left = parse_equality()

			while peek() do
				local op = peek()
				local next_op = tokens[pos + 1]

				if op:ValueEquals("&") and next_op and next_op:ValueEquals("&") then
					advance() -- consume &
					advance() -- consume &
					local right = parse_equality()
					left = (left ~= 0 and right ~= 0) and 1 or 0
				else
					break
				end
			end

			return left
		end

		function parse_logical_or()
			local left = parse_logical_and()

			while peek() do
				local op = peek()
				local next_op = tokens[pos + 1]

				if op:ValueEquals("|") and next_op and next_op:ValueEquals("|") then
					advance() -- consume |
					advance() -- consume |
					local right = parse_logical_and()
					left = (left ~= 0 or right ~= 0) and 1 or 0
				else
					break
				end
			end

			return left
		end

		local result = parse_logical_or()
		return result ~= 0
	end

	-- Helper to skip tokens until we find a matching directive
	-- This removes all tokens between the current position and the target directive
	local function skip_until_directive(self, directives)
		local depth = 1
		local start_pos = self:GetPosition()

		while depth > 0 do
			local tk = self:GetToken()

			if tk.type == "end_of_file" then
				error("Unterminated conditional directive")
			end

			if tk:ValueEquals("#") then
				local next_tk = self:GetTokenOffset(1)

				if next_tk.type == "letter" then
					local directive = next_tk:GetValueString()

					-- Track nesting
					if directive == "if" or directive == "ifdef" or directive == "ifndef" then
						depth = depth + 1
					elseif directive == "endif" then
						depth = depth - 1

						if depth == 0 then
							-- Remove all tokens from start to here (not including the # and endif)
							local end_pos = self:GetPosition()

							for i = end_pos - 1, start_pos, -1 do
								self:RemoveToken(i)
							end

							self:SetPosition(start_pos)
							-- Now consume and remove the #endif directive
							self:ExpectToken("#")
							self:ExpectTokenType("letter")
							local directive_end = self:GetPosition()

							for i = directive_end - 1, start_pos, -1 do
								self:RemoveToken(i)
							end

							self:SetPosition(start_pos)
							return "endif"
						end
					elseif depth == 1 then
						-- Only respond to else/elif at our nesting level
						if directive == "else" then
							-- Remove all tokens from start to here (not including the # and else)
							local end_pos = self:GetPosition()

							for i = end_pos - 1, start_pos, -1 do
								self:RemoveToken(i)
							end

							self:SetPosition(start_pos)
							-- Consume and remove the #else directive
							self:ExpectToken("#")
							self:ExpectTokenType("letter")
							local directive_end = self:GetPosition()

							for i = directive_end - 1, start_pos, -1 do
								self:RemoveToken(i)
							end

							self:SetPosition(start_pos)
							return "else"
						elseif directive == "elif" then
							-- Remove all tokens from start to here (not including the # and elif)
							local end_pos = self:GetPosition()

							for i = end_pos - 1, start_pos, -1 do
								self:RemoveToken(i)
							end

							self:SetPosition(start_pos)
							-- Don't consume elif - let ReadElif handle it
							return "elif"
						end
					end
				end
			end

			self:Advance(1)
		end

		return "endif"
	end

	function META:ReadIfdef()
		if not (self:IsToken("#") and self:IsTokenValueOffset("ifdef", 1)) then
			return false
		end

		self:PushPosition()
		self:ExpectToken("#")
		self:ExpectTokenValue("ifdef")
		local identifier = self:ExpectTokenType("letter")
		local is_defined = self:GetDefinition(identifier:GetValueString()) ~= nil
		table.insert(self.conditional_stack, {active = is_defined, had_true = is_defined})
		self:RemoveDirectiveTokens()

		if not is_defined then
			skip_until_directive(self, {"else", "elif", "endif"})
		end

		return true
	end

	function META:ReadIfndef()
		if not (self:IsToken("#") and self:IsTokenValueOffset("ifndef", 1)) then
			return false
		end

		self:PushPosition()
		self:ExpectToken("#")
		self:ExpectTokenValue("ifndef")
		local identifier = self:ExpectTokenType("letter")
		local is_defined = self:GetDefinition(identifier:GetValueString()) ~= nil
		local is_active = not is_defined
		table.insert(self.conditional_stack, {active = is_active, had_true = is_active})
		self:RemoveDirectiveTokens()

		if is_defined then skip_until_directive(self, {"else", "elif", "endif"}) end

		return true
	end

	function META:ReadIf()
		if not (self:IsToken("#") and self:IsTokenOffset("if", 1)) then
			return false
		end

		self:PushPosition()
		self:ExpectToken("#")
		self:ExpectToken("if")
		local tokens = self:CaptureTokens()
		local condition = evaluate_condition(self, tokens)
		table.insert(self.conditional_stack, {active = condition, had_true = condition})
		self:RemoveDirectiveTokens()

		if not condition then
			skip_until_directive(self, {"else", "elif", "endif"})
		end

		return true
	end

	function META:ReadElif()
		if not (self:IsToken("#") and self:IsTokenValueOffset("elif", 1)) then
			return false
		end

		if #self.conditional_stack == 0 then error("#elif without matching #if") end

		self:PushPosition()
		self:ExpectToken("#")
		self:ExpectTokenValue("elif")
		local tokens = self:CaptureTokens()
		local state = self.conditional_stack[#self.conditional_stack]
		self:RemoveDirectiveTokens()

		-- If we already had a true branch, skip this elif
		if state.had_true then
			skip_until_directive(self, {"else", "elif", "endif"})
		else
			-- Evaluate the elif condition
			local condition = evaluate_condition(self, tokens)
			state.active = condition
			state.had_true = condition

			if not condition then
				skip_until_directive(self, {"else", "elif", "endif"})
			end
		end

		return true
	end

	function META:ReadElse()
		if not (self:IsToken("#") and self:IsTokenOffset("else", 1)) then
			return false
		end

		if #self.conditional_stack == 0 then
			local tk = self:GetToken()
			error(
				string.format(
					"#else without matching #if at %s:%d",
					tk.code_ptr and tk.code_ptr.path or "unknown",
					tk.line or 0
				)
			)
		end

		self:PushPosition()
		self:ExpectToken("#")
		self:ExpectToken("else")
		local state = self.conditional_stack[#self.conditional_stack]
		self:RemoveDirectiveTokens()

		-- If we already had a true branch, skip the else
		if state.had_true then
			skip_until_directive(self, {"endif"})
		else
			-- This else branch should be active
			state.active = true
			state.had_true = true
		end

		return true
	end

	function META:ReadEndif()
		if not (self:IsToken("#") and self:IsTokenValueOffset("endif", 1)) then
			return false
		end

		if #self.conditional_stack == 0 then
			error("#endif without matching #if")
		end

		self:PushPosition()
		self:ExpectToken("#")
		self:ExpectTokenValue("endif")
		-- Remove the last conditional state, but be careful with nested else
		table.remove(self.conditional_stack)
		self:RemoveDirectiveTokens()
		return true
	end
end

do -- #include directive
	local fs = require("nattlua.other.fs")

	local function resolve_include_path(self, filename, is_system_include)
		local opts = self.preprocess_options

		if not opts then return nil, "No preprocessor options available" end

		-- Prevent infinite recursion
		if self.include_depth >= opts.max_include_depth then
			return nil, "Maximum include depth exceeded"
		end

		-- Note: We don't check included_files here anymore
		-- Include guards (#ifndef) inside the header files themselves
		-- will prevent duplicate content, which is the proper C way
		local search_paths = {}

		if is_system_include then
			-- System includes: search system paths first
			for _, path in ipairs(opts.system_include_paths) do
				table.insert(search_paths, path)
			end

			for _, path in ipairs(opts.include_paths) do
				table.insert(search_paths, path)
			end
		else
			-- Local includes: search working directory first
			table.insert(search_paths, opts.working_directory)

			for _, path in ipairs(opts.include_paths) do
				table.insert(search_paths, path)
			end

			for _, path in ipairs(opts.system_include_paths) do
				table.insert(search_paths, path)
			end
		end

		-- Try to find the file
		for _, base_path in ipairs(search_paths) do
			local full_path = base_path .. "/" .. filename
			local content, err = fs.read(full_path)

			if content then return content, full_path end
		end

		-- Try absolute path
		if filename:sub(1, 1) == "/" then
			local content, err = fs.read(filename)

			if content then return content, filename end
		end

		return nil, "Include file not found: " .. filename
	end

	function META:ReadInclude()
		if not (self:IsToken("#") and self:IsTokenValueOffset("include", 1)) then
			return false
		end

		-- Remember the starting position to remove the #include directive tokens
		local start_pos = self:GetPosition()
		local hashtag = self:ExpectToken("#")
		local directive = self:ExpectTokenValue("include")
		-- Parse the filename
		local filename
		local is_system_include = false

		-- Check if we have a proper string token (luajit lexer)
		-- IsToken checks sub_type, so we need to check token type instead
		if self:IsTokenType("string") then
			-- #include "file.h" (as a single string token)
			local str_token = self:ExpectTokenType("string")
			local str_val = str_token:GetValueString()
			-- Remove surrounding quotes
			filename = str_val:sub(2, -2)
			is_system_include = false
		elseif self:IsToken("\"") then
			-- #include "file.h" (tokenized as separate symbols)
			self:ExpectToken("\"")
			local parts = {}

			while not self:IsToken("\"") do
				local tk = self:GetToken()

				if tk.type == "end_of_file" then
					error("Unterminated #include directive")
				end

				table.insert(parts, tk:GetValueString())
				self:Advance(1)
			end

			self:ExpectToken("\"")
			filename = table.concat(parts)
			is_system_include = false
		elseif self:IsToken("<") then
			-- #include <file.h>
			self:ExpectToken("<")
			local parts = {}

			while not self:IsToken(">") do
				local tk = self:GetToken()

				if tk.type == "end_of_file" then
					error("Unterminated #include directive")
				end

				table.insert(parts, tk:GetValueString())
				self:Advance(1)
			end

			self:ExpectToken(">")
			filename = table.concat(parts)
			is_system_include = true
		else
			error("Invalid #include directive: expected string or <filename>")
		end

		-- Resolve and read the include file
		local content, full_path = resolve_include_path(self, filename, is_system_include)

		if not content then
			-- For now, just skip the include if file not found
			-- In production, you might want to error or warn
			print("Warning: " .. (full_path or filename))
			return true
		end

		-- Callback for tracking includes
		if self.preprocess_options.on_include then
			self.preprocess_options.on_include(filename, full_path)
		end

		-- Preprocess the included file recursively
		local Code = require("nattlua.code").New
		local Lexer = require("nattlua.lexer.lexer").New

		local function lex(code_str)
			local lexer = Lexer(code_str)
			lexer.ReadShebang = function()
				return false
			end
			return lexer:GetTokens()
		end

		local code_obj = Code(content, full_path)
		local tokens = lex(code_obj)
		local include_parser = META.New(tokens, code_obj)
		-- Inherit context from parent parser
		include_parser.defines = self.defines
		-- Create a copy of options with updated working directory
		local include_opts = {}

		for k, v in pairs(self.preprocess_options) do
			include_opts[k] = v
		end

		-- Set working directory to the directory of the included file
		-- so relative includes from that file work correctly
		include_opts.working_directory = full_path:match("(.*/)") or self.preprocess_options.working_directory
		include_parser.preprocess_options = include_opts
		include_parser.include_depth = self.include_depth + 1
		-- Process the included file
		include_parser:Parse()
		-- Get the processed tokens
		local processed_tokens = include_parser.tokens

		-- Remove EOF token from included tokens
		if
			processed_tokens[#processed_tokens] and
			processed_tokens[#processed_tokens].type == "end_of_file"
		then
			table.remove(processed_tokens)
		end

		-- Remove the #include directive tokens and insert the included content
		local end_pos = self:GetPosition()

		-- Remove all tokens from the #include directive (from start_pos to end_pos - 1)
		for i = end_pos - 1, start_pos, -1 do
			self:RemoveToken(i)
		end

		-- Set position back to where the #include was
		self:SetPosition(start_pos)
		-- Insert the processed tokens from the included file
		self:AddTokens(processed_tokens)
		-- Update defines from included file (they persist)
		self.defines = include_parser.defines
		return true
	end
end

-- Helper to transfer whitespace from original token to replacement tokens
local function transfer_token_whitespace(original_token, tokens, strip_newlines)
	if not tokens[1] then return end

	if original_token:HasWhitespace() then
		tokens[1].whitespace = original_token:GetWhitespace()
		tokens[1].whitespace_start = original_token.whitespace_start

		-- Optionally remove newlines from whitespace (for function-like macros)
		if strip_newlines and tokens[1]:HasWhitespace() then
			for _, v in ipairs(tokens[1]:GetWhitespace()) do
				local str = v:GetValueString():gsub("\n", "")
				v:ReplaceValue(str)
			end
		end
	else
		tokens[1].whitespace = nil
		tokens[1].whitespace_start = nil
	end
end

-- Helper to mark tokens as expanded from a macro
local function mark_tokens_expanded(tokens, start_pos, end_pos, def_identifier, original_token)
	for i = start_pos, end_pos - 1 do
		local token = tokens[i]

		if token then
			token.expanded_from = token.expanded_from or {}
			token.expanded_from[def_identifier] = true

			-- Inherit expanded_from from the original token
			if original_token.expanded_from then
				for macro_name, _ in pairs(original_token.expanded_from) do
					token.expanded_from[macro_name] = true
				end
			end
		end
	end
end

-- Helper to validate argument count
local function validate_arg_count(def, args)
	local has_var_arg = def.args[1] and def.args[#def.args]:ValueEquals("...")

	if has_var_arg then
		if #args < #def.args - 1 then error("Argument count mismatch") end
	else
		assert(#args == #def.args, "Argument count mismatch")
	end
end

-- Helper to define parameters as macros
local function define_parameters(self, def, args)
	for i, param in ipairs(def.args) do
		if param:ValueEquals("...") then
			local remaining = {}

			for j = i, #args do
				for _, token in ipairs(args[j] or {}) do
					if j ~= i then
						table.insert(remaining, self:NewToken("symbol", ","))
					end

					table.insert(remaining, token)
				end
			end

			if #remaining == 0 then remaining = {self:NewToken("symbol", "")} end

			self:PushDefine("__VA_ARGS__", nil, remaining)

			break
		else
			self:PushDefine(param:GetValueString(), nil, args[i] or {})
		end
	end
end

-- Helper to undefine parameters
local function undefine_parameters(self, def)
	for _, param in ipairs(def.args) do
		if param:ValueEquals("...") then
			self:PushUndefine("__VA_ARGS__")

			break
		else
			self:PushUndefine(param:GetValueString())
		end
	end
end

-- Extract __VA_OPT__ handling to reduce duplication
function META:HandleVAOPT()
	local start = self:GetPosition()
	local va_opt_token = self:GetToken()
	self:ExpectTokenType("letter")
	local va = self:GetDefinition("__VA_ARGS__")
	self:ExpectToken("(")
	local content_tokens = {}
	local paren_depth = 0
	local consumed_closing_paren = false

	-- Capture content inside __VA_OPT__(content)
	while true do
		if paren_depth == 0 and self:IsToken(")") then break end

		local tk = self:ConsumeToken()

		if tk.type == "end_of_file" then break end

		local new_depth = update_paren_depth(tk, paren_depth)

		-- Only add the ) if it's not the final closing paren
		if tk:ValueEquals(")") and new_depth < 0 then
			consumed_closing_paren = true

			break
		end

		paren_depth = new_depth
		table.insert(content_tokens, tk)
	end

	if not consumed_closing_paren then self:ExpectToken(")") end

	local stop = self:GetPosition()
	-- Remove __VA_OPT__(content) from token stream
	remove_token_range(self, start, stop - 1)
	self:SetPosition(start)

	-- Only add content if __VA_ARGS__ is non-empty
	if is_va_args_non_empty(va) then
		-- Copy before modifying whitespace
		content_tokens = copy_tokens(content_tokens)

		-- Transfer whitespace from __VA_OPT__ token to the first content token
		if #content_tokens > 0 and va_opt_token:HasWhitespace() then
			content_tokens[1].whitespace = va_opt_token:GetWhitespace()
			content_tokens[1].whitespace_start = va_opt_token.whitespace_start
		end

		self:AddTokens(content_tokens)
	end

	return true
end

function META:ExpandMacroCall()
	local def = self:GetDefinition(nil, 0)

	if not (def and self:IsTokenOffset("(", 1)) then return false end

	if not def.args then return false end -- Only expand function-like macros
	local current_tk = self:GetToken()

	-- Prevent infinite recursion
	if is_already_expanded(current_tk, def.identifier) then return false end

	-- Special handling for __VA_OPT__
	if def.identifier == "__VA_OPT__" and self:IsTokenOffset("(", 1) then
		return self:HandleVAOPT()
	end

	if current_tk.type == "end_of_file" then return false end

	local tk = current_tk:Copy()
	-- Must copy the macro body tokens before modification
	local tokens = copy_tokens(def.tokens)
	transfer_token_whitespace(tk, tokens, true) -- Strip newlines for function-like macros
	-- Replace macro call with macro body
	local start = self:GetPosition()
	self:ExpectTokenType("letter")
	local args = self:CaptureArgs(def)
	local stop = self:GetPosition()
	remove_token_range(self, start, stop - 1)
	self:SetPosition(start)
	self:AddTokens(tokens)
	-- Validate and bind arguments
	validate_arg_count(def, args)
	define_parameters(self, def, args)
	-- Expand the macro body with parameters substituted
	self:Parse()
	-- Mark expanded tokens to prevent re-expansion
	mark_tokens_expanded(self.tokens, start, self:GetPosition(), def.identifier, tk)
	-- Clean up parameter definitions
	undefine_parameters(self, def)
	return true
end

-- Helper to get token from definition or create empty token
local function get_token_from_definition(self, def, fallback_token)
	if not def then return fallback_token end

	if def.tokens[1] then
		return def.tokens[1]
	elseif #def.tokens == 0 then
		-- Empty parameter - treat as empty string
		return self:NewToken("symbol", "")
	end

	return fallback_token
end

function META:ExpandMacroConcatenation()
	if not (self:IsTokenOffset("#", 1) and self:IsTokenOffset("#", 2)) then
		return false
	end

	local tk_left = self:GetToken()

	if tk_left.type == "end_of_file" then return false end

	local pos = self:GetPosition()
	-- Expand left operand if it's a parameter/macro
	local def_left = self:GetDefinition(nil, 0)
	tk_left = get_token_from_definition(self, def_left, tk_left)
	self:Advance(3)
	-- Expand right operand if it's a parameter/macro
	local tk_right = self:GetToken()

	if tk_right.type == "end_of_file" then return false end

	local def_right = self:GetDefinition(nil, 0)
	tk_right = get_token_from_definition(self, def_right, tk_right)
	self:SetPosition(pos)
	self:AddTokens(
		{
			self:NewToken("letter", tk_left:GetValueString() .. tk_right:GetValueString()),
		}
	)

	-- Don't advance - stay at the concatenated token so we can check for more ## operators
	-- self:Advance(1)
	for i = 1, 4 do
		self:RemoveToken(self:GetPosition() + 1) -- Remove tokens after the concatenated one
	end

	return true
end

function META:ExpandMacroString()
	if not self:IsToken("#") then return false end

	local def = self:GetDefinition(nil, 1)

	if not def then return false end

	local original_tokens = {}

	for i, v in pairs(def.tokens) do
		original_tokens[i] = v.parent or v
	end

	self:RemoveToken(self:GetPosition())
	local str = self:ToString(original_tokens)
	-- Normalize whitespace: trim and collapse multiple spaces
	str = str:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	local tk = self:NewToken("string", "\"" .. str .. "\"")
	self:RemoveToken(self:GetPosition())
	self:AddTokens({tk})
	self:Advance(#def.tokens)
	return true
end

-- Helper to handle empty macro expansion
local function handle_empty_macro(self, current_token)
	if current_token.type == "end_of_file" then return false end

	local has_ws = current_token:HasWhitespace()
	local ws = has_ws and current_token:GetWhitespace() or nil
	self:RemoveToken(self:GetPosition())

	-- Preserve whitespace with empty token if needed
	if has_ws then
		local empty_ws_token = self:NewToken("symbol", "")
		empty_ws_token.whitespace = ws
		empty_ws_token.whitespace_start = current_token.whitespace_start
		self:AddTokens({empty_ws_token})
	end

	return true
end

-- Helper to mark tokens and inherit expansion history
local function mark_and_inherit_expansion(tokens, def_identifier, current_token)
	for _, token in ipairs(tokens) do
		token.expanded_from = token.expanded_from or {}
		token.expanded_from[def_identifier] = true

		-- Inherit expansion history to prevent re-expansion
		if current_token.expanded_from then
			for macro_name, _ in pairs(current_token.expanded_from) do
				token.expanded_from[macro_name] = true
			end
		end
	end
end

function META:ExpandMacro()
	local tk = self:GetToken()

	if tk.type == "end_of_file" then return false end

	-- Special handling for __VA_OPT__
	local next_tk = self:GetTokenOffset(1)

	if
		tk.type == "letter" and
		tk:ValueEquals("__VA_OPT__") and
		next_tk.type ~= "end_of_file" and
		next_tk:ValueEquals("(")
	then
		return self:HandleVAOPT()
	end

	local def = self:GetDefinition(nil, 0)

	if not def then return false end

	-- Function-like macros are handled by ExpandMacroCall()
	if def.args then return false end

	local current_token = self:GetToken()

	if current_token.type == "end_of_file" then return false end

	-- Prevent infinite recursion
	if is_already_expanded(current_token, def.identifier) then return false end

	-- Handle empty macro definitions
	if #def.tokens == 0 then return handle_empty_macro(self, current_token) end

	-- Expand macro
	-- IMPORTANT: We MUST copy tokens because:
	-- 1. Macros can be expanded multiple times
	-- 2. We modify tokens (whitespace, expanded_from) during expansion
	-- 3. Without copying, these modifications would corrupt the stored definition
	local tokens = copy_tokens(def.tokens)
	transfer_token_whitespace(current_token:Copy(), tokens, false) -- Don't strip newlines for object-like macros
	mark_and_inherit_expansion(tokens, def.identifier, current_token)
	self:RemoveToken(self:GetPosition())
	self:AddTokens(tokens)
	return true
end

function META:ToString(tokens, skip_whitespace)
	tokens = tokens or self.tokens
	local output = buffer.new()

	for i, tk in ipairs(tokens) do
		local value = tk:GetValueString()

		-- For empty tokens, output their whitespace but not the value
		if value == "" then
			if not skip_whitespace and tk:HasWhitespace() then
				for _, whitespace in ipairs(tk:GetWhitespace()) do
					output:put(whitespace:GetValueString())
				end
			end
		-- Don't output the empty value itself
		else
			if not skip_whitespace then
				if tk:HasWhitespace() then
					for _, whitespace in ipairs(tk:GetWhitespace()) do
						output:put(whitespace:GetValueString())
					end
				else
					local prev = tokens[i - 1]

					if prev then
						-- Only add space between non-empty tokens of same type
						if not prev:ValueEquals("") and tk.type ~= "symbol" and tk.type == prev.type then
							output:put(" ")
						end
					end
				end
			end

			output:put(tostring(value))
		end
	end

	return tostring(output)
end

function META:NextToken()
	if not self:GetDefinition(nil, 0) then
		self:Advance(1)
		local tk = self:GetToken()

		if tk.type == "end_of_file" then return false end

		return true
	end

	return false
end

function META:Parse()
	while true do
		if
			not (
				self:ReadDefine() or
				self:ReadUndefine() or
				self:ReadIfdef() or
				self:ReadIfndef() or
				self:ReadIf() or
				self:ReadElif() or
				self:ReadElse() or
				self:ReadEndif() or
				self:ReadInclude() or
				self:ExpandMacroCall() or
				self:ExpandMacroConcatenation() or
				self:ExpandMacroString() or
				self:ExpandMacro() or
				self:NextToken()
			)
		then
			break
		end
	end
end

return META
