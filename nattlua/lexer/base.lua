--[[#local type { TokenType } = import("~/nattlua/lexer/token.lua")]]

--[[#local type { Code } = import<|"~/nattlua/code.lua"|>]]

local reverse_escape_string = require("nattlua.other.reverse_escape_string")
local Token = require("nattlua.lexer.token").New
local class = require("nattlua.other.class")
local setmetatable = _G.setmetatable
local ipairs = _G.ipairs
local META = class.CreateTemplate("lexer")
--[[#type META.@Name = "Lexer"]]
--[[#type META.@Self = {
	Code = Code,
	Position = number,
}]]

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

function META.New(code--[[#: Code]])
	local self = setmetatable({
		Code = code,
		Position = 1,
	}, META)
	self:ResetState()
	return self
end

return META
