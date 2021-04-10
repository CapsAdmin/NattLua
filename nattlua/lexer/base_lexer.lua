--[[#local type { Token } = import_type("nattlua/lexer/token.nlua")]]

local table_pool = require("nattlua.other.table_pool")
local ipairs = ipairs

return function(META--[[#: {
	@Name = "BaseLexer",
	syntax = {
		IsDuringLetter = (function(number): boolean),
		IsLetter = (function(number): boolean),
		IsSpace = (function(number): boolean),
		GetSymbols = (function(): {[number] = string}),
		[string] = any,
	},
	[string] = any,
}]])
--[[#	type META.code = string]]
--[[#	type META.i = number]]
--[[#	type META.code_ptr_ref = string]]
--[[#	type META.code = string]]
--[[#	type META.name = string]]
--[[#	type META.OnError = nil | (function(META, string, string, string, number, number): nil)]]
--[[#	type META.code_ptr = {
			@MetaTable = self,
			[number] = number,
			__add = (function(self, number): self),
			__sub = (function(self, number): self),
		}]]

	local function remove_bom_header(str--[[#: string]])--[[#: string]]
		if str:sub(1, 2) == "\xFE\xFF" then
			return str:sub(3)
		elseif str:sub(1, 3) == "\xEF\xBB\xBF" then
			return str:sub(4)
		end

		return str
	end

	local B = string.byte

	function META:GetLength()
		return self.code_length
	end

	function META:GetChars(start--[[#: number]], stop--[[#: number]])
		return self.code:sub(start, stop)
	end

	function META:GetChar(offset--[[#: number]])
		return self.code:byte(self.i + offset)
	end

	function META:GetCurrentChar()--[[#: number]]
		return self.code:byte(self.i)
	end

	function META:ResetState()
		self.i = 1
	end

	function META:FindNearest(str--[[#: string]])
		local _, stop = self.code:find(str, self.i, true)
		if stop then return stop - self.i + 1 end
		return false
	end

	function META:ReadChar()--[[#: number]]
		local char = self:GetCurrentChar()
		self.i = self.i + 1
		return char
	end

	function META:Advance(len--[[#: number]])
		self.i = self.i + len
		return self.i <= self:GetLength()
	end

	function META:SetPosition(i--[[#: number]])
		self.i = i
	end

	function META:TheEnd()
		return self.i > self:GetLength()
	end

	function META:IsValue(what--[[#: string]], offset--[[#: number]])
		return self:IsByte(B(what), offset)
	end

	function META:IsCurrentValue(what--[[#: string]])
		return self:IsCurrentByte(B(what))
	end

	function META:IsCurrentByte(what--[[#: number]])
		return self:GetCurrentChar() == what
	end

	function META:IsByte(what--[[#: number]], offset--[[#: number]])
		return self:GetChar(offset) == what
	end

	function META:Error(msg--[[#: string]], start--[[#: number | nil]], stop--[[#: number | nil]])
		if self.OnError then
			self:OnError(self.code, self.name, msg, start or self.i, stop or self.i)
		end
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
				}
		end, 3105585)

		function META:NewToken(type--[[#: string]], start--[[#: number]], stop--[[#: number]], is_whitespace--[[#: boolean]])--[[#: Token]]
			local tk = new_token()
			tk.type = type
			tk.is_whitespace = is_whitespace
			tk.start = start
			tk.stop = stop
			return tk
		end
	end

	function META:ReadShebang()
		if self.i == 1 and self:IsCurrentValue("#") then
			for _ = self.i, self:GetLength() do
				self:Advance(1)
				if self:IsCurrentValue("\n") then break end
			end

			return true
		end

		return false
	end

	function META:ReadEndOfFile()
		if self.i > self:GetLength() then
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

	function META:ReadSimple()
		local start = self.i
		local type, is_whitespace = self:Read()
		return type, is_whitespace, start, self.i - 1
	end

	function META:ReadToken() --[[:# Token ]]
        if self:ReadShebang() then return self:NewToken("shebang", 1, self.i - 1, false) end
		local type, is_whitespace, start, stop = self:ReadSimple()
		local tk = self:NewToken(type, start, stop, is_whitespace)
		self:OnTokenRead(tk)
		return tk
	end

	function META:GetTokens()
		self:ResetState()
		local tokens = {}

		for i = self.i, self:GetLength() + 1 do
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

	function META:OnInitialize() 
	end

	function META:OnTokenRead(tk) 
	end

	function META:Initialize(code--[[#: string]])
		self.code = remove_bom_header(code)
		self.code_length = #self.code
		self:ResetState()
		self:OnInitialize()
	end
end
