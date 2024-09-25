--[[#local type { TokenType } = import("./token.lua")]]

local reverse_escape_string = require("nattlua.other.reverse_escape_string")
local Token = require("nattlua.token").New
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
local META = class.CreateTemplate("lexer")
--[[#type META.@Name = "Lexer"]]
--[[#type META.@Self = {
	Code = Code,
	Position = number,
}]]
--[[#local type Lexer = META.@Self]]

function META:GetLength()--[[#: number]]
	return self.Code:GetByteSize()
end

function META:GetStringSlice(start--[[#: number]], stop--[[#: number]])--[[#: string]]
	return self.Code:GetStringSlice(start, stop)
end

function META:PeekByte(offset--[[#: number | nil]])--[[#: number]]
	offset = offset or 0
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
	self.Position = 1
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

function META:TheEnd()--[[#: boolean]]
	return self.Position > self:GetLength()
end

function META:IsString(str--[[#: string]], offset--[[#: number | nil]])--[[#: boolean]]
	offset = offset or 0
	return self.Code:IsStringSlice(self.Position + offset, self.Position + offset + #str - 1, str)
end

function META:IsStringLower(str--[[#: string]])--[[#: boolean]]
	return self.Code:GetStringSlice(self.Position, self.Position + #str - 1):lower() == str
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

function META:Read()--[[#: (TokenType, boolean) | (nil, nil)]]
	return nil, nil
end

function META:ReadSimple()--[[#: (TokenType, boolean, number, number)]]
	if self:ReadShebang() then return "shebang", false, 1, self.Position - 1 end

	local start = self.Position
	local type, is_whitespace = self:Read()

	if type == "discard" then return self:ReadSimple() end

	if not type then
		if self:ReadEndOfFile() then
			type = "end_of_file"
			is_whitespace = false
		end
	end

	if not type then type, is_whitespace = self:ReadUnknown() end

	is_whitespace = is_whitespace or false
	return type, is_whitespace, start, self.Position - 1
end

function META:NewToken(
	type--[[#: TokenType]],
	is_whitespace--[[#: boolean]],
	start--[[#: number]],
	stop--[[#: number]]
)
	return Token(type, is_whitespace, start, stop)
end

do
	function META:ReadToken()
		local type, is_whitespace, start, stop = self:ReadSimple() -- TODO: unpack not working
		local token = self:NewToken(type, is_whitespace, start, stop)
		token.value = self:GetStringSlice(token.start, token.stop)

		if token.type == "string" then
			if token.value:sub(1, 1) == [["]] or token.value:sub(1, 1) == [[']] then
				token.string_value = reverse_escape_string(token.value:sub(2, #token.value - 1))
			elseif token.value:sub(1, 1) == "[" then
				local start = token.value:find("[", 2, true)

				if not start then error("start not found") end

				token.string_value = token.value:sub(start + 1, -start - 1)
			end
		end

		return token
	end

	function META:ReadNonWhitespaceToken()
		local token = self:ReadToken()

		if not token.is_whitespace then
			token.whitespace = {}
			return token
		end

		local whitespace = {token}
		local whitespace_i = 2

		for i = self.Position, self:GetLength() + 1 do
			local token = self:ReadToken()

			if not token.is_whitespace then
				token.whitespace = whitespace
				return token
			end

			whitespace[whitespace_i] = token
			whitespace_i = whitespace_i + 1
		end
	end
end

function META:ReadFirstFromArray(strings--[[#: List<|string|>]])--[[#: boolean]]
	for _, str in ipairs(strings) do
		if self:IsString(str) then
			self:Advance(#str)
			return true
		end
	end

	return false
end

function META:ReadFirstLowercaseFromArray(strings--[[#: List<|string|>]])--[[#: boolean]]
	for _, str in ipairs(strings) do
		if self:IsStringLower(str) then
			self:Advance(#str)
			return true
		end
	end

	return false
end

function META:GetTokens()
	collectgarbage("stop")
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

	collectgarbage("restart")
	return tokens
end

function META:ReadSpace()--[[#: TokenReturnType]]
	if not characters.IsSpace(self:PeekByte()) then return false end

	while not self:TheEnd() do
		self:Advance(1)

		if not characters.IsSpace(self:PeekByte()) then break end
	end

	return "space"
end

function META:ReadLetter()--[[#: TokenReturnType]]
	if not characters.IsLetter(self:PeekByte()) then return false end

	while not self:TheEnd() do
		self:Advance(1)

		if not characters.IsDuringLetter(self:PeekByte()) then break end
	end

	return "letter"
end

function META:ReadMultilineCComment()--[[#: TokenReturnType]]
	if not self:IsString("/*") then return false end

	local start = self:GetPosition()
	self:Advance(2)

	while not self:TheEnd() do
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

	while not self:TheEnd() do
		if self:IsString("\n") then break end

		self:Advance(1)
	end

	return "line_comment"
end

function META:ReadLineComment()--[[#: TokenReturnType]]
	if not self:IsString("--") then return false end

	self:Advance(2)

	while not self:TheEnd() do
		if self:IsString("\n") then break end

		self:Advance(1)
	end

	return "line_comment"
end

function META:ReadMultilineComment()--[[#: TokenReturnType]]
	if
		not self:IsString("--[") or
		(
			not self:IsString("[", 3) and
			not self:IsString("=", 3)
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

function META.ReadInlineAnalyzerDebugCode(self--[[#: Lexer & {comment_escape = string | nil}]])--[[#: TokenReturnType]]
	if not self:IsString("§") then return false end

	self:Advance(#"§")

	while not self:TheEnd() do
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

function META.ReadInlineParserDebugCode(self--[[#: Lexer & {comment_escape = string | nil}]])--[[#: TokenReturnType]]
	if not self:IsString("£") then return false end

	self:Advance(#"£")

	while not self:TheEnd() do
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

	if not characters.IsNumber(self:PeekByte()) then
		self:Error(
			"malformed " .. what .. " expected number, got " .. string.char(self:PeekByte()),
			(self:GetPosition()--[[# as number]]) - 2
		)
		return false
	end

	while not self:TheEnd() do
		if not characters.IsNumber(self:PeekByte()) then break end

		self:Advance(1)
	end

	return true
end

function META:ReadHexNumber()
	if
		not self:IsString("0") or
		(
			not self:IsString("x", 1) and
			not self:IsString("X", 1)
		)
	then
		return false
	end

	self:Advance(2)
	local has_dot = false

	while not self:TheEnd() do
		if self:IsString("_") then self:Advance(1) end

		if not has_dot and self:IsString(".") then
			-- 22..66 would be a number range
			-- so we have to return 22 only
			if self:IsString(".", 1) then break end

			has_dot = true
			self:Advance(1)
		end

		if characters.IsHex(self:PeekByte()) then
			self:Advance(1)
		else
			if characters.IsSpace(self:PeekByte()) or characters.IsSymbol(self:PeekByte()) then
				break
			end

			if self:IsString("p") or self:IsString("P") then
				if self:ReadNumberPowExponent("pow") then break end
			end

			if self:ReadFirstLowercaseFromArray(runtime_syntax:GetNumberAnnotations()) then
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
			self:IsString("b", 1) and
			not self:IsString("B", 1)
		)
	then
		return false
	end

	-- skip past 0b
	self:Advance(2)

	while not self:TheEnd() do
		if self:IsString("_") then self:Advance(1) end

		if self:IsString("1") or self:IsString("0") then
			self:Advance(1)
		else
			if characters.IsSpace(self:PeekByte()) or characters.IsSymbol(self:PeekByte()) then
				break
			end

			if self:IsString("e") or self:IsString("E") then
				if self:ReadNumberPowExponent("exponent") then break end
			end

			if self:ReadFirstLowercaseFromArray(runtime_syntax:GetNumberAnnotations()) then
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
		not characters.IsNumber(self:PeekByte()) and
		(
			not self:IsString(".") or
			not characters.IsNumber(self:PeekByte(1))
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

	while not self:TheEnd() do
		if self:IsString("_") then self:Advance(1) end

		if not has_dot and self:IsString(".") then
			-- 22..66 would be a number range
			-- so we have to return 22 only
			if self:IsString(".", 1) then break end

			has_dot = true
			self:Advance(1)
		end

		if characters.IsNumber(self:PeekByte()) then
			self:Advance(1)
		else
			if characters.IsSpace(self:PeekByte()) or characters.IsSymbol(self:PeekByte()) then
				break
			end

			if self:IsString("e") or self:IsString("E") then
				if self:ReadNumberPowExponent("exponent") then break end
			end

			if self:ReadFirstLowercaseFromArray(runtime_syntax:GetNumberAnnotations()) then
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
		not self:IsString("[", 0) or
		(
			not self:IsString("[", 1) and
			not self:IsString("=", 1)
		)
	then
		return false
	end

	local start = self:GetPosition()
	self:Advance(1)

	if self:IsString("=") then
		while not self:TheEnd() do
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

			while not self:TheEnd() do
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

local symbols = runtime_syntax:GetSymbols()

function META:ReadSymbol()--[[#: TokenReturnType]]
	if self:ReadFirstFromArray(symbols) then return "symbol" end

	return false
end

function META.ReadCommentEscape(self--[[#: Lexer & {comment_escape = string | nil}]])--[[#: TokenReturnType]]
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

function META.ReadRemainingCommentEscape(self--[[#: Lexer & {comment_escape = string | nil}]])--[[#: TokenReturnType]]
	if self.comment_escape and self:IsString(self.comment_escape--[[# as string]]) then
		self:Advance(#self.comment_escape--[[# as string]])
		self.comment_escape = nil
		return "comment_escape"
	end

	return false
end

function META:Read()--[[#: (TokenType, boolean) | (nil, nil)]]
	if self:ReadRemainingCommentEscape() then return "discard", false end

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
end

function META.New(code--[[#: Code]])
	local self = setmetatable({
		Code = code,
		Position = 1,
	}, META)
	self:ResetState()
	return self
end

return META