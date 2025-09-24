--[=[#--[[HOTRELOAD
	run_test("test/tests/nattlua/lexer.lua")
	run_test("test/performance/lexer.lua")
]]
local type { TokenType } = import("./token.lua")]=]

local Token = require("nattlua.lexer.token").New
local TokenWithString = require("nattlua.lexer.token").New2
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
local formating = require("nattlua.other.formating")
local bit = require("nattlua.other.bit")
local IsSpace = characters.IsSpace
local IsNumber = characters.IsNumber
local IsHex = characters.IsHex
local IsDuringLetter = characters.IsDuringLetter
local IsLetter = characters.IsLetter
local IsKeyword = characters.IsKeyword
local IsSymbol = characters.IsSymbol
local typesystem_syntax = require("nattlua.syntax.typesystem")
local read_letter = runtime_syntax:BuildReadMapReader(typesystem_syntax.ReadMap)
local META = class.CreateTemplate("lexer")
--[[#type META.@Name = "Lexer"]]
--[[#type META.@Self = {
	Code = Code,
	Position = number,
	comment_escape = false | string,
	OnError = function=(self: self, code: Code, msg: string, start: number | nil, stop: number | nil)>(),
	Config = {} | nil,
}]]
--[[#local type Lexer = META.@Self]]

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

function META:ReadSimple()--[[#: (TokenType, boolean, number, number)]]
	local start = self.Position
	local type, is_whitespace = self:Read()
	return type, is_whitespace, start, self.Position - 1
end

do
	function META:ReadToken()
		local type, is_whitespace, start, stop = self:ReadSimple()
		local tk

		if type == "symbol" then
			tk = TokenWithString(type, self.Code:GetStringSlice(start, stop), start, stop)
		elseif type == "letter" then
			tk = Token(type, self.Code, start, stop)
			tk.value = read_letter(tk) or false
		else
			tk = Token(type, self.Code, start, stop)
		end

		return tk, is_whitespace
	end

	local B = string.byte("/")

	function META:ReadNonWhitespaceToken()
		local token, is_whitespace = self:ReadToken()

		if not is_whitespace then return token end

		local whitespace = {token}
		local whitespace_i = 2
		local potential_idiv = false

		for i = self.Position, self:GetLength() + 1 do
			local token, is_whitespace = self:ReadToken()

			if not is_whitespace then
				token.whitespace = whitespace
				token.potential_idiv = potential_idiv
				return token
			end

			whitespace[whitespace_i] = token
			whitespace_i = whitespace_i + 1

			if token.type == "line_comment" then
				if token:GetByte(0) == B and token:GetByte(1) == B then
					potential_idiv = true
				end
			end
		end
	end
end

local function BuildTrieReader(list, lowercase)
	local bit_bor = bit.bor
	local longest = 0
	local min_byte = math.huge
	local max_byte = 0
	local map = {}

	for _, v in ipairs(list) do
		if #v > longest then longest = #v end

		local node = map

		for i = 1, #v do
			local b = v:byte(i)

			if lowercase then b = bit_bor(b, 32) end

			if b < min_byte then min_byte = b end

			if b > max_byte then max_byte = b end

			node[b] = node[b] or {}
			node = node[b]

			if i == #v then node.END = v end
		end
	end

	return function(self)
		local b = self:PeekByte()

		if lowercase then b = bit_bor(b, 32) end

		if b < min_byte or b > max_byte then return false end

		local node = map
		local last_match = nil

		for i = 1, longest do
			local b = self:PeekByteOffset(i - 1)

			if lowercase then b = bit_bor(b, 32) end

			if not node[b] then break end

			node = node[b]

			if node.END then last_match = i end
		end

		if last_match then
			self:Advance(last_match)
			return true
		end

		return false
	end
end

function META:GetTokens()
	self:ResetState()
	local tokens = {}
	local tokens_i = 1

	for i = self.Position, self:GetLength() + 1 do
		local token = self:ReadNonWhitespaceToken()

		if not token then break end

		tokens[tokens_i] = token
		tokens_i = tokens_i + 1

		if token.type == "end_of_file" then break end
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
	local pos = self:FindNearest("]" .. string.rep("=", (self:GetPosition() - start) - 4) .. "]")

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

local ReadNumberAnnotations = BuildTrieReader(runtime_syntax:GetNumberAnnotations(), true)

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

			if ReadNumberAnnotations(self) then break end

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

			if ReadNumberAnnotations(self) then break end

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

			if ReadNumberAnnotations(self) then break end

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

	if self:IsString("=") then
		for _ = self:GetPosition(), self:GetLength() do
			self:Advance(1)

			if not self:IsString("=") then break end
		end
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
	local closing = "]" .. string_rep("=", (self:GetPosition() - start) - 2) .. "]"
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

local ReadSymbolFromTrie = BuildTrieReader(runtime_syntax:GetSymbols(), false)

function META:ReadSymbol()
	if ReadSymbolFromTrie(self) then return "symbol" end

	return false
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

function META:Read()--[[#: (TokenType, boolean) | (nil, nil)]]
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
		local name = self:ReadInlineAnalyzerDebugCode() or
			self:ReadInlineParserDebugCode() or
			self:ReadHexNumber() or
			self:ReadBinaryNumber() or
			self:ReadDecimalNumber() or
			self:ReadMultilineString() or
			self:ReadSingleQuoteString() or
			self:ReadDoubleQuoteString() or
			self:ReadLetter() or
			self:ReadSymbol()

		if name then return name, false end
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
