local Parser = nil

do
	local META = require("nattlua.parser.base")()

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
		return obj
	end

	function META:IsWhitespace(str, offset)
		local tk = self:GetTokenOffset(offset)

		if tk.whitespace then
			for _, whitespace in ipairs(tk.whitespace) do
				if whitespace.value:find(str, nil, true) then return true end
			end
		end

		return false
	end

	function META:IsMultiWhitespace(str, offset)
		local tk = self:GetTokenOffset(offset)

		if tk and tk.whitespace then
			for _, whitespace in ipairs(tk.whitespace) do
				local count = 0

				for i = 1, #whitespace.value do
					if whitespace.value:sub(i, i) == str then count = count + 1 end
				end

				if count and count > 1 then return true end
			end
		end

		return false
	end

	do -- for normal define, can be overriden
		function META:Define(identifier, args, tokens)
			self.defines[identifier] = {args = args, tokens = copy_tokens(tokens), identifier = identifier}
		end

		function META:Undefine(identifier)
			self.defines[identifier] = nil
		end
	end

	do -- for arguments
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

			if not tk then return false end

			if tk.type ~= "letter" then return false end

			identifier = tk.value
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
				not self:IsTokenValue("\\", -1)
				or
				self:IsMultiWhitespace("\n")
			then
				break
			end

			local tk = self:ConsumeToken()

			if not tk then break end

			if tk then if tk.value ~= "\\" then table.insert(tks, tk) end end
		end

		return tks
	end

	function META:CaptureArgumentDefinition()
		self:ExpectTokenValue("(")
		local args = {}

		for i = 1, self:GetLength() do
			if self:IsTokenValue(")") then break end

			local node = self:ExpectTokenType("letter")

			if not node then break end

			args[i] = node

			if not self:IsTokenValue(",") then break end

			self:ExpectTokenValue(",")
		end

		self:ExpectTokenValue(")")
		return args
	end

	function META:CaptureArgs(def)
		local is_va_opt = def and def.identifier == "__VA_OPT__"
		self:ExpectTokenValue("(")
		local args = {}

		for _ = self:GetPosition(), self:GetLength() do
			if self:IsTokenValue(")") then
				if not is_va_opt and self:IsTokenValueOffset(",", -1) then
					local tokens = {}
					table.insert(tokens, self:NewToken("symbol", ""))
					table.insert(args, tokens)
				end

				break
			end

			local tokens = {}

			if not is_va_opt and self:IsTokenValue(",") then
				table.insert(tokens, self:NewToken("symbol", ""))
			else
				local paren_depth = 0

				for _ = self:GetPosition(), self:GetLength() do
					if paren_depth == 0 then
						if self:IsTokenValue(",") then break end

						if self:IsTokenValue(")") then break end
					end

					local pos = self:GetPosition()
					local parent = self:GetToken()
					self:Parse()
					self:SetPosition(pos)
					local tk = self:ConsumeToken()

					if tk.value == "(" then
						paren_depth = paren_depth + 1
					elseif tk.value == ")" then
						paren_depth = paren_depth - 1
					end

					tk.parent = parent
					table.insert(tokens, tk)
				end
			end

			table.insert(args, tokens)

			if self:IsTokenValue(",") then self:ExpectTokenValue(",") end
		end

		self:ExpectTokenValue(")")

		for i, tokens in ipairs(args) do
			tokens = copy_tokens(tokens)
			args[i] = tokens

			for _, tk in ipairs(tokens) do
				if tk.whitespace then
					tk.whitespace = {
						self:NewToken("space", " "),
					}
				end

				if tk.parent then
					if tk.parent.whitespace then
						tk.parent.whitespace = {
							self:NewToken("space", " "),
						}
					end
				end
			end

			if i == 1 then if tokens[1] then tokens[1].whitespace = nil end end

			if i == 1 then
				if tokens[1] and tokens[1].parent then tokens[1].parent.whitespace = nil end
			end
		end

		return args
	end

	function META:PrintState(tokens, pos)
		tokens = tokens or self.tokens
		pos = pos or self:GetPosition()

		if not tokens then return "" end

		local str = ""
		local str_point = ""

		for i, tk in ipairs(tokens) do
			str = str .. " " .. tk.value
			str_point = str_point .. " " .. (i == pos and "^" or (" "):rep(#tk.value))
		end

		str = str .. "\n" .. str_point
		print("\n" .. str)
	end

	function META:ReadDefine()
		if not (self:IsTokenValue("#") and self:IsTokenValueOffset("define", 1)) then
			return false
		end

		local hashtag = self:ExpectTokenValue("#")
		local directive = self:ExpectTokenValue("define")
		local identifier = self:ExpectTokenType("letter")
		local args = self:IsTokenValue("(") and self:CaptureArgumentDefinition() or nil
		self:Define(identifier.value, args, self:CaptureTokens())
		return true
	end

	function META:ReadUndefine()
		if not (self:IsTokenValue("#") and self:IsTokenValueOffset("undef", 1)) then
			return false
		end

		local hashtag = self:ExpectTokenValue("#")
		local directive = self:ExpectTokenValue("undef")
		local identifier = self:ExpectTokenType("letter")
		self:Undefine(identifier.value)
		return true
	end

	function META:ExpandMacroCall()
		local def = self:GetDefinition()

		if not (def and self:IsTokenValueOffset("(", 1)) then return false end

		local whitespace = self:GetToken():Copy().whitespace
		local tokens = copy_tokens(def.tokens)
		tokens[1].whitespace = whitespace

		if tokens[1].whitespace then
			for k, v in ipairs(tokens[1].whitespace) do
				v.value = v.value:gsub("\n", "")
			end
		end

		local start = self:GetPosition()
		self:ExpectTokenType("letter")
		local args = self:CaptureArgs(def)
		local stop = self:GetPosition()

		for i = stop - 1, start, -1 do
			self:RemoveToken(i)
		end

		self:SetPosition(start)

		if def.identifier == "__VA_OPT__" then
			local va = self:GetDefinition("__VA_ARGS__")

			if va and #va.tokens > 0 and va.tokens[1].value ~= "" then
				self:AddTokens(tokens)
			end
		else
			self:AddTokens(tokens)
		end

		local has_var_arg = def.args[1] and def.args[#def.args].value == "..."

		if has_var_arg then
			if #args < #def.args - 1 then error("Argument count mismatch") end
		else
			assert(#args == #def.args, "Argument count mismatch")
		end

		for i, param in ipairs(def.args) do
			if param.value == "..." then
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
				self:PushDefine(
					"__VA_OPT__",
					{
						self:NewToken("letter", "arg"),
					},
					{
						self:NewToken("symbol", ","),
					}
				)

				break
			else
				self:PushDefine(param.value, nil, args[i] or {})
			end
		end

		self:Parse()

		-- Clean up definitions - also unified approach
		for i, param in ipairs(def.args) do
			if param.value == "..." then
				self:PushUndefine("__VA_ARGS__")
				self:PushUndefine("__VA_OPT__")

				break
			else
				self:PushUndefine(param.value)
			end
		end

		return true
	end

	function META:ExpandMacroConcatenation()
		if not (self:IsTokenValueOffset("#", 1) and self:IsTokenValueOffset("#", 2)) then
			return false
		end

		local tk_left = self:GetToken()
		local pos = self:GetPosition()
		self:Advance(3)

		if self:GetDefinition() then self:Parse() end

		self:SetPosition(pos)
		self:AddTokens({
			self:NewToken("letter", tk_left.value .. self:GetTokenOffset(3).value),
		})
		self:Advance(1)

		for i = 1, 4 do
			self:RemoveToken(self:GetPosition())
		end

		return true
	end

	function META:ExpandMacroString()
		if not self:IsTokenValue("#") then return false end

		local def = self:GetDefinition(nil, 1)

		if not def then return false end

		local original_tokens = {}

		for i, v in pairs(def.tokens) do
			original_tokens[i] = v.parent
		end

		self:RemoveToken(self:GetPosition())
		local tk = self:NewToken("string", "\"" .. self:ToString(original_tokens) .. "\"")
		self:RemoveToken(self:GetPosition())
		self:AddTokens({tk})
		self:Advance(#def.tokens)
		return true
	end

	function META:ExpandMacro()
		local def = self:GetDefinition()

		if not def then return false end

		local tokens = def.tokens

		if tokens[1] and tokens[1].value == self:GetToken().value then
			return false
		end

		if tokens[1] then
			local tk = self:GetToken():Copy()
			tokens = copy_tokens(tokens)
			tokens[1].whitespace = tk.whitespace

			if tokens[1].whitespace and false then
				for k, v in ipairs(tokens[1].whitespace) do
					v.value = v.value:gsub("\n", "")
				end
			end
		end

		self:RemoveToken(self:GetPosition())
		self:AddTokens(tokens)
		return true
	end

	function META:ToString(tokens, skip_whitespace)
		tokens = tokens or self.tokens
		local output = ""

		for i, tk in ipairs(tokens) do
			if not skip_whitespace then
				if tk.whitespace then
					for _, whitespace in ipairs(tk.whitespace) do
						output = output .. whitespace.value
					end
				else
					local prev = tokens[i - 1]

					if prev then
						if tk.type ~= "symbol" and tk.type == prev.type then
							output = output .. " "
						end
					end
				end
			end

			output = output .. tk.value
		end

		return output
	end

	function META:NextToken()
		if not self:GetDefinition() then
			self:Advance(1)

			if not self:GetToken() then return false end

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
					self:ExpandMacroCall() or
					self:ExpandMacro() or
					self:ExpandMacroConcatenation() or
					self:ExpandMacroString() or
					self:NextToken()
				)
			then
				break
			end
		end
	end

	Parser = META.New
end

do -- tests
	local Code = require("nattlua.code").New
	local Lexer = require("nattlua.lexer.lexer").New

	local function lex(code)
		local lexer = Lexer(code)
		lexer.ReadShebang = function()
			return false
		end
		return lexer:GetTokens()
	end

	local function preprocess(code)
		local code = Code(code, "test.c")
		local tokens = lex(code)
		local parser = Parser(tokens, code)
		parser:Parse()
		return parser:ToString()
	end

	local function preprocess_gcc(code)
		local tmp_file = os.tmpname() .. ".c"
		local f = assert(io.open(tmp_file, "w"))
		f:write(code)
		f:close()
		local p = assert(io.popen("gcc -E " .. tmp_file, "r"))
		local res = p:read("*all")
		p:close()
		os.remove(tmp_file)
		res = res:gsub("# %d .-\n", "")
		res = res:gsub("\n\n", "")
		return res
	end

	local function assert_find(code, find)
		if not code:find(">.-<") then error("must define a macro with > and <", 2) end

		if find:find(">.-<") then error("must not contain > and <", 2) end

		do
			local gcc_code = preprocess_gcc(code)
			local captured = gcc_code:match(">(.-)<")

			if find ~= captured then
				print(captured .. " != " .. find)
				print("gcc -E fail, could not find:\n" .. find .. "\nin:\n" .. gcc_code)
			end
		end

		do
			local code = preprocess(code)
			local captured = code:match(">(.-)<")

			if find ~= captured then
				print(captured .. " != " .. find)
				error("Could not find:\n" .. find .. "\nin:\n" .. code, 2)
			end
		end
	end

	local function ones(count)
		local str = {}

		for i = 1, count do
			str[i] = "1"
		end

		return table.concat(str, " ")
	end

	-- Test argument error cases
	local function assert_error(code, error_msg)
		local success, err = pcall(function()
			preprocess(code)
		end)
		assert(not success, "Expected an error but none was thrown")
		assert(err:find(error_msg, nil, true), "Error message doesn't match: " .. err)
	end

	do -- whitespace
		assert_find("#define M z \n >x=\nM<", "x=\nz")
		assert_find("#define M \\\n z \n >x=M<", "x=z")
		assert_find("#define S(a) a \n >S(x-y)<", "x-y")
		assert_find("#define S(a) a \n >S(x - y)<", "x - y")
		assert_find("#define S(a) a \n >S( x - y )<", "x - y")
		assert_find("#define S(a) a \n >S( x-    y )<", "x- y")
		assert_find("#define S(a) a \n >S( x -y )<", "x -y")
	end

	do -- basic macro expansion
		assert_find("#define REPEAT(x) x \n >REPEAT(1)<", "1")
		assert_find("#define REPEAT(x) x x \n >REPEAT(1)<", "1 1")
		assert_find("#define REPEAT(x) x x x \n >REPEAT(1)<", "1 1 1")
		assert_find("#define REPEAT(x) x x x x \n >REPEAT(1)<", "1 1 1 1")
		assert_find("#define TEST 1 \n #define TEST2 2 \n >TEST + TEST2<", "1 + 2")
		assert_find("#define TEST(x) x*x \n >TEST(2)<", "2*2")
		assert_find("#define TEST(x,y) x*y \n >TEST(2,4)<", "2*4")
		assert_find("#define X 1 \n #define X 2 \n >X<", "2")
		assert_find("#define A 1 \n #define B 2 \n >A + B + A<", "1 + 2 + 1")
		assert_find("#define TRIPLE(x) x x x \n >TRIPLE(abc)<", "abc abc abc")
		assert_find("#define PLUS(a, b) a + b \n >PLUS(1, 2)<", "1 + 2")
		assert_find("#define MULT(a, b) a * b \n >MULT(3, 4)<", "3 * 4")
		assert_find("#define EMPTY \n >EMPTY<", "")
		assert_find("#define EMPTY() nothing \n >EMPTY()<", "nothing")
		assert_find("#define TEST 1 \n #undef TEST \n >TEST<", "TEST")
	end

	do -- string operations (#)
		assert_find("#define STR(a) #a \n >STR(hello world)<", "\"hello world\"")
		assert_find("#define STR(x) #x \n >STR(  hello  world  )<", "\"hello world\"")
		assert_find(
			"#define STRINGIFY(a,b,c,d) #a #b #c #d  \n >STRINGIFY(1,2,3,4)<",
			"\"1\" \"2\" \"3\" \"4\""
		)
		assert_find("#define STRINGIFY(a) #a  \n >STRINGIFY(1)<", "\"1\"")
		assert_find("#define STRINGIFY(a) #a  \n >STRINGIFY((a,b,c))<", "\"(a,b,c)\"")
		assert_find("#define STR(x) #x \n >STR(a + b)<", "\"a + b\"")
		assert_find("#define A value \n #define STR(x) #x \n >STR(A)<", "\"A\"")
	end

	do -- token concatenation (##)
		assert_find(
			"#define PREFIX(x) pre_##x \n #define SUFFIX(x) x##_post \n >PREFIX(fix) SUFFIX(fix)<",
			"pre_fix fix_post"
		)
		assert_find("#define F(a, b) a##b \n >F(1,2)<", "12")
		assert_find("#define EMPTY_ARG(a, b) a##b \n >EMPTY_ARG(test, )<", "test")
		assert_find("#define EMPTY_ARG(a, b) a##b \n >EMPTY_ARG(, test)<", "test")
		assert_find("#define JOIN(a, b) a##b \n >JOIN(pre, post)<", "prepost")
	end

	do -- empty arguments
		assert_find("#define F(x,y) x and y \n >F(,)<", " and ")
	end

	do -- variadic macros and VA_ARGS
		assert_find("#define F(...) __VA_ARGS__ \n >F(0)<", "0")
		assert_find("#define F(...) __VA_ARGS__ \n >F()<", "")
		assert_find("#define F(...) __VA_ARGS__ \n >F(1,2,3)<", "1,2,3")
		assert_find("#define F(...) f(0 __VA_OPT__(,) __VA_ARGS__) \n >F(1)<", "f(0 , 1)")
		assert_find("#define F(...) f(0 __VA_OPT__(,) __VA_ARGS__) \n >F()<", "f(0 )")
		assert_find(
			"#define VARIADIC(a, ...) a __VA_ARGS__ \n >VARIADIC(first, second, third)<",
			"first second, third"
		)
		assert_find("#define VARIADIC(a, ...) a __VA_ARGS__ \n >VARIADIC(only)<", "only ")
		assert_find(
			"#define DEBUG(...) printf(\"Debug: \" __VA_ARGS__) \n >DEBUG(\"Value: %d\", x)<",
			"printf(\"Debug: \" \"Value: %d\", x)"
		)
		assert_find(
			"#define LOG(fmt, ...) printf(fmt __VA_OPT__(,) __VA_ARGS__) \n >LOG(\"Hello\")<",
			"printf(\"Hello\" )"
		)
		assert_find(
			"#define LOG(fmt, ...) printf(fmt __VA_OPT__(,) __VA_ARGS__) \n >LOG(\"Hello\", \"World\")<",
			"printf(\"Hello\" , \"World\")"
		)
		assert_find("#define COMMA(...) __VA_OPT__(,)__VA_ARGS__ \n >COMMA()<", "")
		assert_find("#define COMMA(...) __VA_OPT__(,)__VA_ARGS__ \n >COMMA(x)<", ",x")
	end

	do -- nested and recursive macros
		assert_find("#define X(x) x \n #define Y X(1) \n >Y<", "1")
		assert_find("#define X(x) x \n #define Y(x) X(x) \n >Y(1)<", "1")
		assert_find(
			"#define REPEAT_5(x) x x x x x \n #define REPEAT_25(x) REPEAT_5(x) \n >REPEAT_25(1)<",
			ones(5)
		)
		assert_find(
			"#define REPEAT_5(x) x x x x x \n #define REPEAT_25(x) REPEAT_5(x) REPEAT_5(x) \n >REPEAT_25(1)<",
			ones(10)
		)
		assert_find(
			"#define REPEAT_5(x) x x x x x \n #define REPEAT_25(x) REPEAT_5(REPEAT_5(x)) \n >REPEAT_25(1)<",
			ones(25)
		)
		assert_find(
			"#define REPEAT_5(x) x x x x x \n #define REPEAT_25(x) REPEAT_5(x) \n >REPEAT_25(1)<",
			"1 1 1 1 1"
		)
		assert_find("#define F(x) (2*x) \n #define G(y) F(y+1) \n >G(5)<", "(2*5+1)")
		assert_find("#define INNER(x) x+x \n #define OUTER(y) INNER(y) \n >OUTER(5)<", "5+5")
		assert_find(
			"#define A(x) x+1 \n #define B(y) A(y*2) \n #define C(z) B(z-1) \n >C(5)<",
			"5-1*2+1"
		)
	end

	do -- complex expressions and ternary operators
		assert_find(
			"#define max(a,b) ((a)^(b)?(a):(b))  \n int x = >max(1,2)<",
			"((1)^(2)?(1):(2))"
		)
		assert_find(
			"#define MAX(a,b) ((a)^(b)?(a):(b)) \n >MAX(1+2,3*4)<",
			"((1+2)^(3*4)?(1+2):(3*4))"
		)
		assert_find("#define COMPLEX(a) a*a \n >COMPLEX(1+2)<", "1+2*1+2")
		assert_find("#define PAREN(a) (a) \n >PAREN(1+2*3)<", "(1+2*3)")
		assert_find("#define FUNC(a) a \n >FUNC((1+2))<", "(1+2)")
		assert_find("#define X 10 \n #define EXPAND(a) a \n >EXPAND(X)<", "10")
	end

	do -- multi-line macros
		assert_find(
			[[
#define MY_LIST \
X(Item1, "This is a description of item 1") \
X(Item2, "This is a description of item 2") \
X(Item3, "This is a description of item 3")

#define X(name, desc) name,
>enum ListItemType { MY_LIST }<
#undef X]],
			"enum ListItemType { Item1,Item2,Item3, }"
		)
	end

	do -- error handling
		assert_error("#define FUNC(a, b) a + b \n FUNC(1)", "Argument count mismatch")
		assert_error("#define FUNC(a, b, c) a + b + c \n FUNC(1, 2)", "Argument count mismatch")
		assert_error("#define FUNC(a, b) a + b \n FUNC(1, 2, 3)", "Argument count mismatch")
	end
end
