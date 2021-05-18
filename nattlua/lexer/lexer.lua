--[[#local type { Token, TokenType } = import_type("nattlua/lexer/token.nlua")]]

local table_pool = require("nattlua.other.table_pool")
local setmetatable = _G.setmetatable
local ipairs = _G.ipairs
local META = {}
META.__index = META
--[[#type META.@Name = "Lexer"]]
--[[#type META.@Self = {
		Buffer = string,
		Position = number,
		name = string,
		BufferLength = number,
	}]]
local B = string.byte

function META:GetLength()--[[#: number]]
	return self.BufferLength
end

function META:GetChars(start--[[#: number]], stop--[[#: number]])--[[#: string]]
	return self.Buffer:sub(start, stop)
end

function META:GetChar(offset--[[#: number]])--[[#: number]]
	return (self.Buffer:byte(self.Position + offset))
end

function META:GetCurrentChar()--[[#: number]]
	return (self.Buffer:byte(self.Position))
end

function META:ResetState()
	self.Position = 1
end

function META:FindNearest(str--[[#: string]])
	local _, stop = self.Buffer:find(str, self.Position, true)
	if stop then return stop + 1 end
	return false
end

function META:ReadChar()--[[#: number]]
	local char = self:GetCurrentChar()
	self.Position = self.Position + 1
	return char
end

function META:Advance(len--[[#: number]])--[[#: boolean]]
	self.Position = self.Position + len
	return self.Position <= self:GetLength()
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

function META:IsValue(what--[[#: string]], offset--[[#: number]])--[[#: boolean]]
	return self:IsByte((B(what)), offset)
end

function META:IsCurrentValue(what--[[#: string]])--[[#: boolean]]
	return self:IsCurrentByte((B(what)))
end

function META:IsCurrentByte(what--[[#: number]])--[[#: boolean]]
	return self:GetCurrentChar() == what
end

function META:IsByte(what--[[#: number]], offset--[[#: number]])--[[#: boolean]]
	return self:GetChar(offset) == what
end

function META:OnError(code--[[#: string]], name--[[#: string]], msg--[[#: string]], start--[[#: number | nil]], stop--[[#: number | nil]]) 
end

function META:Error(msg--[[#: string]], start--[[#: number | nil]], stop--[[#: number | nil]])
	if not self.OnError then return end
	self:OnError(self.Buffer, self.name, msg, start or self.Position, stop or self.Position)
end

do
	local new_token = table_pool(function()
		return
			{
				type = "something",
				value = "something",
				whitespace = false,
				start = 0,
				stop = 0,
			}--[[# as Token]]
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
	if self.Position == 1 and self:IsCurrentValue("#") then
		for _ = self.Position, self:GetLength() do
			self:Advance(1)
			if self:IsCurrentValue("\n") then break end
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

function META:GetTokens()
	self:ResetState()
	local tokens = {}

	for i = self.Position, self:GetLength() + 1 do
		tokens[i] = self:ReadToken()
		if not tokens[i] then break end -- TODO

		if tokens[i].type == "end_of_file" then break end
	end

	for _, token in ipairs(tokens) do
		token.value = self:GetChars(token.start, token.stop)
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

local function remove_bom_header(str--[[#: string]])--[[#: string]]
	if str:sub(1, 2) == "\xFE\xFF" then
		return str:sub(3)
	elseif str:sub(1, 3) == "\xEF\xBB\xBF" then
		return str:sub(4)
	end

	return str
end

function META.New(code--[[#: string]])
	local self = setmetatable({
		Buffer = "",
		name = "",
		BufferLength = 0,
		Position = 0,
	}, META)
	self.Buffer = remove_bom_header(code)
	self.BufferLength = #self.Buffer
	self:ResetState()
	return self
end

return META
