--[[#local type { Token, TokenType } = import_type<|"nattlua/lexer/token.nlua"|>]]

local Code = require("nattlua.code.code")
local table_pool = require("nattlua.other.table_pool")
local setmetatable = _G.setmetatable
local ipairs = _G.ipairs
local META = {}
META.__index = META
--[[#type META.@Name = "Lexer"]]
--[[#type META.@Self = {
		Code = Code,
		Position = number,
	}]]
local B = string.byte

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
	return self.Code:GetStringSlice(self.Position + offset, self.Position + offset + #str - 1) == str
end

function META:IsStringLower(str--[[#: string]], offset--[[#: number | nil]])--[[#: boolean]]
	offset = offset or 0
	return self.Code:GetStringSlice(self.Position + offset, self.Position + offset + #str - 1):lower() == str
end

function META:OnError(code--[[#: Code]], msg--[[#: string]], start--[[#: number | nil]], stop--[[#: number | nil]]) 
end

function META:Error(msg--[[#: string]], start--[[#: number | nil]], stop--[[#: number | nil]])
	if not self.OnError then return end
	self:OnError(self.Code, msg, start or self.Position, stop or self.Position)
end

do
	local new_token = table_pool(function()
		local x = 
			{
				type = "unknown",
				value = "",
				whitespace = false,
				start = 0,
				stop = 0,
			}--[[# as Token]]
			return x
	end, 3105585)

	function META:NewToken(type--[[#: TokenType]], is_whitespace--[[#: boolean]], start--[[#: number]], stop--[[#: number]])--[[#: Token]]
		local tk = new_token()
		tk.type = type
		tk.is_whitespace = is_whitespace
		tk.start = start
		tk.stop = stop
		return tk
	end
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

function META:Read()
	return self:ReadUnknown()
end

function META:ReadSimple()--[[#: TokenType,boolean,number,number]]
	if self:ReadShebang() then return "shebang", false, 1, self.Position - 1 end
	local start = self.Position
	local type, is_whitespace = self:Read()

	if not type then
		if self:ReadEndOfFile() then
			type, is_whitespace = "end_of_file", false
		end
	end

	if not type then
		type, is_whitespace = self:ReadUnknown()
	end

	is_whitespace = is_whitespace or false
	return type, is_whitespace, start, self.Position - 1
end

function META:ReadToken()
	local a, b, c, d = self:ReadSimple() -- TODO: unpack not working
	return self:NewToken(a, b, c, d)
end

function META:ReadFirstFromArray(strings--[[#: List<|string|>]]) --[[#: boolean]]
	for _, str in ipairs(strings) do
		if self:IsStringLower(str) then
			self:Advance(#str)
			return true
		end
	end

	return false
end

local fixed = {
	"a", "b", "f", "n", "r", "t", "v", "\\", "\"", "'",
}
local pattern = "\\[" .. table.concat(fixed, "\\") .. "]"

local map_double_quote = {[ [[\"]] ] = [["]]}
local map_single_quote = {[ [[\']] ] = [[']]}

for _, v in ipairs(fixed) do
	map_double_quote["\\" .. v] = load("return \"\\" .. v .. "\"")()
	map_single_quote["\\" .. v] = load("return \"\\" .. v .. "\"")()
end

local function reverse_escape_string(str, quote)
	if quote == "\"" then
		str = str:gsub(pattern, map_double_quote)
	elseif quote == "'" then
		str = str:gsub(pattern, map_single_quote)
	end
	return str
end

function META:GetTokens()
	self:ResetState()
	local tokens = {}

	for i = self.Position, self:GetLength() + 1 do
		tokens[i] = self:ReadToken()
		if not tokens[i] then break end -- TODO

		if tokens[i].type == "end_of_file" then break end
	end

	for _, token in ipairs(tokens) do
		token.value = self:GetStringSlice(token.start, token.stop)

		if token.type == "string" then
			if token.value:sub(1,1) == [["]] then
				token.string_value = reverse_escape_string(token.value:sub(2, #token.value - 1), '"')
			elseif token.value:sub(1,1) == [[']] then
				token.string_value = reverse_escape_string(token.value:sub(2, #token.value - 1), "'")
			elseif token.value:sub(1,1) == "[" then
				local start = token.value:match("(%[[%=]*%[)")
				if not start then error("unable to match string") end
				token.string_value = token.value:sub(#start + 1, -#start - 1)
			end
		end
	end

	local whitespace_buffer = {}
	local whitespace_buffer_i = 1
	local non_whitespace = {}
	local non_whitespace_i = 1

	for _, token in ipairs(tokens) do
		if token.type ~= "discard" then
			if token.is_whitespace then
				whitespace_buffer[whitespace_buffer_i] = token
				whitespace_buffer_i = whitespace_buffer_i + 1
			else
				token.whitespace = whitespace_buffer
				non_whitespace[non_whitespace_i] = token
				non_whitespace_i = non_whitespace_i + 1
				whitespace_buffer = {}
				whitespace_buffer_i = 1
			end
		end
	end

	local tokens = non_whitespace
	local last = tokens[#tokens]

	if last then
		last.value = ""
	end

	return tokens
end

function META.New(code--[[#: Code]])
	local self = setmetatable({
		Code = code,
		Position = 1,
	}, META)
	self:ResetState()
	return self
end

-- lua lexer
do
	--[[# local type Lexer = META.@Self]]
	--[[# local type { TokenReturnType } = import_type<|"nattlua/lexer/token.nlua"|>]]

	local characters = require("nattlua.syntax.characters")
	local runtime_syntax = require("nattlua.syntax.runtime")
	local helpers = require("nattlua.other.quote")

	local function ReadSpace(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
		if characters.IsSpace(lexer:PeekByte()) then
			while not lexer:TheEnd() do
				lexer:Advance(1)
				if not characters.IsSpace(lexer:PeekByte()) then break end
			end

			return "space"
		end

		return false
	end

	local function ReadLetter(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
		if not characters.IsLetter(lexer:PeekByte()) then
			return false
		end
		
		while not lexer:TheEnd() do
			lexer:Advance(1)
			if not characters.IsDuringLetter(lexer:PeekByte()) then break end
		end

		return "letter"
	end

	local function ReadMultilineCComment(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
		if not lexer:IsString("/*") then
			return false
		end

		local start = lexer:GetPosition()
		lexer:Advance(2)

		while not lexer:TheEnd() do
			if lexer:IsString("*/") then
				lexer:Advance(2)
				return "multiline_comment"
			end

			lexer:Advance(1)
		end

		lexer:Error(
			"expected multiline c comment to end, reached end of code",
			start,
			start + 1
		)

		return false
	end

	local function ReadLineCComment(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
		if not lexer:IsString("//") then
			return false
		end

		lexer:Advance(2)

		while not lexer:TheEnd() do
			if lexer:IsString("\n") then
				 break 
			end
			
			lexer:Advance(1)
		end

		return "line_comment"
	end

	local function ReadLineComment(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
		if not lexer:IsString("--") then
			return false
		end

		lexer:Advance(2)

		while not lexer:TheEnd() do
			if lexer:IsString("\n") then
				break 
			end
			
			lexer:Advance(1)
		end

		return "line_comment"
	end

	local function ReadMultilineComment(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
		if not lexer:IsString("--[") or (not lexer:IsString("[", 3) and not lexer:IsString("=", 3)) then
			return false
		end

		local start = lexer:GetPosition()

		-- skip past the --[
		lexer:Advance(3)

		while lexer:IsString("=") do
			lexer:Advance(1)
		end

		if not lexer:IsString("[") then
			-- if we have an incomplete multiline comment, it's just a single line comment
			lexer:SetPosition(start)
			return ReadLineComment(lexer);
		end

		-- skip the last [
		lexer:Advance(1)
		local pos = lexer:FindNearest("]" .. string.rep("=", (lexer:GetPosition() - start) - 4) .. "]")

		if pos then
			lexer:SetPosition(pos)
			return "multiline_comment"
		end

		lexer:Error("expected multiline comment to end, reached end of code", start, start + 1)
		lexer:SetPosition(start + 2)

		return false
	end

	local function ReadInlineAnalyzerDebugCode(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if not lexer:IsString("§") then
				return false
			end

			lexer:Advance(#"§")

			while not lexer:TheEnd() do
				if lexer:IsString("\n") then
					break
				end
				lexer:Advance(1)
			end

			return "analyzer_debug_code"
		end
	local function ReadInlineParserDebugCode(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
		if not lexer:IsString("£") then
			return false
		end

		lexer:Advance(#"£")

		while not lexer:TheEnd() do
			if lexer:IsString("\n") then
				break
			end
			lexer:Advance(1)
		end

		return "parser_debug_code"
	end
	
	local function ReadNumberPowExponent(lexer--[[#: Lexer]], what--[[#: string]])
		lexer:Advance(1)

		if lexer:IsString("+") or lexer:IsString("-") then
			lexer:Advance(1)

			if not characters.IsNumber(lexer:PeekByte()) then
				lexer:Error(
					"malformed " .. what .. " expected number, got " .. string.char(lexer:PeekByte()),
					lexer:GetPosition() - 2
				)
				return false
			end
		end

		while not lexer:TheEnd() do
			if not characters.IsNumber(lexer:PeekByte()) then break end
			lexer:Advance(1)
		end

		return true
	end

	local function ReadHexNumber(lexer--[[#: Lexer]])
		if not lexer:IsString("0") or not lexer:IsStringLower("x", 1) then
			return false
		end

		lexer:Advance(2)
		local has_dot = false

		while not lexer:TheEnd() do
			if lexer:IsString("_") then
				lexer:Advance(1)
			end

			if not has_dot and lexer:IsString(".") then
				-- 22..66 would be a number range
				-- so we have to return 22 only
				if lexer:IsString(".", 1) then
					break
				end
				
				has_dot = true
				lexer:Advance(1)
			end


			if characters.IsHex(lexer:PeekByte()) then
				lexer:Advance(1)
			else
				if characters.IsSpace(lexer:PeekByte()) or characters.IsSymbol(lexer:PeekByte()) then
					break
				end

				if lexer:IsStringLower("p") then
					if ReadNumberPowExponent(lexer, "pow") then
						break
					end
				end

				if lexer:ReadFirstFromArray(runtime_syntax:GetNumberAnnotations()) then break end

				lexer:Error(
					"malformed hex number, got " .. string.char(lexer:PeekByte()),
					lexer:GetPosition() - 1,
					lexer:GetPosition()
				)

				return false
			end
		end

		return "number"
	end

	local function ReadBinaryNumber(lexer--[[#: Lexer]])
		if not lexer:IsString("0") or not lexer:IsStringLower("b", 1) then
			return false
		end

		-- skip past 0b
		lexer:Advance(2)

		while not lexer:TheEnd() do
			if lexer:IsString("_") then
				lexer:Advance(1)
			end

			if lexer:IsString("1") or lexer:IsString("0") then
				lexer:Advance(1)
			else
				if characters.IsSpace(lexer:PeekByte()) or characters.IsSymbol(lexer:PeekByte()) then
					break
				end

				if lexer:IsStringLower("e") then
					if ReadNumberPowExponent(lexer, "exponent") then
						break
					end
				end

				if lexer:ReadFirstFromArray(runtime_syntax:GetNumberAnnotations()) then break end
				
				lexer:Error(
					"malformed binary number, got " .. string.char(lexer:PeekByte()),
					lexer:GetPosition() - 1,
					lexer:GetPosition()
				)
				return false
			end
		end

		return "number"
	end

	local function ReadDecimalNumber(lexer--[[#: Lexer]])
		if not characters.IsNumber(lexer:PeekByte()) and (not lexer:IsString(".") or not characters.IsNumber(lexer:PeekByte(1))) then 
			return false
		end

		-- if we start with a dot
		-- .0
		local has_dot = false
		if lexer:IsString(".") then
			has_dot = true
			lexer:Advance(1)
		end

		while not lexer:TheEnd() do
			if lexer:IsString("_") then
				lexer:Advance(1)
			end

			if not has_dot and lexer:IsString(".") then
				-- 22..66 would be a number range
				-- so we have to return 22 only
				if lexer:IsString(".", 1) then
					break
				end
				
				has_dot = true
				lexer:Advance(1)
			end

			if characters.IsNumber(lexer:PeekByte()) then
				lexer:Advance(1)
			else
				if characters.IsSpace(lexer:PeekByte()) or characters.IsSymbol(lexer:PeekByte()) then
					break
				end

				if lexer:IsString("e") or lexer:IsString("E") then
					if ReadNumberPowExponent(lexer, "exponent") then
						break
					end
				end
				
				if lexer:ReadFirstFromArray(runtime_syntax:GetNumberAnnotations()) then break end

				lexer:Error(
					"malformed number, got " .. string.char(lexer:PeekByte()) .. " in decimal notation",
					lexer:GetPosition() - 1,
					lexer:GetPosition()
				)
				return false
			end
		end

		return "number"
	end

	local function ReadMultilineString(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
		if not lexer:IsString("[", 0) or (not lexer:IsString("[", 1) and not lexer:IsString("=", 1)) then
			return false
		end

		local start = lexer:GetPosition()
		lexer:Advance(1)

		if lexer:IsString("=") then
			while not lexer:TheEnd() do
				lexer:Advance(1)
				if not lexer:IsString("=") then break end
			end
		end

		if not lexer:IsString("[") then
			lexer:Error(
				"expected multiline string " .. helpers.QuoteToken(lexer:GetStringSlice(start, lexer:GetPosition() - 1) .. "[") .. " got " .. helpers.QuoteToken(lexer:GetStringSlice(start, lexer:GetPosition())),
				start,
				start + 1
			)
			return false
		end

		lexer:Advance(1)
		local closing = "]" .. string.rep("=", (lexer:GetPosition() - start) - 2) .. "]"
		local pos = lexer:FindNearest(closing)

		if pos then
			lexer:SetPosition(pos)
			return "string"
		end

		lexer:Error(
			"expected multiline string " .. helpers.QuoteToken(closing) .. " reached end of code",
			start,
			start + 1
		)

		return false
	end

	local ReadSingleQuoteString
	local ReadDoubleQuoteString

	do
		local B = string.byte
		local escape_character = B([[\]])

		local function build_string_reader(name--[[#: string]], quote--[[#: string]])
			return function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
				if not lexer:IsString(quote) then return false end
				
				local start = lexer:GetPosition()
				lexer:Advance(1)
		
				while not lexer:TheEnd() do
					local char = lexer:ReadByte()
		
					if char == escape_character then
						local char = lexer:ReadByte()
		
						if char == B("z") and not lexer:IsString(quote) then
							ReadSpace(lexer)
						end
					elseif char == B("\n") then
						lexer:Advance(-1)
						lexer:Error("expected " .. name:lower() .. " quote to end", start, lexer:GetPosition() - 1)
						return "string"
					elseif char == B(quote) then
						return "string"
					end
				end
		
				lexer:Error(
					"expected " .. name:lower() .. " quote to end: reached end of file",
					start,
					lexer:GetPosition() - 1
				)
				return "string"
			end
		end
		
		ReadDoubleQuoteString = build_string_reader("double", "\"")
		ReadSingleQuoteString = build_string_reader("single", "'")
	end

	local function ReadSymbol(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
		if lexer:ReadFirstFromArray(runtime_syntax:GetSymbols()) then return "symbol" end
		return false
	end

	local function ReadCommentEscape(lexer--[[#: Lexer & {comment_escape = string | nil}]])--[[#: TokenReturnType]]
		if lexer:IsString("--[[#") then
			lexer:Advance(5)
			lexer.comment_escape = "]]"
			return "comment_escape"
        elseif lexer:IsString("--[=[#") then
            lexer:Advance(6)
            lexer.comment_escape = "]=]"
            return "comment_escape"
        end

		return false
	end
	
	local function ReadRemainingCommentEscape(lexer--[[#: Lexer & {comment_escape = string | nil}]])--[[#: TokenReturnType]]
		if lexer.comment_escape and lexer:IsString(lexer.comment_escape --[[#as string]]) then
			lexer:Advance(#lexer.comment_escape --[[#as string]])
			return "comment_escape"
		end

		return false
	end

	function META:Read()
		if ReadRemainingCommentEscape(self) then return "discard", false end

		do
			local name = ReadSpace(self) or
				ReadCommentEscape(self) or
				ReadMultilineCComment(self) or
				ReadLineCComment(self) or
				ReadMultilineComment(self) or
				ReadLineComment(self)
			if name then return name, true end
		end

		do
			local name = ReadInlineAnalyzerDebugCode(self) or
				ReadInlineParserDebugCode(self) or
				ReadHexNumber(self) or
				ReadBinaryNumber(self) or
				ReadDecimalNumber(self) or
				ReadMultilineString(self) or
				ReadSingleQuoteString(self) or
				ReadDoubleQuoteString(self) or
				ReadLetter(self) or
				ReadSymbol(self)
			if name then return name, false end
		end
	end
end

return META.New
