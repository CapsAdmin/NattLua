local Code = require("nattlua.code").New
local Lexer = require("nattlua.lexer.lexer").New
local Parser = nil

do
	local META = loadfile("nattlua/parser/base.lua")()
	local old = META.New

	function META.New(...)
		local obj = old(...)
		obj.defines = {}
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

	local function tostring_tokens(tokens)
		if not tokens then return "" end

		local str = ""

		for _, tk in ipairs(tokens) do
			str = str .. " " .. tk.value
		end

		return str
	end

	function META:Define(identifier, args, tokens)
		print("DEFINE:", identifier)
		print("\targs:", tostring_tokens(args))
		print("\ttokens:", tostring_tokens(tokens))
		self.defines[identifier] = {args = args, tokens = tokens}
	end

	function META:Undefine(identifier)
		self.defines[identifier] = nil
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

			for _ = self:GetPosition(), self:GetLength() do
				if self:IsTokenValue(",") then break end

				if self:IsTokenValue(")") then break end

				table.insert(tokens, self:ConsumeToken())
			end

			table.insert(args, tokens)

			if self:IsTokenValue(",") then self:ExpectTokenValue(",") end
		end

		self:ExpectTokenValue(")")
		return args
	end

	function META:ParseIdentifier()
		local tk = self:ConsumeToken()

		if tk.type == "letter" then return tk end

		error("Expected identifier, got " .. tk.type)
	end

	local math_min = math.min

	function META:ParseMultipleValues(
		reader--[[#: ref function=(Parser, ...: ref ...any)>(ref (nil | Node))]],
		a--[[#: ref any]],
		b--[[#: ref any]],
		c--[[#: ref any]]
	)
		local out = {}

		for i = 1, math_min(self:GetLength(), 200) do
			local node = reader(self, a, b, c)

			if not node then break end

			out[i] = node

			if not self:IsTokenValue(",") then break end

			self:ExpectTokenValue(",")
		end

		return out
	end

	local function replace_tokens(self)
		for _ = self:GetPosition(), self:GetLength() do
			local tk = self:GetToken()

			if self:IsTokenValue("#") then break end

			if not tk then break end

			local def = self.defines[tk.value]

			if def then
				print("REPLACE:", tk.value)

				if def.args then
					local start = self:GetPosition()
					self:ExpectTokenType("letter") -- consume the identifier
					local args = self:CaptureArgs() -- capture all tokens separated by commas
					local stop = self:GetPosition()
					self:AddTokens(def.tokens)

					for i = stop - 1, start, -1 do
						self:RemoveToken(i)
						stop = stop - 1
					end

					self.current_token_index = stop

					for i, tokens in ipairs(args) do
						local key = def.args[i]
						self:Define(key.value, nil, tokens)
					end

					replace_tokens(self)

					for i, tokens in ipairs(args) do
						local key = def.args[i]
						self:Undefine(key.value)
					end
				else
					self:RemoveToken(self:GetPosition()) -- remove the token we replace
					self:AddTokens(def.tokens)
				end
			else
				self:Advance(1)
			end
		end
	end

	function META:Parse()
		for _ = self:GetPosition(), self:GetLength() do
			while self:IsTokenValue("#") do
				local hashtag = self:ExpectTokenValue("#")
				local directive = self:ExpectTokenType("letter")
				local t = directive.value

				if t == "define" then
					local identifier = self:ExpectTokenType("letter")
					local args = nil

					if self:IsTokenValue("(") then
						self:ExpectTokenValue("(")
						args = self:ParseMultipleValues(self.ParseIdentifier)
						self:ExpectTokenValue(")")
					end

					self:Define(identifier.value, args, self:CaptureTokens())
				elseif t == "undef" then
					local identifier = self:ExpectTokenType("letter")
					self:Undefine(identifier.value)
				else
					error("Unknown preprocessor directive: " .. t)
				end
			end

			replace_tokens(self, tokens)
		end

		local output = ""

		for _, tk in ipairs(self.tokens) do
			if tk.whitespace then
				for _, whitespace in ipairs(tk.whitespace) do
					output = output .. whitespace.value
				end
			end

			output = output .. tk.value
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
	return parser:Parse()
end

assert(
	preprocess([[
#define TEST 1
#define TEST2 2
static int test = TEST + TEST2;
]]):find("static int test = 1 + 2;", nil, true)
)
assert(
	preprocess([[
#define TEST(x) x*x
static int test = TEST(2);
]]):find("static int test =2*2;", nil, true)
)
assert(
	preprocess([[
#define TEST(x,y) x*y
static int test = TEST(2,4);
]]):find("static int test =2*4;", nil, true)
)
assert(
	preprocess([[
#define TEST 1
#undef TEST
static int test = TEST;
]]):find("static int test = TEST;", nil, true)
)
assert(
	preprocess([[
#define MY_LIST \
X(Item1, "This is a description of item 1") \
X(Item2, "This is a description of item 2") \
X(Item3, "This is a description of item 3")

#define X(name, desc) name,
enum ListItemType { MY_LIST }
#undef X

]]):find("enum ListItemType {Item1,Item2,Item3, }", nil, true)
)
