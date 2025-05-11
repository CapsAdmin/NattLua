local Code = require("nattlua.code").New
local Lexer = require("nattlua.lexer.lexer").New
local Parser = nil

do
	local META = loadfile("nattlua/parser/base.lua")()
	local old = META.New

	function META.New(...)
		local obj = old(...)
		obj.defines = {}
		obj.define_stack = {}
		return obj
	end

	function META:IsWhitespace(str, offset)
		local tk = self:GetToken(offset)

		if tk.whitespace then
			for _, whitespace in ipairs(tk.whitespace) do
				if whitespace.value:find(str, nil, true) then return true end
			end
		end

		return false
	end

	function META:IsMultiWhitespace(str, offset)
		local tk = self:GetToken(offset)

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

	local function tostring_tokens(tokens, pos)
		if not tokens then return "" end

		local str = ""
		local str_point = ""

		for i, tk in ipairs(tokens) do
			str = str .. " " .. tk.value
			str_point = str_point .. " " .. (i == pos and "^" or (" "):rep(#tk.value))
		end

		return str .. "\n" .. str_point
	end

	local function is_stringinfy(self)
		return self:GetToken(-1).value == "#" and self:GetToken(-2).value ~= "#"
	end

	do -- for normal define, can be overriden
		function META:Define(identifier, args, tokens)
			local new_tokens = {}

			for i, v in ipairs(tokens) do
				new_tokens[i] = {
					value = v.value,
					type = v.type,
					whitespace = {
						{value = " ", type = "space"},
					},
				}
			end

			self.defines[identifier] = {args = args, tokens = new_tokens}
		end

		function META:Undefine(identifier)
			self.defines[identifier] = nil
		end
	end

	do -- for arguments
		function META:PushDefine(identifier, args, tokens)
			local new_tokens = {}

			for i, v in ipairs(tokens) do
				new_tokens[i] = {
					value = v.value,
					type = v.type,
					whitespace = {
						{value = " ", type = "space"},
					},
				}
			end

			self.define_stack[identifier] = self.define_stack[identifier] or {}
			table.insert(self.define_stack[identifier], 1, {args = args, tokens = new_tokens})
		end

		function META:PushUndefine(identifier)
			self.define_stack[identifier] = self.define_stack[identifier] or {}
			table.remove(self.define_stack[identifier], 1)

			if not self.define_stack[identifier][1] then
				self.define_stack[identifier] = nil
			end
		end
	end

	function META:GetDefinition(identifier)
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

	function META:CaptureArgs()
		self:ExpectTokenValue("(")
		local args = {}

		for _ = self:GetPosition(), self:GetLength() do
			if self:IsTokenValue(")") then break end

			local tokens = {}
			local paren_depth = 0 -- Track the parenthesis nesting level
			for _ = self:GetPosition(), self:GetLength() do
				-- Only break on comma if we're at the top level (paren_depth == 0)
				if self:IsTokenValue(",") and paren_depth == 0 then break end

				-- Break on closing parenthesis only at the top level
				if self:IsTokenValue(")") and paren_depth == 0 then break end

				local tk = self:ConsumeToken()

				-- Update parenthesis depth based on the token we just consumed
				if tk.value == "(" then
					paren_depth = paren_depth + 1
				elseif tk.value == ")" then
					paren_depth = paren_depth - 1
				end

				local def = self:GetDefinition(tk.value)

				if def then
					if def.args then
						local start = self:GetPosition()
						self:ExpectTokenType("letter") -- consume the identifier
						local args = self:CaptureArgs() -- capture all tokens separated by commas
						local stop = self:GetPosition()

						for i = stop - 1, start, -1 do
							self:RemoveToken(i)
						end

						self.current_token_index = start
						self:AddTokens(def.tokens)

						for i, tokens in ipairs(args) do
							table.insert(tokens, 1, def.args[i].value)
						end
					else
						for i, v in ipairs(def.tokens) do
							table.insert(tokens, v)
						end
					end
				else
					table.insert(tokens, tk)
				end
			end

			table.insert(args, tokens)

			if self:IsTokenValue(",") then self:ExpectTokenValue(",") end
		end

		self:ExpectTokenValue(")")
		return args
	end

	function META:PrintState()
		print("\n" .. tostring_tokens(self.tokens, self:GetPosition()))
	end

	function META:ReadDefine()
		if not (self:IsTokenValue("#") and self:IsTokenValue("define", 1)) then
			return false
		end

		local hashtag = self:ExpectTokenValue("#")
		local directive = self:ExpectTokenValue("define")
		local identifier = self:ExpectTokenType("letter")
		local args = nil

		if self:IsTokenValue("(") then
			self:ExpectTokenValue("(")
			args = {}

			for i = 1, self:GetLength() do
				local node = self:ExpectTokenType("letter")

				if not node then break end

				args[i] = node

				if not self:IsTokenValue(",") then break end

				self:ExpectTokenValue(",")
			end

			self:ExpectTokenValue(")")
		end

		self:Define(identifier.value, args, self:CaptureTokens())
		return true
	end

	function META:ReadUndefine()
		if not (self:IsTokenValue("#") and self:IsTokenValue("undef", 1)) then
			return false
		end

		local hashtag = self:ExpectTokenValue("#")
		local directive = self:ExpectTokenValue("undef")
		local identifier = self:ExpectTokenType("letter")
		self:Undefine(identifier.value)
		return true
	end

	function META:ExpandMacroCall()
		local tk = self:GetToken()

		if not tk then return false end

		local def = self:GetDefinition(tk.value)

		if not (def and self:IsTokenValue("(", 1)) then return false end

		local start = self:GetPosition()
		self:ExpectTokenType("letter") -- consume the identifier
		local args = self:CaptureArgs() -- capture all tokens separated by commas
		local stop = self:GetPosition()

		for i = stop - 1, start, -1 do
			self:RemoveToken(i)
		end

		self.current_token_index = start

		if tk.value == "__VA_OPT__" then
			local va = self:GetDefinition("__VA_ARGS__")

			if not va or #va.tokens == 0 or va.tokens[1].value == "" then

			else
				self:AddTokens(def.tokens)
			end
		else
			self:AddTokens(def.tokens)
		end

		local has_var_arg = def.args[1] and def.args[#def.args].value == "..."

		if has_var_arg then
			if #args < #def.args - 1 then error("Argument count mismatch") end
		else
			assert(#args == #def.args, "Argument count mismatch")
		end

		if #args == 0 then
			if def.args[#def.args].value == "..." then
				self:PushDefine("__VA_ARGS__", nil, {self:NewToken("symbol", "")})
				self:PushDefine(
					"__VA_OPT__",
					{
						self:NewToken("letter", "arg"),
					},
					{
						self:NewToken("symbol", ","),
					}
				)
			end
		else
			for i, tokens in ipairs(args) do
				if def.args[i].value == "..." then
					local remaining = {}

					for j = i, #args do
						for _, token in ipairs(args[j]) do
							if j ~= i then
								table.insert(remaining, self:NewToken("symbol", ","))
							end

							table.insert(remaining, token)
						end
					end

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
					self:PushDefine(def.args[i].value, nil, tokens)
				end
			end
		end

		self:Parse()

		if #args == 0 then
			if def.args[#def.args].value == "..." then
				self:PushUndefine("__VA_ARGS__")
				self:PushUndefine("__VA_OPT__")
			end
		else
			for i, tokens in ipairs(args) do
				if def.args[i].value == "..." then
					self:PushUndefine("__VA_ARGS__")
					self:PushUndefine("__VA_OPT__")

					break
				else
					self:PushUndefine(def.args[i].value)
				end
			end
		end

		return true
	end

	function META:ExpandMacroConcatenation()
		if not (self:IsTokenValue("#", 1) and self:IsTokenValue("#", 2)) then
			return false
		end

		local tk_left = self:GetToken()
		local def_left = self:GetDefinition(tk_left.value)

		if not def_left then return false end

		local tk_right = self:GetToken(3)
		local def_right = self:GetDefinition(tk_right.value)

		if not def_right then return false end

		for i = 1, 4 do
			self:RemoveToken(self:GetPosition())
		end

		self:AddTokens(
			{
				self:NewToken(
					"letter",
					self:ToString(def_left.tokens, true) .. self:ToString(def_right.tokens, true)
				),
			}
		)
		return true
	end

	function META:ExpandMacroString()
		if not self:IsTokenValue("#") then return false end

		local tk = self:GetToken(1)

		if not tk then return false end

		local def = self:GetDefinition(tk.value)

		if not def then return false end

		self:RemoveToken(self:GetPosition())
		local output = ""

		for i, tk in ipairs(def.tokens) do
			output = output .. tk.value
		end

		tk = self:NewToken("string", "\"" .. output .. "\"")
		tk.whitespace = {
			{value = " ", type = "space"},
		}
		self:RemoveToken(self:GetPosition())
		self:AddTokens({tk})
		self:Advance(#def.tokens)
		return true
	end

	function META:ExpandMacro()
		local tk = self:GetToken()

		if not tk then return false end

		local def = self:GetDefinition(tk.value)

		if not def then return false end

		self:RemoveToken(self:GetPosition())
		self:AddTokens(def.tokens)

		-- if the first token is another macro, we need to process it
		if not self:GetDefinition(self:GetToken().value) then
			self:Advance(#def.tokens)
		end
	end

	function META:ToString(tokens, skip_whitespace)
		local output = ""

		for i, tk in ipairs(tokens or self.tokens) do
			if not skip_whitespace and tk.whitespace then
				for _, whitespace in ipairs(tk.whitespace) do
					output = output .. whitespace.value
				end
			end

			output = output .. tk.value
		end

		return output
	end

	function META:Parse()
		for _ = self:GetPosition(), self:GetLength() do
			if
				not (
					self:ReadDefine() or
					self:ReadUndefine() or
					self:ExpandMacroCall() or
					self:ExpandMacroConcatenation() or
					self:ExpandMacroString() or
					self:ExpandMacro()
				)
			then
				local tk = self:GetToken()

				if not tk then break end

				local def = self:GetDefinition(tk.value)

				if not def then self:Advance(1) end
			end

			if not self:GetToken() then break end
		end

		return output
	end

	Parser = META.New
end

local function lex(code)
	local lexer = Lexer(code)
	lexer.ReadShebang = function()
		return false
	end
	return lexer:GetTokens()
end

local function preprocess(code, defines)
	local code = Code(code, "test.c")
	local tokens = lex(code)
	local parser = Parser(tokens, code)
	parser:Parse()
	return parser:ToString()
end

local function assert_find(code, find)
	code = preprocess(code)
	local start, stop = code:find(find, nil, true)

	if start and stop then return end

	error("Could not find " .. find .. " in " .. code, 2)
end

assert_find("#define F(...) >__VA_ARGS__<\nF(0)", "> 0 <")
assert_find("#define F(...) >__VA_ARGS__<\nF()", ">  <")
assert_find([[
#define X(x) x
#define Y X(1)

>Y<

]], "> 1<")
assert_find([[
#define X(x) x
#define Y(x) X(x)

>Y(1)<

]], "> 1<")
assert_find(
	[[
	#define REPEAT_5(x) x x x x x
	#define REPEAT_25(x) REPEAT_5(x)
    >REPEAT_25(1)<
]],
	">" .. (" 1"):rep(5) .. "<"
)
assert_find(
	[[
	#define REPEAT_5(x) x x x x x
	#define REPEAT_25(x) REPEAT_5(x) REPEAT_5(x)
    >REPEAT_25(1)<
]],
	">" .. (" 1"):rep(10) .. "<"
)
assert_find(
	[[
	#define REPEAT_5(x) x x x x x
	#define REPEAT_25(x) REPEAT_5(REPEAT_5(x)) 
    >REPEAT_25(1)<
]],
	">" .. (" 1"):rep(25) .. "<"
)
assert_find([[
	#define REPEAT(x) x
    >REPEAT(1)<
]], "> 1<")
assert_find([[
	#define REPEAT(x) x x
    >REPEAT(1)<
]], "> 1 1<")
assert_find([[
	#define REPEAT(x) x x x
    >REPEAT(1)<
]], "> 1 1 1<")
assert_find([[
	#define REPEAT(x) x x x x
    >REPEAT(1)<
]], "> 1 1 1 1<")
assert_find(
	[[
	#define REPEAT_5(x) x x x x x
	#define REPEAT_25(x) REPEAT_5(x)
    >REPEAT_25(1)<
]],
	"> 1 1 1 1 1<"
)
assert_find(
	[[
#define TEST 1
#define TEST2 2
static int test = TEST + TEST2;
]],
	"static int test = 1 + 2;"
)
assert_find([[
#define TEST(x) x*x
static int test = TEST(2);
]], "static int test = 2 * 2;")
assert_find(
	[[
#define TEST(x,y) x*y
static int test = TEST(2,4);
]],
	"static int test = 2 * 4;"
)
assert_find(
	[[
#define TEST 1
#undef TEST
static int test = TEST;
]],
	"static int test = TEST;"
)
assert_find(
	[[
#define MY_LIST \
X(Item1, "This is a description of item 1") \
X(Item2, "This is a description of item 2") \
X(Item3, "This is a description of item 3")

#define X(name, desc) name,
enum ListItemType { MY_LIST }
#undef X

]],
	"enum ListItemType { Item1 , Item2 , Item3 , }"
)
assert_find(
	"#define max(a,b) ((a)>(b)?(a):(b)) \nint x = max(1,2);",
	"( ( 1 ) > ( 2 ) ? ( 1 ) : ( 2 ) );"
)
assert_find(
	"#define max(a,b) ((a)>(b)?(a):(b)) \nint x = max(1,2);",
	"( ( 1 ) > ( 2 ) ? ( 1 ) : ( 2 ) );"
)
assert_find(
	"#define STRINGIFY(a,b,c,d) #a #b #c #d \nSTRINGIFY(1,2,3,4);",
	"\"1\" \"2\" \"3\" \"4\""
)
assert_find("#define STRINGIFY(a) #a \nSTRINGIFY(1);", "\"1\"")
assert_find("#define STRINGIFY(a) #a \nSTRINGIFY((a,b,c));", "\"(a,b,c)\"")
assert_find("#define F(...) >__VA_ARGS__<\nF(1,2,3)", "> 1 , 2 , 3 <")
assert_find("#define F(...) f(0 __VA_OPT__(,) __VA_ARGS__)\nF(1)", "f ( 0 , 1 )")
assert_find("#define F(...) f(0 __VA_OPT__(,) __VA_ARGS__)\nF()", "f ( 0  )")
assert_find("#define F(a, b) >a##b<\nF(1,2)", ">12 <")

--assert_find("#define A value\n#define STR(x) #x\nSTR(A)", "\"A\"")
do
	return
end

assert_find(
	"#define PREFIX(x) pre_##x\n#define SUFFIX(x) x##_post\nPREFIX(fix) SUFFIX(fix)",
	"pre_fix fix_post"
)

do
	return
end

-- Test redefinition of a macro
assert_find("#define X 1\n#define X 2\nX", "2")
-- Test empty macro definition
assert_find("#define EMPTY\nEMPTY", "")
-- Test multiple macro replacements on a single line
assert_find("#define A 1\n#define B 2\nA + B + A", "1 + 2 + 1")
-- Test empty arguments
--assert_find("#define F(x,y) x and y\nF(,)", " and ")
-- Test nested function calls
assert_find("#define F(x) (2*x)\n#define G(y) F(y+1)\nG(5)", "( 2 * 5 + 1 )")
-- Test complex expressions as arguments
assert_find(
	"#define MAX(a,b) ((a)>(b)?(a):(b))\nMAX(1+2,3*4)",
	"( ( 1 + 2 ) > ( 3 * 4 ) ? ( 1 + 2 ) : ( 3 * 4 ) )"
)
-- Test reusing parameters
assert_find("#define TRIPLE(x) x x x\nTRIPLE(abc)", "abc abc abc")
-- Test stringification with spaces
--assert_find("#define STR(x) #x\nSTR(  hello  world  )", "\"  hello  world  \"")
-- Test stringification of a macro
assert_find("#define A value\n#define STR(x) #x\nSTR(A)", "\"A\"")
-- Test stringification of expressions
assert_find("#define STR(x) #x\nSTR(a + b)", "\"a + b\"")
