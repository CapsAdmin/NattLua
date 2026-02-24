--[[#local type { TokenType } = import("./token.lua")]]

--[[HOTRELWOAD
	--run_test("test/tests/nattlua/lexer.lua")
	run_lua("test/performance/lexer.lua")
]]
local Token = require("nattlua.lexer.token").New
local class = require("nattlua.other.class")
local setmetatable = _G.setmetatable
local ipairs = _G.ipairs
local string_rep = _G.string.rep
local string = _G.string
local B = string.byte
--[[#local type TokenReturnType = TokenType | false]]

--[[#local type { Code } = import<|"~/nattlua/code.lua"|>]]

local characters = require("nattlua.syntax.characters")
local runtime_syntax = require("nattlua.syntax.runtime")
local typesystem_syntax = require("nattlua.syntax.typesystem")
local formating = require("nattlua.other.formating")
local bit = require("nattlua.other.bit")
local string_reader = require("nattlua.other.string_reader")--[[# as any]]
local IsSpace = characters.IsSpace
local IsNumber = characters.IsNumber
local IsHex = characters.IsHex
local IsDuringLetter = characters.IsDuringLetter
local IsLetter = characters.IsLetter
local IsKeyword = characters.IsKeyword
local IsSymbol = characters.IsSymbol
local META = class.CreateTemplate("lexer")
--[[#type META.@Name = "Lexer"]]
--[[#type META.@SelfArgument = {
	Code = Code,
	Position = number,
	comment_escape = false | string,
	OnError = function=(self: self, code: Code, msg: string, start: number | nil, stop: number | nil)>(),
	Config = {} | nil,
}]]
--[[#local type Lexer = META.@SelfArgument]]

function META:GetLength()--[[#: number]]
	return self.Code:GetByteSize()
end

function META:GetStringSlice(start--[[#: number]], stop--[[#: number]])--[[#: string]]
	return self.Code:GetStringSlice(start, stop)
end

function META:PeekByte()--[[#: number]]
	return self.Code:GetByte(self.Position)
end

function META:PeekByteOffset(offset--[[#: number]])--[[#: number]]
	return self.Code:GetByte(self.Position + offset)
end

function META:FindNearest(str--[[#: string]])--[[#: nil | number]]
	return self.Code:FindNearest(str, self.Position)
end

function META:ReadByte()--[[#: number]]
	local char = self:PeekByte()
	self.Position = self.Position + 1
	return char
end

function META:ResetState()
	self.Position = 1--[[# as number]]
end

function META:Advance(len--[[#: number]])
	self.Position = self.Position + len
end

function META:SetPosition(i--[[#: number]])
	self.Position = i
end

function META:GetPosition()
	return self.Position
end

function META:IsString(str--[[#: string]])--[[#: boolean]]
	return self.Code:IsStringSlice(self.Position, str)
end

function META:IsStringOffset(str--[[#: string]], offset--[[#: number]])--[[#: boolean]]
	return self.Code:IsStringSlice(self.Position + offset, str)
end

function META:OnError(
	code--[[#: Code]],
	msg--[[#: string]],
	start--[[#: number | nil]],
	stop--[[#: number | nil]]
) end

function META:Error(msg--[[#: string]], start--[[#: number | nil]], stop--[[#: number | nil]])
	self:OnError(self.Code, msg, start or self.Position, stop or self.Position)
end

function META:ReadShebang()
	if self.Position == 1 and self:IsString("#") then
		for _ = self.Position, self:GetLength() do
			self:Advance(1)

			if self:IsString("\n") then break end
		end

		return true
	end

	return false
end

function META:ReadEndOfFile()
	if self.Position > self:GetLength() then
		-- nothing to capture, but remaining whitespace will be added
		self:Advance(1)
		return true
	end

	return false
end

function META:ReadUnknown()
	self:Advance(1)
	return "unknown", false
end

function META:ReadSimple()--[[#: (TokenType, boolean, number, number, string | nil)]]
	local start = self.Position
	local type, is_whitespace, content = self:Read()
	return type--[[# as TokenType]],
	is_whitespace--[[# as boolean]],
	start,
	self.Position - 1,
	content
end

local read_letter

do
	local map = {
		symbol = true,
		nan = true,
		number = true,
		boolean = true,
		self = true,
		string = true,
		any = true,
		require = true,
		import = true,
		dofile = true,
		loadstring = true,
		inf = true,
	}

	for k, v in pairs(runtime_syntax.ReadMap) do
		if not k:find("%p") then map[k] = true end
	end

	for k, v in pairs(typesystem_syntax.ReadMap) do
		if not runtime_syntax.ReadMap[k] then
			if not k:find("%p") then map[k] = true end
		end
	end

	local list = {}

	for k in pairs(map) do
		table.insert(list, k)
	end

	table.insert(list, "import_data")
	read_letter = string_reader(list, false)
end

function META:GetTokens()
	self:ResetState()
	local tokens = {}
	local tokens_i = 1
	local whitespace_start

	for i = self.Position, self:GetLength() + 1 do
		local type, is_whitespace, start, stop, content = self:ReadSimple()

		if is_whitespace then
			whitespace_start = whitespace_start or start
		else
			local tk = Token(type, self, start, stop, whitespace_start)
			whitespace_start = nil

			if type == "symbol" then
				tk.value = content--[[# as string]]
				tk.sub_type = content--[[# as string]]
			elseif type == "letter" then
				local sub_type = read_letter(tk--[[# as any]])

				if sub_type then
					tk.value = sub_type
					tk.sub_type = sub_type
				end
			end

			tokens[tokens_i] = tk
			tokens_i = tokens_i + 1

			if type == "end_of_file" then break end
		end
	end

	return tokens
end

function META:ReadSpace()--[[#: TokenReturnType]]
	if not IsSpace(self:PeekByte()) then return false end

	for _ = self:GetPosition(), self:GetLength() do
		self:Advance(1)

		if not IsSpace(self:PeekByte()) then break end
	end

	return "space"
end

function META:ReadLetter()--[[#: TokenReturnType]]
	if not IsLetter(self:PeekByte()) then return false end

	for _ = self:GetPosition(), self:GetLength() do
		self:Advance(1)

		if not IsDuringLetter(self:PeekByte()) then break end
	end

	return "letter"
end

function META:ReadMultilineCComment()--[[#: TokenReturnType]]
	if not self:IsString("/*") then return false end

	local start = self:GetPosition()
	self:Advance(2)

	for _ = self:GetPosition(), self:GetLength() do
		if self:IsString("*/") then
			self:Advance(2)
			return "multiline_comment"
		end

		self:Advance(1)
	end

	self:Error("expected multiline c comment to end, reached end of code", start, start + 1)
	return false
end

function META:ReadLineCComment()--[[#: TokenReturnType]]
	if not self:IsString("//") then return false end

	self:Advance(2)

	for _ = self:GetPosition(), self:GetLength() do
		if self:IsString("\n") then break end

		self:Advance(1)
	end

	return "line_comment"
end

function META:ReadLineComment()--[[#: TokenReturnType]]
	if not self:IsString("--") then return false end

	self:Advance(2)

	for _ = self:GetPosition(), self:GetLength() do
		if self:IsString("\n") then break end

		self:Advance(1)
	end

	return "line_comment"
end

function META:ReadMultilineComment()--[[#: TokenReturnType]]
	if
		not self:IsString("--[") or
		(
			not self:IsStringOffset("[", 3) and
			not self:IsStringOffset("=", 3)
		)
	then
		return false
	end

	local start = self:GetPosition()
	-- skip past the --[
	self:Advance(3)

	while self:IsString("=") do
		self:Advance(1)
	end

	if not self:IsString("[") then
		-- if we have an incomplete multiline comment, it's just a single line comment
		self:SetPosition(start)
		return self:ReadLineComment()
	end

	-- skip the last [
	self:Advance(1)
	local count = (self:GetPosition() - start) - 4
	local closing

	if count == 0 then
		closing = "]]"
	elseif count == 1 then
		closing = "]=]"
	else
		closing = "]" .. string_rep("=", count) .. "]"
	end

	local pos = self:FindNearest(closing)

	if pos then
		self:SetPosition(pos)
		return "multiline_comment"
	end

	self:Error("expected multiline comment to end, reached end of code", start, start + 1)
	self:SetPosition(start + 2)
	return false
end

function META.ReadInlineAnalyzerDebugCode(self--[[#: Lexer]])--[[#: TokenReturnType]]
	if not self:IsString("§") then return false end

	self:Advance(#"§")

	for _ = self:GetPosition(), self:GetLength() do
		if
			self:IsString("\n") or
			(
				self.comment_escape and
				self:IsString(self.comment_escape)
			)
		then
			break
		end

		self:Advance(1)
	end

	return "analyzer_debug_code"
end

function META.ReadInlineParserDebugCode(self--[[#: Lexer]])--[[#: TokenReturnType]]
	if not self:IsString("£") then return false end

	self:Advance(#"£")

	for _ = self:GetPosition(), self:GetLength() do
		if
			self:IsString("\n") or
			(
				self.comment_escape and
				self:IsString(self.comment_escape)
			)
		then
			break
		end

		self:Advance(1)
	end

	return "parser_debug_code"
end

function META:ReadNumberPowExponent(what--[[#: string]])
	self:Advance(1) -- Consume the 'e' or 'p' character
	if self:IsString("+") or self:IsString("-") then self:Advance(1) end

	if not IsNumber(self:PeekByte()) then
		self:Error(
			"malformed " .. what .. " expected number, got " .. string.char(self:PeekByte()),
			(self:GetPosition()--[[# as number]]) - 2
		)
		return false
	end

	for _ = self:GetPosition(), self:GetLength() do
		if not IsNumber(self:PeekByte()) then break end

		self:Advance(1)
	end

	return true
end

local ReadNumberAnnotations = string_reader(runtime_syntax:GetNumberAnnotations(), true, true)

function META:ReadHexNumber()
	if
		not self:IsString("0") or
		(
			not self:IsStringOffset("x", 1) and
			not self:IsStringOffset("X", 1)
		)
	then
		return false
	end

	self:Advance(2)
	local has_dot = false

	for _ = self:GetPosition(), self:GetLength() do
		if self:IsString("_") then self:Advance(1) end

		if not has_dot and self:IsString(".") then
			-- 22..66 would be a number range
			-- so we have to return 22 only
			if self:IsStringOffset(".", 1) then break end

			has_dot = true
			self:Advance(1)
		end

		if IsHex(self:PeekByte()) then
			self:Advance(1)
		else
			if IsSpace(self:PeekByte()) or IsSymbol(self:PeekByte()) then break end

			if self:IsString("p") or self:IsString("P") then
				if self:ReadNumberPowExponent("pow") then break end
			end

			local what = ReadNumberAnnotations(self)

			if what then
				self:Advance(#what)

				break
			end

			self:Error(
				"malformed hex number, got " .. string.char(self:PeekByte()),
				self:GetPosition() - 1,
				self:GetPosition()
			)
			return false
		end
	end

	return "number"
end

function META:ReadBinaryNumber()
	if
		not self:IsString("0") or
		not (
			self:IsStringOffset("b", 1) and
			not self:IsStringOffset("B", 1)
		)
	then
		return false
	end

	-- skip past 0b
	self:Advance(2)

	for _ = self:GetPosition(), self:GetLength() do
		if self:IsString("_") then self:Advance(1) end

		if self:IsString("1") or self:IsString("0") then
			self:Advance(1)
		else
			if IsSpace(self:PeekByte()) or IsSymbol(self:PeekByte()) then break end

			if self:IsString("e") or self:IsString("E") then
				if self:ReadNumberPowExponent("exponent") then break end
			end

			local what = ReadNumberAnnotations(self)

			if what then
				self:Advance(#what)

				break
			end

			self:Error(
				"malformed binary number, got " .. string.char(self:PeekByte()),
				self:GetPosition() - 1,
				self:GetPosition()
			)
			return false
		end
	end

	return "number"
end

function META:ReadDecimalNumber()
	if
		not IsNumber(self:PeekByte()) and
		(
			not self:IsString(".") or
			not IsNumber(self:PeekByteOffset(1))
		)
	then
		return false
	end

	-- if we start with a dot
	-- .0
	local has_dot = false

	if self:IsString(".") then
		has_dot = true
		self:Advance(1)
	end

	for _ = self:GetPosition(), self:GetLength() do
		if self:IsString("_") then self:Advance(1) end

		if not has_dot and self:IsString(".") then
			-- 22..66 would be a number range
			-- so we have to return 22 only
			if self:IsStringOffset(".", 1) then break end

			has_dot = true
			self:Advance(1)
		end

		if IsNumber(self:PeekByte()) then
			self:Advance(1)
		else
			if IsSpace(self:PeekByte()) or IsSymbol(self:PeekByte()) then break end

			if self:IsString("e") or self:IsString("E") then
				if self:ReadNumberPowExponent("exponent") then break end
			end

			local what = ReadNumberAnnotations(self)

			if what then
				self:Advance(#what)

				break
			end

			self:Error(
				"malformed number, got " .. string.char(self:PeekByte()) .. " in decimal notation",
				self:GetPosition() - 1,
				self:GetPosition()
			)
			return false
		end
	end

	return "number"
end

function META:ReadMultilineString()--[[#: TokenReturnType]]
	if
		not self:IsString("[") or
		(
			not self:IsStringOffset("[", 1) and
			not self:IsStringOffset("=", 1)
		)
	then
		return false
	end

	local start = self:GetPosition()
	self:Advance(1)

	while self:IsString("=") do
		self:Advance(1)
	end

	if not self:IsString("[") then
		self:Error(
			"expected multiline string " .. formating.QuoteToken(self:GetStringSlice(start, self:GetPosition() - 1) .. "[") .. " got " .. formating.QuoteToken(self:GetStringSlice(start, self:GetPosition())),
			start,
			start + 1
		)
		return false
	end

	self:Advance(1)
	local count = (self:GetPosition() - start) - 2
	local closing

	if count == 0 then
		closing = "]]"
	elseif count == 1 then
		closing = "]=]"
	else
		closing = "]" .. string_rep("=", count) .. "]"
	end

	local pos = self:FindNearest(closing)

	if pos then
		self:SetPosition(pos)
		return "string"
	end

	self:Error(
		"expected multiline string " .. formating.QuoteToken(closing) .. " reached end of code",
		start,
		start + 1
	)
	return false
end

do
	local B = string.byte
	local escape_character = B([[\]])

	local function build_string_reader(name--[[#: string]], quote--[[#: string]])
		return function(self--[[#: Lexer]])--[[#: TokenReturnType]]
			if not self:IsString(quote) then return false end

			local start = self:GetPosition()
			self:Advance(1)

			for _ = self:GetPosition(), self:GetLength() do
				local char = self:ReadByte()

				if char == escape_character then
					local char = self:ReadByte()

					if char == B("z") and not self:IsString(quote) then
						self:ReadSpace()
					end
				elseif char == B("\n") then
					self:Advance(-1)
					self:Error("expected " .. name:lower() .. " quote to end", start, self:GetPosition() - 1)
					return "string"
				elseif char == B(quote) then
					return "string"
				end
			end

			self:Error(
				"expected " .. name:lower() .. " quote to end: reached end of file",
				start,
				self:GetPosition() - 1
			)
			return "string"
		end
	end

	META.ReadDoubleQuoteString = build_string_reader("double", "\"")
	META.ReadSingleQuoteString = build_string_reader("single", "'")
end

do
	local symbols = {}
	local done = {}

	for _, v in ipairs(runtime_syntax:GetSymbols()) do
		done[v] = true
		table.insert(symbols, v)
	end

	for _, v in ipairs(typesystem_syntax:GetSymbols()) do
		if not done[v] then table.insert(symbols, v) end
	end

	local read_symbol = string_reader(symbols, true)

	function META:ReadSymbol()--[[#: "symbol" | false]]
		local str = read_symbol(self--[[# as any]])

		if str then
			self:Advance(#str)
			return "symbol", str
		end

		return false
	end
end

function META.ReadCommentEscape(self--[[#: Lexer]])--[[#: TokenReturnType]]
	if self:IsString("--[[#") then
		self:Advance(5)
		self.comment_escape = "]]"
		return "comment_escape"
	elseif self:IsString("--[=[#") then
		self:Advance(6)
		self.comment_escape = "]=]"
		return "comment_escape"
	end

	return false
end

function META.ReadRemainingCommentEscape(self--[[#: Lexer]])--[[#: TokenReturnType]]
	if self.comment_escape and self:IsString(self.comment_escape--[[# as string]]) then
		self:Advance(#(self.comment_escape--[[# as string]]))
		self.comment_escape = false
		return "comment_escape"
	end

	return false
end

function META:Read()--[[#: (TokenType, boolean, string | nil) | (nil, nil)]]
	if self:ReadShebang() then return "shebang", false end

	if self:ReadRemainingCommentEscape() then return "comment_escape", true end

	do
		local name = self:ReadSpace() or
			self:ReadCommentEscape() or
			self:ReadMultilineCComment() or
			self:ReadLineCComment() or
			self:ReadMultilineComment() or
			self:ReadLineComment()

		if name then return name, true end
	end

	do
		local content
		local name = self:ReadInlineAnalyzerDebugCode() or
			self:ReadInlineParserDebugCode() or
			self:ReadHexNumber() or
			self:ReadBinaryNumber() or
			self:ReadDecimalNumber() or
			self:ReadMultilineString() or
			self:ReadSingleQuoteString() or
			self:ReadDoubleQuoteString() or
			self:ReadLetter()

		if not name then name, content = self:ReadSymbol() end

		if name then return name, false, content end
	end

	if self:ReadEndOfFile() then return "end_of_file", false end

	return self:ReadUnknown()
end

function META.New(code--[[#: Code]], config--[[#: {} | nil]])
	local self = META.NewObject(
		{
			Code = code,
			Position = 1,
			comment_escape = false,
			OnError = META.OnError,
			Config = config,
		},
		true
	)
	self:ResetState()
	return self
end

return META
