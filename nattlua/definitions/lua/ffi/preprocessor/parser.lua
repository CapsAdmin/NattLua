--[[HOTRELOAD
	run_lua("test/tests/nattlua/c_declarations/preprocessor.lua")
]]
local Lexer = require("nattlua.definitions.lua.ffi.preprocessor.lexer").New
local Code = require("nattlua.code").New
local buffer = require("string.buffer")
local META = require("nattlua.parser.base")()
local bit = require("bit")

local function copy_tokens(tokens)
	local new_tokens = {}

	for i, token in ipairs(tokens) do
		new_tokens[i] = token:Copy()
	end

	return new_tokens
end

local old = META.New

function META.New(tokens, code, config)
	config = config or {}
	config.working_directory = config.working_directory or os.getenv("PWD") or "."
	config.defines = config.defines or {}
	config.include_paths = config.include_paths or {}
	config.max_include_depth = config.max_include_depth or 100
	config.on_include = config.on_include
	config.system_include_paths = config.system_include_paths or {}

	if config.add_standard_defines ~= false then
		local date_str = os.date("\"%b %d %Y\"")
		local time_str = os.date("\"%H:%M:%S\"")
		local standard_defines = {
			__STDC__ = 1,
			__STDC_VERSION__ = "201710L",
			__STDC_HOSTED__ = 1,
			__GNUC__ = 4,
			__GNUC_MINOR__ = 2,
			__GNUC_PATCHLEVEL__ = 1,
			__DATE__ = date_str,
			__TIME__ = time_str,
		}

		for name, value in pairs(standard_defines) do
			if config.defines[name] == nil then config.defines[name] = value end
		end
	end

	local self = old(tokens, code, config)
	self.defines = {}
	self.define_stack = {}
	self.conditional_stack = {}
	self.position_stack = {}
	self.include_depth = 0
	self.current_line = 1
	self.counter_value = 0
	self.macro_expansion_depth = 0

	for name, value in pairs(config.defines) do
		if type(value) == "boolean" then
			value = value and "1" or "0"
		else
			value = tostring(value)
		end

		local value_tokens = Lexer(Code(value, "define")):GetTokens()
		assert(value_tokens[#value_tokens].type == "end_of_file")
		table.remove(value_tokens)
		self:Define(name, nil, value_tokens)
	end

	return self
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

do
	function META:Define(identifier, args, tokens)
		self.defines[identifier] = {args = args, tokens = copy_tokens(tokens), identifier = identifier}

		if self.config.on_define then self.config.on_define(identifier, args, tokens) end
	end

	function META:Undefine(identifier)
		self.defines[identifier] = nil
	end
end

do
	function META:PushDefine(identifier, args, tokens)
		self.define_stack[identifier] = self.define_stack[identifier] or {}
		table.insert(
			self.define_stack[identifier],
			1,
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

		if i == 1 and tokens[1] then
			tokens[1].whitespace = nil

			if tokens[1].parent then tokens[1].parent.whitespace = nil end
		end
	end

	return args
end

local function update_paren_depth(token, depth)
	if token:ValueEquals("(") then
		return depth + 1
	elseif token:ValueEquals(")") then
		return depth - 1
	end

	return depth
end

local function remove_token_range(self, start_pos, end_pos)
	for i = end_pos, start_pos, -1 do
		self:RemoveToken(i)
	end
end

local function is_va_args_non_empty(va)
	return va and #va.tokens > 0 and not va.tokens[1]:ValueEquals("")
end

local function is_already_expanded(token, macro_identifier)
	return token.expanded_from and token.expanded_from[macro_identifier]
end

local function capture_single_argument(self, is_va_opt)
	local tokens = {}

	if not is_va_opt and self:IsToken(",") then return tokens end

	local paren_depth = 0

	for _ = self:GetPosition(), self:GetLength() do
		if paren_depth == 0 then
			if self:IsToken(",") or self:IsToken(")") then break end
		end

		local pos = self:GetPosition()
		local parent = self:GetToken()

		if parent.type == "end_of_file" then break end

		if not is_va_opt then self:Parse() end

		self:SetPosition(pos)
		local tk = self:ConsumeToken()
		paren_depth = update_paren_depth(tk, paren_depth)

		if tk ~= parent then tk.unexpanded_form = parent end

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

	local hashtag = self:ExpectToken("#")
	local directive = self:ExpectTokenValue("define")
	local identifier = self:ExpectTokenType("letter")
	local args = nil

	if self:IsToken("(") and not self:GetToken():HasWhitespace() then
		args = self:CaptureArgumentDefinition()
	end

	self:Define(identifier:GetValueString(), args, self:CaptureTokens())
	return true
end

function META:ReadUndefine()
	if not (self:IsToken("#") and self:IsTokenValueOffset("undef", 1)) then
		return false
	end

	local hashtag = self:ExpectToken("#")
	local directive = self:ExpectTokenValue("undef")
	local identifier = self:ExpectTokenType("letter")
	self:Undefine(identifier:GetValueString())
	return true
end

do
	do
		local parser_meta = require("nattlua.parser.base")()
		require("nattlua.parser.expressions")(parser_meta)

		local function evaluate_ast(self, node)
			if not node then return 0 end

			if node.Type == "expression_value" then
				local tk = node.value

				if tk.type == "number" then
					return tonumber(tk:GetValueString()) or 0
				end

				if tk:ValueEquals("defined") then return 0 end

				if tk.type == "letter" then
					local def = self:GetDefinition(tk:GetValueString())

					if def and def.tokens[1] and def.tokens[1].type == "number" then
						return tonumber(def.tokens[1]:GetValueString()) or 0
					end

					return 0
				end

				return 0
			elseif node.Type == "expression_prefix_operator" then
				local op = node.value:GetValueString()
				local right = evaluate_ast(self, node.right)

				if op == "!" or op == "not" then
					return right == 0 and 1 or 0
				elseif op == "-" then
					return -right
				elseif op == "+" then
					return right
				elseif op == "~" then
					return bit.bnot(math.floor(right))
				end

				return 0
			elseif node.Type == "expression_binary_operator" then
				local op = node.value:GetValueString()

				if op == "defined" then return 0 end

				local left = evaluate_ast(self, node.left)

				if op == "&&" or op == "and" then
					if left == 0 then return 0 end

					local right = evaluate_ast(self, node.right)
					return (left ~= 0 and right ~= 0) and 1 or 0
				elseif op == "||" or op == "or" then
					if left ~= 0 then return 1 end

					local right = evaluate_ast(self, node.right)
					return (left ~= 0 or right ~= 0) and 1 or 0
				end

				local right = evaluate_ast(self, node.right)

				if op == "+" then
					return left + right
				elseif op == "-" then
					return left - right
				elseif op == "*" then
					return left * right
				elseif op == "/" then
					return right ~= 0 and (left / right) or 0
				elseif op == "%" then
					return right ~= 0 and (left % right) or 0
				elseif op == "==" then
					return left == right and 1 or 0
				elseif op == "~=" or op == "!=" then
					return left ~= right and 1 or 0
				elseif op == "<" then
					return left < right and 1 or 0
				elseif op == ">" then
					return left > right and 1 or 0
				elseif op == "<=" then
					return left <= right and 1 or 0
				elseif op == ">=" then
					return left >= right and 1 or 0
				elseif op == "&" then
					return bit.band(math.floor(left), math.floor(right))
				elseif op == "|" then
					return bit.bor(math.floor(left), math.floor(right))
				elseif op == "^" then
					return bit.bxor(math.floor(left), math.floor(right))
				elseif op == "<<" then
					return bit.lshift(math.floor(left), math.floor(right))
				elseif op == ">>" then
					return bit.rshift(math.floor(left), math.floor(right))
				end

				return 0
			end

			return 0
		end

		function META:EvaluateCondition(tokens)
			local Code = require("nattlua.code").New
			local temp_tokens = copy_tokens(tokens)
			table.insert(temp_tokens, self:NewToken("end_of_file", ""))
			local temp_parser = META.New(temp_tokens, self.Code, self.config)
			temp_parser.defines = self.defines
			temp_parser.define_stack = self.define_stack
			local expanded_tokens = {}
			local i = 1
			temp_parser:SetPosition(1)

			while temp_parser:GetPosition() <= #temp_parser.tokens do
				local tk = temp_parser:GetToken()

				if tk.type == "end_of_file" then break end

				if tk:ValueEquals("defined") then
					table.insert(expanded_tokens, tk:Copy())
					temp_parser:Advance(1)
					local has_paren = temp_parser:IsToken("(")

					if has_paren then
						table.insert(expanded_tokens, temp_parser:GetToken():Copy())
						temp_parser:Advance(1)
					end

					if not temp_parser:IsToken("end_of_file") then
						table.insert(expanded_tokens, temp_parser:GetToken():Copy())
						temp_parser:Advance(1)
					end

					if has_paren and temp_parser:IsToken(")") then
						table.insert(expanded_tokens, temp_parser:GetToken():Copy())
						temp_parser:Advance(1)
					end
				else
					local start_pos = temp_parser:GetPosition()
					local expanded = temp_parser:ExpandMacroCall() or temp_parser:ExpandMacro()

					if expanded then
						local end_pos = temp_parser:GetPosition()

						for j = start_pos, end_pos - 1 do
							local token = temp_parser.tokens[j]

							if token and token.type ~= "end_of_file" then
								table.insert(expanded_tokens, token:Copy())
							end
						end
					else
						table.insert(expanded_tokens, tk:Copy())
						temp_parser:Advance(1)
					end
				end
			end

			tokens = expanded_tokens
			local processed_tokens = {}
			i = 1

			while i <= #tokens do
				local tk = tokens[i]

				if tk:ValueEquals("defined") then
					local has_paren = tokens[i + 1] and tokens[i + 1]:ValueEquals("(")
					local name_idx = has_paren and i + 2 or i + 1
					local name_tk = tokens[name_idx]

					if name_tk then
						local is_defined = self:GetDefinition(name_tk:GetValueString()) ~= nil
						local value_token = self:NewToken("number", is_defined and "1" or "0")
						table.insert(processed_tokens, value_token)
						i = name_idx + 1

						if has_paren and tokens[i] and tokens[i]:ValueEquals(")") then
							i = i + 1
						end
					else
						i = i + 1
					end
				else
					table.insert(processed_tokens, tk)
					i = i + 1
				end
			end

			local parser = parser_meta.New(processed_tokens, self.Code)
			local ast = parser:ParseRuntimeExpression(0)

			if not ast then return false end

			local result = evaluate_ast(self, ast)
			return result ~= 0
		end
	end

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

					if directive == "if" or directive == "ifdef" or directive == "ifndef" then
						depth = depth + 1
					elseif directive == "endif" then
						depth = depth - 1

						if depth == 0 then
							local end_pos = self:GetPosition()

							for i = end_pos - 1, start_pos, -1 do
								self:RemoveToken(i)
							end

							self:SetPosition(start_pos)
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
						if directive == "else" then
							local end_pos = self:GetPosition()

							for i = end_pos - 1, start_pos, -1 do
								self:RemoveToken(i)
							end

							self:SetPosition(start_pos)
							self:ExpectToken("#")
							self:ExpectTokenType("letter")
							local directive_end = self:GetPosition()

							for i = directive_end - 1, start_pos, -1 do
								self:RemoveToken(i)
							end

							self:SetPosition(start_pos)
							return "else"
						elseif directive == "elif" then
							local end_pos = self:GetPosition()

							for i = end_pos - 1, start_pos, -1 do
								self:RemoveToken(i)
							end

							self:SetPosition(start_pos)
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

		self:ExpectToken("#")
		self:ExpectTokenValue("ifdef")
		local identifier = self:ExpectTokenType("letter")
		local is_defined = self:GetDefinition(identifier:GetValueString()) ~= nil
		table.insert(self.conditional_stack, {active = is_defined, had_true = is_defined})

		if not is_defined then
			skip_until_directive(self, {"else", "elif", "endif"})
		end

		return true
	end

	function META:ReadIfndef()
		if not (self:IsToken("#") and self:IsTokenValueOffset("ifndef", 1)) then
			return false
		end

		self:ExpectToken("#")
		self:ExpectTokenValue("ifndef")
		local identifier = self:ExpectTokenType("letter")
		local is_defined = self:GetDefinition(identifier:GetValueString()) ~= nil
		local is_active = not is_defined
		table.insert(self.conditional_stack, {active = is_active, had_true = is_active})

		if is_defined then skip_until_directive(self, {"else", "elif", "endif"}) end

		return true
	end

	function META:ReadIf()
		if not (self:IsToken("#") and self:IsTokenOffset("if", 1)) then
			return false
		end

		self:ExpectToken("#")
		self:ExpectToken("if")
		local tokens = self:CaptureTokens()
		local condition = self:EvaluateCondition(tokens)
		table.insert(self.conditional_stack, {active = condition, had_true = condition})

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

		self:ExpectToken("#")
		self:ExpectTokenValue("elif")
		local tokens = self:CaptureTokens()
		local state = self.conditional_stack[#self.conditional_stack]

		if state.had_true then
			skip_until_directive(self, {"else", "elif", "endif"})
		else
			local condition = self:EvaluateCondition(tokens)
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

		self:ExpectToken("#")
		self:ExpectToken("else")
		local state = self.conditional_stack[#self.conditional_stack]

		if state.had_true then
			skip_until_directive(self, {"endif"})
		else
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

		self:ExpectToken("#")
		self:ExpectTokenValue("endif")
		table.remove(self.conditional_stack)
		return true
	end
end

do -- #include
	local fs = require("nattlua.other.fs")

	local function resolve_include_path(self, filename, is_system_include)
		local opts = self.config

		if not opts then return nil, "No preprocessor options available" end

		if self.include_depth >= opts.max_include_depth then
			return nil, "Maximum include depth exceeded"
		end

		local search_paths = {}

		if is_system_include then
			for _, path in ipairs(opts.system_include_paths) do
				table.insert(search_paths, path)
			end

			for _, path in ipairs(opts.include_paths) do
				table.insert(search_paths, path)
			end
		else
			table.insert(search_paths, opts.working_directory)

			for _, path in ipairs(opts.include_paths) do
				table.insert(search_paths, path)
			end

			for _, path in ipairs(opts.system_include_paths) do
				table.insert(search_paths, path)
			end
		end

		for _, base_path in ipairs(search_paths) do
			local full_path = base_path .. "/" .. filename
			local content, err = fs.read(full_path)

			if content then return content, full_path end
		end

		if filename:sub(1, 1) == "/" then
			local content, err = fs.read(filename)

			if content then return content, filename end
		end

		return nil, "Include file not found: " .. filename
	end

	function META:ReadError()
		if not (self:IsToken("#") and self:IsTokenValueOffset("error", 1)) then
			return false
		end

		local hashtag = self:ExpectToken("#")
		local directive = self:ExpectTokenValue("error")
		local message_tokens = self:CaptureTokens()
		local message = self:ToString(message_tokens, false):gsub("^%s+", ""):gsub("%s+$", "")
		error("#error: " .. message)
	end

	function META:ReadWarning()
		if not (self:IsToken("#") and self:IsTokenValueOffset("warning", 1)) then
			return false
		end

		local hashtag = self:ExpectToken("#")
		local directive = self:ExpectTokenValue("warning")
		local message_tokens = self:CaptureTokens()
		local message = self:ToString(message_tokens, false):gsub("^%s+", ""):gsub("%s+$", "")
		print("#warning: " .. message)
		return true
	end

	function META:ReadPragma()
		if not (self:IsToken("#") and self:IsTokenValueOffset("pragma", 1)) then
			return false
		end

		local hashtag = self:ExpectToken("#")
		local directive = self:ExpectTokenValue("pragma")
		self:CaptureTokens()
		return true
	end

	function META:ReadLine()
		if not (self:IsToken("#") and self:IsTokenValueOffset("line", 1)) then
			return false
		end

		local hashtag = self:ExpectToken("#")
		local directive = self:ExpectTokenValue("line")
		local tokens = self:CaptureTokens()

		-- Expand macros in the line directive
		if #tokens > 0 then
			local Code = require("nattlua.code").New
			table.insert(tokens, self:NewToken("end_of_file", ""))
			local temp_parser = META.New(tokens, self.Code, self.config)
			temp_parser.defines = self.defines
			temp_parser.define_stack = self.define_stack
			temp_parser:SetPosition(1)

			while temp_parser:GetPosition() <= #temp_parser.tokens do
				local tk = temp_parser:GetToken()

				if tk.type == "end_of_file" then break end

				if not (temp_parser:ExpandMacroCall() or temp_parser:ExpandMacro()) then
					temp_parser:Advance(1)
				end
			end

			table.remove(temp_parser.tokens)
			tokens = temp_parser.tokens
		end

		-- Parse line number and optional filename
		if #tokens > 0 and tokens[1].type == "number" then
			local line_num = tonumber(tokens[1]:GetValueString())

			if line_num then
				self.current_line = line_num - 1 -- Will be incremented on next newline
			end

			-- Check for optional filename
			if #tokens > 1 and tokens[2].type == "string" then
				local filename = tokens[2]:GetValueString()
				-- Remove quotes
				filename = filename:sub(2, -2)
				self.line_filename = filename
			end
		end

		return true
	end

	function META:ReadInclude()
		if not (self:IsToken("#") and self:IsTokenValueOffset("include", 1)) then
			return false
		end

		local hashtag = self:ExpectToken("#")
		local directive = self:ExpectTokenValue("include")
		local filename
		local is_system_include = false
		-- First, check if we need to expand macros (computed include)
		local needs_expansion = false
		local tk = self:GetToken()

		if tk.type == "letter" then
			-- Check if this is a macro that needs expansion
			local def = self:GetDefinition(tk:GetValueString())

			if def then needs_expansion = true end
		end

		if needs_expansion then
			-- Capture tokens for macro expansion
			local tokens = self:CaptureTokens()

			-- Expand macros in the include directive
			if #tokens > 0 then
				local Code = require("nattlua.code").New
				table.insert(tokens, self:NewToken("end_of_file", ""))
				local temp_parser = META.New(tokens, self.Code, self.config)
				temp_parser.defines = self.defines
				temp_parser.define_stack = self.define_stack
				temp_parser:SetPosition(1)

				while temp_parser:GetPosition() <= #temp_parser.tokens do
					local tk = temp_parser:GetToken()

					if tk.type == "end_of_file" then break end

					if not (temp_parser:ExpandMacroCall() or temp_parser:ExpandMacro()) then
						temp_parser:Advance(1)
					end
				end

				table.remove(temp_parser.tokens)
				tokens = temp_parser.tokens

				-- Now parse the expanded tokens
				if #tokens > 0 then
					if tokens[1].type == "string" then
						local str_val = tokens[1]:GetValueString()
						filename = str_val:sub(2, -2)
						is_system_include = false
					elseif tokens[1]:ValueEquals("<") then
						-- Reconstruct from < ... >
						local parts = {}

						for i = 2, #tokens do
							if tokens[i]:ValueEquals(">") then break end

							table.insert(parts, tokens[i]:GetValueString())
						end

						filename = table.concat(parts)
						is_system_include = true
					else
						error("Invalid #include directive after macro expansion")
					end
				else
					error("Empty #include directive after macro expansion")
				end
			end
		elseif self:IsTokenType("string") then
			local str_token = self:ExpectTokenType("string")
			local str_val = str_token:GetValueString()
			filename = str_val:sub(2, -2)
			is_system_include = false
		elseif self:IsToken("\"") then
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

		local content, full_path = resolve_include_path(self, filename, is_system_include)

		if not content then
			print("Warning: " .. (full_path or filename))
			content = ""
		end

		if self.config.on_include then
			self.config.on_include(filename, full_path)
		end

		local code_obj = Code(content, full_path)
		local tokens = Lexer(code_obj):GetTokens()
		local include_parser = META.New(tokens, code_obj)
		include_parser.defines = self.defines
		local include_opts = {}

		for k, v in pairs(self.config) do
			include_opts[k] = v
		end

		include_opts.working_directory = full_path:match("(.*/)") or self.config.working_directory
		include_parser.config = include_opts
		include_parser.include_depth = self.include_depth + 1
		include_parser:Parse()
		self:AddTokens(include_parser.tokens)
		self.defines = include_parser.defines
		return true
	end
end

local function transfer_token_whitespace(original_token, tokens, strip_newlines)
	if not tokens[1] then return end

	if original_token:HasWhitespace() then
		tokens[1].whitespace = original_token:GetWhitespace()
		tokens[1].whitespace_start = original_token.whitespace_start

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

local function mark_tokens_expanded(tokens, start_pos, end_pos, def_identifier, original_token)
	for i = start_pos, end_pos - 1 do
		local token = tokens[i]

		if token then
			token.expanded_from = token.expanded_from or {}
			token.expanded_from[def_identifier] = true

			if original_token.expanded_from then
				for macro_name, _ in pairs(original_token.expanded_from) do
					token.expanded_from[macro_name] = true
				end
			end
		end
	end
end

local function validate_arg_count(def, args)
	local has_var_arg = def.args[1] and def.args[#def.args]:ValueEquals("...")

	if has_var_arg then
		if #args < #def.args - 1 then error("Argument count mismatch") end
	else
		assert(#args == #def.args, "Argument count mismatch")
	end
end

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

function META:HandleVAOPT()
	local start = self:GetPosition()
	local va_opt_token = self:GetToken()
	self:ExpectTokenType("letter")
	local va = self:GetDefinition("__VA_ARGS__")
	self:ExpectToken("(")
	local content_tokens = {}
	local paren_depth = 0
	local consumed_closing_paren = false

	while true do
		if paren_depth == 0 and self:IsToken(")") then break end

		local tk = self:ConsumeToken()

		if tk.type == "end_of_file" then break end

		local new_depth = update_paren_depth(tk, paren_depth)

		if tk:ValueEquals(")") and new_depth < 0 then
			consumed_closing_paren = true

			break
		end

		paren_depth = new_depth
		table.insert(content_tokens, tk)
	end

	if not consumed_closing_paren then self:ExpectToken(")") end

	local stop = self:GetPosition()
	remove_token_range(self, start, stop - 1)
	self:SetPosition(start)

	if is_va_args_non_empty(va) then
		content_tokens = copy_tokens(content_tokens)

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

	if not def.args then return false end

	local current_tk = self:GetToken()

	if is_already_expanded(current_tk, def.identifier) then return false end

	if def.identifier == "__VA_OPT__" and self:IsTokenOffset("(", 1) then
		return self:HandleVAOPT()
	end

	if current_tk.type == "end_of_file" then return false end

	local tk = current_tk:Copy()
	local tokens = copy_tokens(def.tokens)
	transfer_token_whitespace(tk, tokens, true)
	local start = self:GetPosition()
	self:ExpectTokenType("letter")
	local args = self:CaptureArgs(def)
	local stop = self:GetPosition()
	remove_token_range(self, start, stop - 1)
	self:SetPosition(start)
	-- Insert a temporary end marker after the macro body
	self:AddTokens(tokens)
	local macro_body_end = start + #tokens
	table.insert(self.tokens, macro_body_end, self:NewToken("end_of_macro_body", ""))
	validate_arg_count(def, args)
	define_parameters(self, def, args)
	self.macro_expansion_depth = self.macro_expansion_depth + 1

	-- Parse only until we hit the end marker
	while self:GetPosition() < macro_body_end + 1 do
		local current_pos = self:GetPosition()
		local tk_at_pos = self.tokens[current_pos]

		if tk_at_pos and tk_at_pos.type == "end_of_macro_body" then break end

		if
			not (
				self:ReadDirective() or
				self:ExpandMacroCall() or
				self:ExpandMacroConcatenation() or
				self:ExpandMacroString() or
				self:ExpandMacro() or
				self:NextToken()
			)
		then
			break
		end

		-- Update macro_body_end in case tokens were added
		for i = current_pos, #self.tokens do
			if self.tokens[i] and self.tokens[i].type == "end_of_macro_body" then
				macro_body_end = i

				break
			end
		end
	end

	-- Remove the end marker
	for i = 1, #self.tokens do
		if self.tokens[i] and self.tokens[i].type == "end_of_macro_body" then
			self:RemoveToken(i)

			break
		end
	end

	self.macro_expansion_depth = self.macro_expansion_depth - 1
	mark_tokens_expanded(self.tokens, start, self:GetPosition(), def.identifier, tk)
	undefine_parameters(self, def)
	return true
end

local function get_token_from_definition(self, def, fallback_token)
	if not def then return fallback_token end

	if def.tokens[1] then
		return def.tokens[1]
	elseif #def.tokens == 0 then
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
	local def_left = self:GetDefinition(nil, 0)
	tk_left = get_token_from_definition(self, def_left, tk_left)
	self:Advance(3)
	local tk_right = self:GetToken()

	if tk_right.type == "end_of_file" then return false end

	local def_right = self:GetDefinition(nil, 0)
	tk_right = get_token_from_definition(self, def_right, tk_right)
	self:SetPosition(pos)
	local result_type = "letter"

	if tk_left.type == "string" then
		result_type = "string"
	elseif tk_right.type == "string" then
		result_type = "string"
	end

	local concatenated_token = self:NewToken(result_type, tk_left:GetValueString() .. tk_right:GetValueString())
	self:AddTokens({concatenated_token})

	for i = 1, 4 do
		self:RemoveToken(self:GetPosition() + 1)
	end

	return true
end

function META:ExpandMacroString()
	if not self:IsToken("#") then return false end

	local def = self:GetDefinition(nil, 1)

	if not def then return false end

	local followed_by_concat = self:IsTokenOffset("#", 2) and self:IsTokenOffset("#", 3)
	local original_tokens = {}

	for i, v in pairs(def.tokens) do
		local parent_token = v.parent or v

		if v.unexpanded_form and v.unexpanded_form.type == "letter" then
			local unexpanded_name = v.unexpanded_form:GetValueString()

			if self.define_stack[unexpanded_name] then
				original_tokens[i] = v
			else
				original_tokens[i] = v.unexpanded_form
			end
		else
			original_tokens[i] = parent_token
		end
	end

	self:RemoveToken(self:GetPosition())
	local str = self:ToString(original_tokens)
	str = str:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	local tk = self:NewToken("string", "\"" .. str .. "\"")
	self:RemoveToken(self:GetPosition())
	self:AddTokens({tk})

	if followed_by_concat then return true end

	self:Advance(#def.tokens)
	return true
end

local function handle_empty_macro(self, current_token)
	if current_token.type == "end_of_file" then return false end

	local has_ws = current_token:HasWhitespace()
	local ws = has_ws and current_token:GetWhitespace() or nil
	self:RemoveToken(self:GetPosition())

	if has_ws then
		local empty_ws_token = self:NewToken("symbol", "")
		empty_ws_token.whitespace = ws
		empty_ws_token.whitespace_start = current_token.whitespace_start
		self:AddTokens({empty_ws_token})
	end

	return true
end

local function mark_and_inherit_expansion(tokens, def_identifier, current_token)
	for _, token in ipairs(tokens) do
		token.expanded_from = token.expanded_from or {}
		token.expanded_from[def_identifier] = true

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

	local next_tk = self:GetTokenOffset(1)

	if
		tk.type == "letter" and
		tk:ValueEquals("__VA_OPT__") and
		next_tk.type ~= "end_of_file" and
		next_tk:ValueEquals("(")
	then
		return self:HandleVAOPT()
	end

	if tk.type == "letter" and tk:ValueEquals("__LINE__") then
		local line_token = self:NewToken("number", tostring(self.current_line))
		transfer_token_whitespace(tk:Copy(), {line_token}, false)
		self:RemoveToken(self:GetPosition())
		self:AddTokens({line_token})
		return true
	end

	if tk.type == "letter" and tk:ValueEquals("__FILE__") then
		local filename = self.line_filename or (self.Code and self.Code:GetName()) or "unknown"
		local file_token = self:NewToken("string", "\"" .. filename .. "\"")
		transfer_token_whitespace(tk:Copy(), {file_token}, false)
		self:RemoveToken(self:GetPosition())
		self:AddTokens({file_token})
		return true
	end

	if tk.type == "letter" and tk:ValueEquals("__COUNTER__") then
		local counter_token = self:NewToken("number", tostring(self.counter_value))
		transfer_token_whitespace(tk:Copy(), {counter_token}, false)
		self:RemoveToken(self:GetPosition())
		self:AddTokens({counter_token})
		self.counter_value = self.counter_value + 1
		return true
	end

	local def = self:GetDefinition(nil, 0)

	if not def then return false end

	if def.args then return false end

	local current_token = self:GetToken()

	if current_token.type == "end_of_file" then return false end

	if is_already_expanded(current_token, def.identifier) then return false end

	if #def.tokens == 0 then return handle_empty_macro(self, current_token) end

	local tokens = copy_tokens(def.tokens)
	transfer_token_whitespace(current_token:Copy(), tokens, false)
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

		if value == "" then
			if not skip_whitespace and tk:HasWhitespace() then
				for _, whitespace in ipairs(tk:GetWhitespace()) do
					output:put(whitespace:GetValueString())
				end
			end
		else
			if not skip_whitespace then
				if tk:HasWhitespace() then
					for _, whitespace in ipairs(tk:GetWhitespace()) do
						output:put(whitespace:GetValueString())
					end
				else
					local prev = tokens[i - 1]

					if prev then
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
		local prev_tk = self:GetToken()
		self:Advance(1)
		local tk = self:GetToken()

		if prev_tk:HasWhitespace() then
			for _, ws in ipairs(prev_tk:GetWhitespace()) do
				local ws_str = ws:GetValueString()

				for i = 1, #ws_str do
					if ws_str:sub(i, i) == "\n" then
						self.current_line = self.current_line + 1
					end
				end
			end
		end

		if tk.type == "end_of_file" then return false end

		return true
	end

	return false
end

function META:ReadDirective()
	local start_pos = self:GetPosition()
	local ok = self:ReadDefine() or
		self:ReadUndefine() or
		self:ReadIfdef() or
		self:ReadIfndef() or
		self:ReadIf() or
		self:ReadElif() or
		self:ReadElse() or
		self:ReadEndif() or
		self:ReadError() or
		self:ReadWarning() or
		self:ReadPragma() or
		self:ReadLine() or
		self:ReadInclude()
	local end_pos = self:GetPosition()

	for i = end_pos - 1, start_pos, -1 do
		self:RemoveToken(i)
	end

	self:SetPosition(start_pos)
	return ok
end

function META:Parse()
	while true do
		if
			not (
				self:ReadDirective() or
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
